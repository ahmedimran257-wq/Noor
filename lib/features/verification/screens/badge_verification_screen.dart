import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../../core/services/selfie_verification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';

enum _PassiveScanState { loading, scanning, capturing, failed, complete }

class BadgeVerificationScreen extends StatefulWidget {
  const BadgeVerificationScreen({super.key});

  @override
  State<BadgeVerificationScreen> createState() =>
      _BadgeVerificationScreenState();
}

class _BadgeVerificationScreenState extends State<BadgeVerificationScreen>
    with WidgetsBindingObserver {
  final _service = SelfieVerificationService.instance;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  CameraController? _camera;
  _PassiveScanState _state = _PassiveScanState.loading;
  bool _processingFrame = false;
  bool _faceEligible = false;
  bool _disposed = false;
  int? _countdown;
  Timer? _countdownTimer;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  String _guidance = 'Center your face inside the guide';
  String? _failureReason;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed &&
        _state == _PassiveScanState.scanning &&
        _camera == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _start() async {
    if (await _service.hasBadge()) {
      if (mounted) setState(() => _state = _PassiveScanState.complete);
      return;
    }
    await _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cancelCountdown();
    if (mounted) {
      setState(() {
        _state = _PassiveScanState.loading;
        _failureReason = null;
        _guidance = 'Center your face inside the guide';
      });
    }

    try {
      final cameras = await availableCameras();
      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (front.isEmpty) throw StateError('Front camera unavailable');

      final controller = CameraController(
        front.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted || _disposed) {
        await controller.dispose();
        return;
      }
      _camera = controller;
      setState(() => _state = _PassiveScanState.scanning);
      await controller.startImageStream(_processFrame);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _PassiveScanState.failed;
        _failureReason = 'Camera access is required for verification';
      });
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processingFrame ||
        _state != _PassiveScanState.scanning ||
        DateTime.now().difference(_lastFrameAt) <
            const Duration(milliseconds: 220)) {
      return;
    }
    _processingFrame = true;
    _lastFrameAt = DateTime.now();

    try {
      final input = _inputImageFromCamera(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _state != _PassiveScanState.scanning) return;

      String guidance;
      var eligible = false;
      if (faces.isEmpty) {
        guidance = 'Center your face inside the guide';
      } else if (faces.length > 1) {
        guidance = 'Only one face should be visible';
      } else {
        final face = faces.single;
        final frameArea = image.width * image.height;
        final faceArea = face.boundingBox.width * face.boundingBox.height;
        final prominence = frameArea <= 0 ? 0.0 : faceArea / frameArea;
        final leftEye = face.leftEyeOpenProbability ?? 0;
        final rightEye = face.rightEyeOpenProbability ?? 0;

        if (prominence < 0.30) {
          guidance = 'Move closer';
        } else if (leftEye <= 0.7 || rightEye <= 0.7) {
          guidance = 'Open your eyes and remove sunglasses';
        } else {
          guidance = 'Hold still';
          eligible = true;
        }
      }

      if (_guidance != guidance || _faceEligible != eligible) {
        setState(() {
          _guidance = guidance;
          _faceEligible = eligible;
        });
      }
      if (eligible) {
        _beginCountdown();
      } else {
        _cancelCountdown();
      }
    } catch (_) {
      if (mounted && _guidance != 'Move to better lighting') {
        setState(() => _guidance = 'Move to better lighting');
      }
    } finally {
      _processingFrame = false;
    }
  }

  InputImage? _inputImageFromCamera(CameraImage image) {
    final camera = _camera;
    if (camera == null || image.planes.isEmpty) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (format != InputImageFormat.nv21 &&
            format != InputImageFormat.bgra8888)) {
      return null;
    }

    final buffer = BytesBuilder(copy: false);
    for (final plane in image.planes) {
      buffer.add(plane.bytes);
    }
    final bytes = buffer.takeBytes();
    final rotation = InputImageRotationValue.fromRawValue(
          camera.description.sensorOrientation,
        ) ??
        InputImageRotation.rotation0deg;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _beginCountdown() {
    if (_countdownTimer != null || !_faceEligible) return;
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_faceEligible || _state != _PassiveScanState.scanning) {
        _cancelCountdown();
        return;
      }
      final current = _countdown ?? 3;
      if (current > 1) {
        setState(() => _countdown = current - 1);
      } else {
        timer.cancel();
        _countdownTimer = null;
        setState(() => _countdown = null);
        unawaited(_captureAutomatically());
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted && _countdown != null) setState(() => _countdown = null);
  }

  Future<void> _captureAutomatically() async {
    final camera = _camera;
    if (camera == null || _state != _PassiveScanState.scanning) return;
    setState(() {
      _state = _PassiveScanState.capturing;
      _guidance = 'Running security checks';
    });

    XFile? capture;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      capture = await camera.takePicture();
      final bytes = await capture.readAsBytes();
      final validation = await _service.validatePassiveSelfie(bytes);
      if (!validation.isValid) {
        await _service.recordFailedAttempt();
        await _showFailure(validation.errorMessage);
        return;
      }

      final saved = await _service.submitBadgeVerification();
      if (!saved) {
        await _showFailure('Could not save your badge. Please retry');
        return;
      }
      await _disposeCamera();
      if (mounted) setState(() => _state = _PassiveScanState.complete);
    } catch (_) {
      await _showFailure('Move to better lighting');
    } finally {
      if (capture != null) {
        await File(capture.path)
            .delete()
            .catchError((_) => File(capture!.path));
      }
    }
  }

  Future<void> _showFailure(String reason) async {
    await _disposeCamera();
    if (!mounted) return;
    setState(() {
      _failureReason = reason;
      _state = _PassiveScanState.failed;
    });
  }

  Future<void> _disposeCamera() async {
    _cancelCountdown();
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    await camera.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _countdown = null;
    unawaited(_disposeCamera());
    unawaited(_detector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: switch (_state) {
        _PassiveScanState.complete => _buildComplete(),
        _PassiveScanState.failed => _buildFailed(),
        _ => _buildCamera(),
      },
    );
  }

  Widget _buildCamera() {
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized)
          CameraPreview(camera)
        else
          ColoredBox(color: AppColors.obsidianNight),
        const ColoredBox(color: Color(0x36000000)),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded,
                          color: AppColors.pearlWhite),
                    ),
                    Expanded(
                      child: Text('Passive face scan',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Spacer(),
              LayoutBuilder(
                builder: (context, constraints) {
                  final size = MediaQuery.sizeOf(context).width * 0.72;
                  return SizedBox(
                    width: size,
                    height: size,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _faceEligible
                              ? AppColors.verifiedTeal
                              : AppColors.champagneGold,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: AppDimensions.durationTransition,
                          child: _countdown == null
                              ? const SizedBox.shrink()
                              : Text(
                                  '$_countdown',
                                  key: ValueKey(_countdown),
                                  style: AppTypography.screenTitle.copyWith(
                                    fontSize: 64,
                                    color: AppColors.pearlWhite,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppDimensions.space20),
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.94),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: AppDimensions.durationTransition,
                      child: Text(
                        _guidance,
                        key: ValueKey(_guidance),
                        style: AppTypography.bodyMedium.copyWith(
                          color: _faceEligible
                              ? AppColors.verifiedTeal
                              : AppColors.pearlWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _state == _PassiveScanState.capturing
                          ? 'Keep the app open while we verify this frame'
                          : 'Capture is automatic when your face is ready',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFailed() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.horizontalMargin),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.softCoral.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.face_retouching_off_rounded,
                  color: AppColors.softCoral, size: 28),
            ),
            const SizedBox(height: AppDimensions.space24),
            Text('Scan not completed',
                style: AppTypography.screenTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.space10),
            Text(_failureReason ?? 'Move to better lighting',
                style: AppTypography.bodyMuted, textAlign: TextAlign.center),
            const Spacer(),
            SilarahPressable(
              onTap: _initializeCamera,
              child: Container(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: Text('Retry scan', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.horizontalMargin),
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.goldGlow,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_rounded,
                  color: AppColors.champagneGold, size: 34),
            ),
            const SizedBox(height: AppDimensions.space24),
            Text('Badge active', style: AppTypography.screenTitle),
            const SizedBox(height: AppDimensions.space10),
            Text(
              'Your passive face scan passed. The verification badge is now visible on your profile.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            SilarahPressable(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: Text('Done', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
