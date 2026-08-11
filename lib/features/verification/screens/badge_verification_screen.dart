import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:intl/intl.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../../../core/services/photo_verification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';

enum _ScreenState { loading, guiding, uploading, pending, approved, failed }

enum _GuideStep { neutral, smile, blink }

class BadgeVerificationScreen extends StatefulWidget {
  const BadgeVerificationScreen({super.key});

  @override
  State<BadgeVerificationScreen> createState() =>
      _BadgeVerificationScreenState();
}

class _BadgeVerificationScreenState extends State<BadgeVerificationScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _service = PhotoVerificationService.instance;
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );
  final Map<String, File> _captures = {};

  late final AnimationController _pulse;
  CameraController? _camera;
  _ScreenState _state = _ScreenState.loading;
  _GuideStep _step = _GuideStep.neutral;
  bool _processingFrame = false;
  bool _eligible = false;
  bool _sawOpenEyes = false;
  bool _manualFallback = false;
  bool _usedFallback = false;
  bool _disposed = false;
  DateTime _lastFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _reviewDeadline;
  String _guidance = 'Look straight at the camera';
  String? _failure;
  Timer? _fallbackTimer;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
      lowerBound: 0.96,
      upperBound: 1.04,
    )..repeat(reverse: true);
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      final status = await _service.fetchStatus();
      if (!mounted) return;
      if (status.isApproved) {
        setState(() => _state = _ScreenState.approved);
        return;
      }
      if (status.isPending) {
        setState(() {
          _state = _ScreenState.pending;
          _reviewDeadline = status.reviewDeadline;
        });
        return;
      }
      await _initializeCamera();
    } catch (error) {
      _showFailure(_message(error));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeCamera());
    } else if (state == AppLifecycleState.resumed &&
        _state == _ScreenState.guiding &&
        _camera == null) {
      unawaited(_initializeCamera(reset: false));
    }
  }

  Future<void> _initializeCamera({bool reset = true}) async {
    _cancelTimers();
    if (reset) {
      await _deleteCaptures();
      _step = _GuideStep.neutral;
      _manualFallback = false;
      _usedFallback = false;
      _sawOpenEyes = false;
    }
    if (mounted) {
      setState(() {
        _state = _ScreenState.loading;
        _failure = null;
        _guidance = _guidanceFor(_step);
      });
    }
    try {
      final cameras = await availableCameras();
      final front = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (front.isEmpty) throw StateError('Front camera unavailable.');
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
      setState(() => _state = _ScreenState.guiding);
      await controller.startImageStream(_processFrame);
      _startFallbackTimer();
    } catch (_) {
      _showFailure('Camera access is required for photo verification.');
    }
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_processingFrame ||
        _state != _ScreenState.guiding ||
        DateTime.now().difference(_lastFrameAt) <
            const Duration(milliseconds: 240)) {
      return;
    }
    _processingFrame = true;
    _lastFrameAt = DateTime.now();
    try {
      final input = _inputImageFromCamera(image);
      if (input == null) return;
      final faces = await _detector.processImage(input);
      if (!mounted || _state != _ScreenState.guiding) return;
      var eligible = false;
      var guidance = _guidanceFor(_step);
      if (faces.length == 1) {
        final face = faces.single;
        final frameArea = image.width * image.height;
        final faceArea = face.boundingBox.width * face.boundingBox.height;
        final prominence = frameArea <= 0 ? 0.0 : faceArea / frameArea;
        final left = face.leftEyeOpenProbability;
        final right = face.rightEyeOpenProbability;
        final smile = face.smilingProbability;
        if (prominence < 0.16) {
          guidance = 'Move a little closer';
        } else {
          switch (_step) {
            case _GuideStep.neutral:
              eligible = true;
              guidance = 'Perfect — hold still';
              break;
            case _GuideStep.smile:
              eligible = smile != null && smile >= 0.32;
              guidance =
                  eligible ? 'Lovely — hold that smile' : 'Give a gentle smile';
              break;
            case _GuideStep.blink:
              if (left != null &&
                  right != null &&
                  left > 0.48 &&
                  right > 0.48) {
                _sawOpenEyes = true;
              }
              eligible = _sawOpenEyes &&
                  left != null &&
                  right != null &&
                  left < 0.38 &&
                  right < 0.38;
              guidance = eligible ? 'Blink captured' : 'Blink once naturally';
              break;
          }
        }
      } else if (faces.length > 1) {
        guidance = 'Only one person should be visible';
      } else {
        guidance = 'Center your face inside the guide';
      }
      if (_eligible != eligible || _guidance != guidance) {
        setState(() {
          _eligible = eligible;
          _guidance = guidance;
        });
      }
      if (eligible) _scheduleCapture();
    } catch (_) {
      if (mounted) setState(() => _guidance = 'Use soft, even lighting');
    } finally {
      _processingFrame = false;
    }
  }

  void _scheduleCapture() {
    if (_captureTimer != null) return;
    _captureTimer = Timer(const Duration(milliseconds: 650), () {
      _captureTimer = null;
      if (_eligible && _state == _ScreenState.guiding) {
        unawaited(_captureStep());
      }
    });
  }

  Future<void> _captureStep({bool manual = false}) async {
    final camera = _camera;
    if (camera == null || _state != _ScreenState.guiding) return;
    _cancelTimers();
    if (manual) {
      _manualFallback = true;
      _usedFallback = true;
    }
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
      final captured = await camera.takePicture();
      _captures[_step.name] = File(captured.path);
      await HapticFeedback.mediumImpact();
      if (_step == _GuideStep.blink) {
        await _submit();
        return;
      }
      setState(() {
        _step =
            _step == _GuideStep.neutral ? _GuideStep.smile : _GuideStep.blink;
        _eligible = false;
        _sawOpenEyes = false;
        _manualFallback = false;
        _guidance = _guidanceFor(_step);
      });
      await camera.startImageStream(_processFrame);
      _startFallbackTimer();
    } catch (error) {
      _showFailure(_message(error));
    }
  }

  Future<void> _submit() async {
    await _disposeCamera();
    if (!mounted) return;
    setState(() => _state = _ScreenState.uploading);
    try {
      final deadline = await _service.uploadAndSubmit(
        captures: _captures,
        accessibilityFallback: _usedFallback,
      );
      await _deleteCaptures();
      if (!mounted) return;
      setState(() {
        _reviewDeadline = deadline;
        _state = _ScreenState.pending;
      });
      await HapticFeedback.heavyImpact();
    } catch (error) {
      await _deleteCaptures();
      _showFailure(_message(error));
    }
  }

  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer(const Duration(seconds: 7), () {
      if (mounted && _state == _ScreenState.guiding) {
        setState(() => _manualFallback = true);
      }
    });
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
    return InputImage.fromBytes(
      bytes: buffer.takeBytes(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotationValue.fromRawValue(
              camera.description.sensorOrientation,
            ) ??
            InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  String _guidanceFor(_GuideStep step) => switch (step) {
        _GuideStep.neutral => 'Look straight at the camera',
        _GuideStep.smile => 'Give a gentle smile',
        _GuideStep.blink => 'Blink once naturally',
      };

  void _showFailure(String reason) {
    unawaited(_disposeCamera());
    if (!mounted) return;
    setState(() {
      _failure = reason;
      _state = _ScreenState.failed;
    });
  }

  String _message(Object error) {
    final value = error.toString().replaceFirst('Bad state: ', '').trim();
    return value.isEmpty ? 'Photo verification could not be completed.' : value;
  }

  void _cancelTimers() {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _captureTimer?.cancel();
    _captureTimer = null;
  }

  Future<void> _disposeCamera() async {
    _cancelTimers();
    final camera = _camera;
    _camera = null;
    if (camera == null) return;
    try {
      if (camera.value.isStreamingImages) await camera.stopImageStream();
    } catch (_) {}
    await camera.dispose();
  }

  Future<void> _deleteCaptures() async {
    final files = _captures.values.toList();
    _captures.clear();
    for (final file in files) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pulse.dispose();
    _cancelTimers();
    unawaited(_disposeCamera());
    unawaited(_deleteCaptures());
    unawaited(_detector.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: switch (_state) {
        _ScreenState.pending => _resultView(
            icon: Icons.hourglass_top_rounded,
            title: 'Photo review in progress',
            message: _pendingMessage(),
            color: AppColors.champagneGold,
          ),
        _ScreenState.approved => _resultView(
            icon: Icons.verified_rounded,
            title: 'Photo verified',
            message:
                'Your profile photo check is approved. The badge confirms only that your temporary captures matched your current profile photo.',
            color: AppColors.verifiedTeal,
          ),
        _ScreenState.failed => _failedView(),
        _ScreenState.uploading => _uploadingView(),
        _ => _cameraView(),
      },
    );
  }

  Widget _cameraView() {
    final camera = _camera;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (camera != null && camera.value.isInitialized)
          CameraPreview(camera)
        else
          ColoredBox(color: AppColors.obsidianNight),
        const ColoredBox(color: Color(0x52000000)),
        SafeArea(
          child: Column(
            children: [
              _topBar('Photo verification'),
              const SizedBox(height: AppDimensions.space12),
              _stepIndicator(),
              const Spacer(),
              ScaleTransition(
                scale: _pulse,
                child: AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  width: MediaQuery.sizeOf(context).width * 0.72,
                  height: MediaQuery.sizeOf(context).width * 0.88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(180),
                    border: Border.all(
                      color: _eligible
                          ? AppColors.verifiedTeal
                          : AppColors.champagneGold,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_eligible
                                ? AppColors.verifiedTeal
                                : AppColors.champagneGold)
                            .withValues(alpha: 0.24),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppDimensions.space20),
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated.withValues(alpha: 0.96),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    AnimatedSwitcher(
                      duration: AppDimensions.durationTransition,
                      child: UiText(
                        _guidance,
                        key: ValueKey(_guidance),
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium.copyWith(
                          color: _eligible
                              ? AppColors.verifiedTeal
                              : AppColors.pearlWhite,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space6),
                    UiText(
                      'Keep normal glasses or hijab on. Smile guidance is optional when your face covering hides your mouth.',
                      style: AppTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    if (_manualFallback) ...[
                      const SizedBox(height: AppDimensions.space12),
                      TextButton.icon(
                        onPressed: () => _captureStep(manual: true),
                        icon: const Icon(Icons.camera_alt_rounded),
                        label: UiText(context.uiCopy('Capture this step')),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepIndicator() {
    final current = _GuideStep.values.indexOf(_step);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_GuideStep.values.length, (index) {
        final complete = index < current;
        final active = index == current;
        return AnimatedContainer(
          duration: AppDimensions.durationTransition,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: active ? 34 : 10,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: complete
                ? AppColors.verifiedTeal
                : active
                    ? AppColors.champagneGold
                    : AppColors.slateMist.withValues(alpha: 0.35),
          ),
        );
      }),
    );
  }

  Widget _uploadingView() => SafeArea(
        child: Column(
          children: [
            _topBar('Photo verification', canClose: false),
            const Spacer(),
            CircularProgressIndicator(color: AppColors.champagneGold),
            const SizedBox(height: AppDimensions.space24),
            UiText(context.uiCopy('Securing your temporary captures'),
                style: AppTypography.screenTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.space10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: UiText(
                context.uiCopy('Keep the app open for a moment.'),
                style: AppTypography.bodyMuted,
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
          ],
        ),
      );

  Widget _failedView() => _resultView(
        icon: Icons.camera_alt_outlined,
        title: 'Photo check not submitted',
        message: _failure ?? 'Please try again.',
        color: AppColors.softCoral,
        actionLabel: 'Try again',
        onAction: _initializeCamera,
      );

  Widget _resultView({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    String actionLabel = 'Done',
    VoidCallback? onAction,
  }) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.horizontalMargin),
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            const Spacer(),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.13),
                border: Border.all(color: color.withValues(alpha: 0.55)),
              ),
              child: Icon(icon, color: color, size: 38),
            ),
            const SizedBox(height: AppDimensions.space24),
            UiText(context.uiCopy(title),
                style: AppTypography.screenTitle, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.space10),
            UiText(context.uiCopy(message),
                style: AppTypography.bodyMuted, textAlign: TextAlign.center),
            const SizedBox(height: AppDimensions.space16),
            Container(
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_delete_outlined,
                      color: AppColors.verifiedTeal, size: 20),
                  const SizedBox(width: AppDimensions.space10),
                  Expanded(
                    child: UiText(
                      context.uiCopy(
                          'Temporary captures are deleted after review and no later than 48 hours. No face template is created.'),
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SilarahPressable(
              onTap: onAction ?? () => Navigator.of(context).pop(true),
              child: Container(
                width: double.infinity,
                height: AppDimensions.buttonHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: UiText(context.uiCopy(actionLabel),
                    style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar(String title, {bool canClose = true}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            IconButton(
              onPressed: canClose ? () => Navigator.of(context).pop() : null,
              icon: Icon(Icons.close_rounded, color: AppColors.pearlWhite),
            ),
            Expanded(
              child: UiText(context.uiCopy(title),
                  textAlign: TextAlign.center, style: AppTypography.bodyMedium),
            ),
            const SizedBox(width: 48),
          ],
        ),
      );

  String _pendingMessage() {
    final deadline = _reviewDeadline;
    if (deadline == null) {
      return context.uiCopy('Your temporary captures are awaiting review.');
    }
    final locale = Localizations.localeOf(context).toLanguageTag();
    final formattedDeadline =
        DateFormat.yMMMd(locale).add_jm().format(deadline.toLocal());
    return context
        .uiCopy(
          'Review is pending. Temporary captures delete after review and no later than {deadline}.',
        )
        .replaceAll('{deadline}', formattedDeadline);
  }
}
