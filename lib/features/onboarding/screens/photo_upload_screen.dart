// lib/features/onboarding/screens/photo_upload_screen.dart
// ============================================================
// MITHAQ - Photo Upload Screen (fast-start step 5)
// 4-slot grid. Slot 0 = primary photo (required to proceed).
// Real image picking via image_picker (Camera / Gallery).
// Compression via flutter_image_compress (webp, 800px, q82).
// On-device face detection via Google ML Kit (free, no API cost).
// Photo privacy toggle for women.
// ============================================================

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/photo_moderation_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Face detection ─────────────────────────────────────────

enum _FaceResult { found, notFound }

/// On-device face detection using Google ML Kit (zero API cost).
/// Writes bytes to a temp file, runs FaceDetector, cleans up.
Future<_FaceResult> _detectFace(Uint8List bytes) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final analysisBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 800,
      minHeight: 800,
      quality: 90,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final tempFile = File(
      '${tempDir.path}/mithaq_face_check_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await tempFile.writeAsBytes(analysisBytes);

    final inputImage = InputImage.fromFilePath(tempFile.path);
    final detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableContours: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
      ),
    );

    final faces = await detector.processImage(inputImage);
    await detector.close();

    // Clean up temp file
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    return faces.isNotEmpty ? _FaceResult.found : _FaceResult.notFound;
  } catch (_) {
    // Fail closed: an unavailable detector must not make a photo eligible for
    // the primary-profile requirement.
    return _FaceResult.notFound;
  }
}

// ── Screen ────────────────────────────────────────────────────

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({
    super.key,
    this.returnToPreviousOnSave = false,
  });

  final bool returnToPreviousOnSave;

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  final _picker = ImagePicker();

  // Compressed bytes for each slot (null = empty)
  final List<Uint8List?> _bytes = [null, null, null, null];
  // Face detection result per slot
  final List<_FaceResult?> _faces = [null, null, null, null];
  // Temp file paths for each slot
  final List<String?> _paths = [null, null, null, null];
  bool _uploading = false;
  bool _isScanning = false;
  PhotoPrivacy _privacy = PhotoPrivacy.publicAll;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _privacy = data.photoPrivacy ?? PhotoPrivacy.publicAll;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PhotoModerationService.warmUp().catchError((_) {}));
    });
    if (data.photoLocalPaths != null) {
      for (final path in data.photoLocalPaths!) {
        final file = File(path);
        if (file.existsSync()) {
          final fileName = file.path.split('/').last.split('\\').last;
          final match = RegExp(r'mithaq_photo_slot_(\d+)').firstMatch(fileName);
          if (match != null) {
            final idx = int.parse(match.group(1)!);
            if (idx >= 0 && idx < 4) {
              final bytes = file.readAsBytesSync();
              _bytes[idx] = bytes;
              _paths[idx] = path;
              _detectFace(bytes).then((face) {
                if (mounted) {
                  setState(() {
                    _faces[idx] = face;
                  });
                }
              });
            }
          }
        }
      }
    }
  }

  bool get _hasPrimary => _bytes[0] != null;
  Gender? get _gender => context.read<OnboardingCubit>().currentData.gender;

  /// Shows bottom sheet to pick source, then picks + compresses + scans.
  /// For slot 3 (verification selfie), forces camera — no gallery access.
  Future<void> _pickPhoto(int index) async {
    if (_isScanning || _uploading) return;
    setState(() {
      _isScanning = true;
      _uploading = true;
    });

    final ImageSource? source;

    // T1: Enforce proof-of-life selfie — slot 3 is camera-only
    if (index == 3) {
      source = ImageSource.camera;
    } else {
      source = await _showSourceSheet();
    }

    if (source == null) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _uploading = false;
        });
      }
      return;
    }
    if (!mounted) return;

    try {
      final XFile? xfile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );
      if (xfile == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      if (!mounted) return;

      // Compress to webp
      final result = await FlutterImageCompress.compressWithFile(
        xfile.path,
        minWidth: 800,
        minHeight: 800,
        quality: 82,
        format: CompressFormat.webp,
        keepExif: false,
      );

      if (!mounted) return;

      if (result == null) {
        // Fallback: use raw bytes
        final raw = await File(xfile.path).readAsBytes();
        await _setSlot(index, raw);
      } else {
        await _setSlot(index, result);
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.photo_error_pick_failed(e.toString()),
                style: AppTypography.body),
            backgroundColor: AppColors.softCoral,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _uploading = false;
        });
      }
    }
  }

  Future<void> _setSlot(int index, Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/mithaq_photo_slot_$index.webp');
    await file.writeAsBytes(bytes);

    final moderation =
        await PhotoModerationService.instance.scanFile(file.path);
    if (!mounted) return;
    if (!moderation.canUpload) {
      await file.delete().catchError((_) => file);
      if (moderation.decision == PhotoModerationDecision.scanFailed) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        _showPhotoSafetyError(
          'Safety check failed. Please try a different photo or try again.',
        );
        return;
      }

      _showPhotoSafetyError(_photoModerationMessage(moderation));
      return;
    }
    if (moderation.decision == PhotoModerationDecision.pendingReview) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'This photo will be reviewed before it appears publicly.',
              style: AppTypography.body,
            ),
            backgroundColor: AppColors.surfaceGlassHover,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              side: const BorderSide(color: AppColors.goldBorder),
            ),
          ),
        );
    }

    _paths[index] = file.path;

    // Show loading while face detection runs
    setState(() {
      _bytes[index] = bytes;
      _faces[index] = null; // pending
    });

    final face = await _detectFace(bytes);
    if (!mounted) return;

    setState(() {
      _faces[index] = face;
    });

    if (face == _FaceResult.notFound) {
      _removePhoto(index);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: AppDimensions.space8),
            Expanded(
              child: Text(
                l10n.photo_error_no_face_detected,
                style: AppTypography.body,
              ),
            ),
          ]),
          backgroundColor: AppColors.softCoral,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          ),
        ),
      );
    }
  }

  String _photoModerationMessage(PhotoModerationResult moderation) {
    if (moderation.category == 'no_face') {
      return "We couldn't detect a face. Please upload a photo clearly showing your face.";
    }
    return 'This photo cannot be accepted. Please upload a clear portrait photo.';
  }

  Future<ImageSource?> _showSourceSheet() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceMid,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppDimensions.space16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.slateMist.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppDimensions.space20),
            Text(l10n.photo_add_photo, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: AppColors.champagneGold),
              title: Text(l10n.photo_sheet_camera, style: AppTypography.body),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: AppColors.champagneGold),
              title: Text(l10n.photo_sheet_gallery, style: AppTypography.body),
              onTap: () => Navigator.pop(sheetCtx, ImageSource.gallery),
            ),
            const SizedBox(height: AppDimensions.space16),
          ],
        ),
      ),
    );
  }

  void _removePhoto(int index) {
    if (_paths[index] != null) {
      final file = File(_paths[index]!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    setState(() {
      _bytes[index] = null;
      _faces[index] = null;
      _paths[index] = null;
    });
  }

  Future<void> _advance() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_uploading || !_hasPrimary || _faces[0] != _FaceResult.found) {
      return;
    }
    final paths = <String>[];
    for (int i = 0; i < 4; i++) {
      if (_paths[i] != null) paths.add(_paths[i]!);
    }
    final data = context.read<OnboardingCubit>().currentData.copyWith(
          photoLocalPaths: paths,
          photoPrivacy: _privacy,
        );
    setState(() => _uploading = true);
    try {
      await ProfilePhotoService.instance.syncLocalPhotos(
        paths,
        privacy: _privacy,
      );
      if (!mounted) return;
      final cubit = context.read<OnboardingCubit>();
      if (widget.returnToPreviousOnSave) {
        cubit.updateProfile(data);
        Navigator.pop(context, true);
      } else {
        await cubit.saveAndAdvance(data);
      }
    } catch (e) {
      if (!mounted) return;
      final message = e is StateError
          ? e.message
          : 'Could not upload photos. Please try again.';
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(message, style: AppTypography.body),
            backgroundColor: AppColors.surfaceGlassHover,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showPhotoSafetyError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.body),
        backgroundColor: AppColors.softCoral,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        final obData = context.read<OnboardingCubit>().currentData;
        final isGuardian = obData.isGuardianMode;
        final relation = obData.profileCreatorRelation ?? 'ward';

        String getRelationString() {
          switch (relation) {
            case 'son':
              return l10n.onboarding_profileForWhom_relation_son.toLowerCase();
            case 'daughter':
              return l10n.onboarding_profileForWhom_relation_daughter
                  .toLowerCase();
            case 'brother':
              return l10n.onboarding_profileForWhom_relation_brother
                  .toLowerCase();
            case 'sister':
              return l10n.onboarding_profileForWhom_relation_sister
                  .toLowerCase();
            default:
              return l10n.onboarding_profileForWhom_ward.toLowerCase();
          }
        }

        return OnboardingScaffold(
          ctaLabel: l10n.legal_button_continue,
          onCta: _advance,
          isCtaEnabled:
              _hasPrimary && !_uploading && _faces[0] == _FaceResult.found,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title: isGuardian
                    ? l10n.photo_title_guardian
                    : l10n.photo_title_self,
                subtitle: isGuardian
                    ? l10n.photo_subtitle_guardian(getRelationString())
                    : l10n.photo_subtitle_self,
              ),
              const SizedBox(height: AppDimensions.space24),

              // Face detection info banner
              Container(
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color: AppColors.goldGlow,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.face_retouching_natural_outlined,
                        color: AppColors.champagneGold, size: 18),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        l10n.photo_banner_text,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Photo grid (2 × 2)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppDimensions.space12,
                  mainAxisSpacing: AppDimensions.space12,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: 4,
                itemBuilder: (context, i) {
                  return _PhotoSlot(
                    index: i,
                    isPrimary: i == 0,
                    bytes: _bytes[i],
                    faceResult: _faces[i],
                    uploading: _uploading && _bytes[i] == null,
                    onAdd: () => _pickPhoto(i),
                    onRemove: () => _removePhoto(i),
                  );
                },
              ),

              // Slot labels
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: [
                  Expanded(
                      child: Center(
                    child:
                        _SlotLabel(l10n.photo_label_primary, isRequired: true),
                  )),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                      child: Center(
                    child:
                        _SlotLabel(l10n.photo_label_photo2, isRequired: false),
                  )),
                ],
              ),
              const SizedBox(height: AppDimensions.space4),
              Row(
                children: [
                  Expanded(
                      child: Center(
                    child:
                        _SlotLabel(l10n.photo_label_photo3, isRequired: false),
                  )),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                      child: Center(
                    child:
                        _SlotLabel(l10n.photo_label_selfie, isRequired: false),
                  )),
                ],
              ),

              // Privacy toggle for women
              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space24),
                Text(l10n.photo_privacy_label,
                    style: AppTypography.sectionLabel),
                const SizedBox(height: AppDimensions.space12),
                _PrivacyToggle(
                  current: _privacy,
                  onChanged: (p) => setState(() => _privacy = p),
                ),
              ],

              const SizedBox(height: AppDimensions.space32),
            ],
          ),
        );
      },
    );
  }
}

// ── Photo slot ────────────────────────────────────────────────

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.index,
    required this.isPrimary,
    required this.bytes,
    required this.faceResult,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final int index;
  final bool isPrimary;
  final Uint8List? bytes;
  final _FaceResult? faceResult;
  final bool uploading;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFilled = bytes != null;
    return GestureDetector(
      onTap: isFilled
          ? null
          : () {
              FocusManager.instance.primaryFocus?.unfocus();
              onAdd();
            },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        decoration: BoxDecoration(
          color:
              isFilled ? AppColors.surfaceGlassHover : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: isFilled
                ? AppColors.champagneGold.withValues(alpha: 0.4)
                : isPrimary
                    ? AppColors.champagneGold.withValues(alpha: 0.3)
                    : AppColors.cardBorder,
            width:
                isFilled ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isFilled)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                child: Image.memory(
                  bytes!,
                  fit: BoxFit.cover,
                ),
              )
            else if (uploading)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.champagneGold,
                ),
              )
            else
              _EmptySlot(isPrimary: isPrimary),

            // Face detection banner (bottom of filled slot)
            if (isFilled && faceResult != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space8,
                    vertical: AppDimensions.space4,
                  ),
                  decoration: BoxDecoration(
                    color: faceResult == _FaceResult.found
                        ? AppColors.verifiedTeal.withValues(alpha: 0.9)
                        : AppColors.softCoral.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppDimensions.radiusCard),
                      bottomRight: Radius.circular(AppDimensions.radiusCard),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        faceResult == _FaceResult.found
                            ? Icons.check_circle_outline_rounded
                            : Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        faceResult == _FaceResult.found
                            ? l10n.photo_face_detected
                            : l10n.photo_no_face,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Remove button
            if (isFilled)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    onRemove();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.softCoral.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.isPrimary});
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isPrimary
              ? Icons.add_photo_alternate_outlined
              : Icons.add_a_photo_outlined,
          color: isPrimary ? AppColors.champagneGold : AppColors.slateMist,
          size: AppDimensions.iconSizeXLarge,
        ),
        const SizedBox(height: AppDimensions.space8),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
          child: Text(
            isPrimary ? l10n.photo_add_main_required : l10n.photo_add_photo,
            style: AppTypography.caption.copyWith(
              color: isPrimary ? AppColors.champagneGold : AppColors.slateMist,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _SlotLabel extends StatelessWidget {
  const _SlotLabel(this.text, {required this.isRequired});
  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: AppTypography.caption),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text('*',
              style: AppTypography.caption.copyWith(
                color: AppColors.softCoral,
              )),
        ],
      ],
    );
  }
}

// ── Privacy toggle ────────────────────────────────────────────

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.current, required this.onChanged});
  final PhotoPrivacy current;
  final ValueChanged<PhotoPrivacy> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        _PrivacyTile(
          icon: Icons.public_outlined,
          label: l10n.photo_privacy_everyone,
          subtitle: l10n.photo_privacy_everyone_sub,
          isSelected: current == PhotoPrivacy.publicAll,
          onTap: () => onChanged(PhotoPrivacy.publicAll),
        ),
        const SizedBox(height: AppDimensions.space8),
        _PrivacyTile(
          icon: Icons.lock_outline_rounded,
          label: l10n.photo_privacy_mutual,
          subtitle: l10n.photo_privacy_mutual_sub,
          isSelected: current == PhotoPrivacy.mutualOnly,
          onTap: () => onChanged(PhotoPrivacy.mutualOnly),
        ),
        const SizedBox(height: AppDimensions.space8),
        _PrivacyTile(
          icon: Icons.visibility_off_outlined,
          label: l10n.photo_privacy_request,
          subtitle: l10n.photo_privacy_request_sub,
          isSelected: current == PhotoPrivacy.requestOnly,
          onTap: () => onChanged(PhotoPrivacy.requestOnly),
        ),
      ],
    );
  }
}

class _PrivacyTile extends StatelessWidget {
  const _PrivacyTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.champagneGold.withValues(alpha: 0.08)
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
            width: isSelected
                ? AppDimensions.borderFocus
                : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color:
                    isSelected ? AppColors.champagneGold : AppColors.slateMist,
                size: AppDimensions.iconSizeLarge),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected
                            ? AppColors.champagneGold
                            : AppColors.pearlWhite,
                      )),
                  const SizedBox(height: AppDimensions.space4),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.champagneGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}
