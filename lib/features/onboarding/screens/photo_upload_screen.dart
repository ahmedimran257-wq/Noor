// lib/features/onboarding/screens/photo_upload_screen.dart
// ============================================================
// SILARAH - Photo Upload Screen (fast-start step 5)
// 4-slot grid. Slot 0 = primary photo (required to proceed).
// Real image picking via image_picker (Camera / Gallery).
// Compression via flutter_image_compress (webp, 800px, q82).
// On-device explicit-content moderation; identity checks live separately.
// Photo privacy toggle for women.
// ============================================================

import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' show getTemporaryDirectory;
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/photo_moderation_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

// ── Face detection ─────────────────────────────────────────

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
  // Temp file paths for each slot
  final List<String?> _paths = [null, null, null, null];
  final List<PhotoModerationResult?> _moderation = [null, null, null, null];
  final List<String?> _remoteUrls = [null, null, null, null];
  final List<String?> _initialRemoteUrls = [null, null, null, null];
  final Set<int> _removedRemoteSlots = <int>{};
  bool _uploading = false;
  bool _isScanning = false;
  bool _loadingExisting = false;
  String? _existingLoadError;
  PhotoPrivacy _privacy = PhotoPrivacy.publicAll;

  @override
  void initState() {
    super.initState();
    final data = context.read<OnboardingCubit>().currentData;
    _privacy = data.photoPrivacy ?? PhotoPrivacy.publicAll;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(PhotoModerationService.warmUp().catchError((_) {}));
    });
    if (widget.returnToPreviousOnSave) {
      _loadingExisting = true;
      unawaited(_loadExistingPhotos());
    } else if (data.photoLocalPaths != null) {
      for (final path in data.photoLocalPaths!) {
        final file = File(path);
        if (file.existsSync()) {
          final fileName = file.path.split('/').last.split('\\').last;
          final match =
              RegExp(r'silarah_photo_slot_(\d+)').firstMatch(fileName);
          if (match != null) {
            final idx = int.parse(match.group(1)!);
            if (idx >= 0 && idx < 4) {
              final bytes = file.readAsBytesSync();
              _bytes[idx] = bytes;
              _paths[idx] = path;
              unawaited(_restoreLocalModeration(idx, path));
            }
          }
        }
      }
    }
  }

  Future<void> _restoreLocalModeration(int index, String path) async {
    final moderation = await PhotoModerationService.instance.scanFile(path);
    if (!mounted || _paths[index] != path) return;
    setState(() => _moderation[index] = moderation);
    if (!moderation.canUpload) {
      _removePhoto(index);
      _showPhotoSafetyError(_photoModerationMessage(moderation));
    }
  }

  Future<void> _loadExistingPhotos() async {
    try {
      final slots = await ProfilePhotoService.instance.getMyPhotoSlots();
      if (!mounted) return;
      setState(() {
        for (var i = 0; i < 4; i++) {
          final url = slots[i];
          _remoteUrls[i] = url;
          _initialRemoteUrls[i] = url;
        }
        _existingLoadError = null;
        _loadingExisting = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _existingLoadError = error is StateError
            ? error.message
            : 'Your photos could not be loaded. Please try again.';
        _loadingExisting = false;
      });
    }
  }

  bool get _hasPrimary => _bytes[0] != null || _remoteUrls[0] != null;
  bool get _primaryReady =>
      _remoteUrls[0] != null ||
      (_bytes[0] != null && _moderation[0]?.canUpload == true);
  Gender? get _gender => context.read<OnboardingCubit>().currentData.gender;

  /// Picks, compresses, validates, and explicit-content scans a photo.
  Future<void> _pickPhoto(int index) async {
    if (_isScanning || _uploading) return;
    setState(() {
      _isScanning = true;
      _uploading = true;
    });

    final ImageSource? source;

    source = await _showSourceSheet();

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
    final file = File('${tempDir.path}/silarah_photo_slot_$index.webp');
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
    if (moderation.decision == PhotoModerationDecision.flagged) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: const Text(
              'Explicit content was detected. This photo will be reviewed and will not appear publicly.',
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
    _moderation[index] = moderation;

    setState(() {
      _bytes[index] = bytes;
      _remoteUrls[index] = null;
      _removedRemoteSlots.remove(index);
    });
  }

  String _photoModerationMessage(PhotoModerationResult moderation) {
    if (moderation.category == 'invalid_image') {
      return 'Choose a valid, non-blank image file.';
    }
    return 'This photo could not be safety checked. Please choose another image.';
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
    final hadLocalPhoto = _paths[index] != null;
    if (hadLocalPhoto) {
      final file = File(_paths[index]!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }
    setState(() {
      _bytes[index] = null;
      _paths[index] = null;
      _moderation[index] = null;
      if (hadLocalPhoto && _initialRemoteUrls[index] != null) {
        // Removing an unsaved replacement restores the server photo instead
        // of unexpectedly deleting it.
        _remoteUrls[index] = _initialRemoteUrls[index];
        _removedRemoteSlots.remove(index);
      } else if (_remoteUrls[index] != null) {
        _remoteUrls[index] = null;
        _removedRemoteSlots.add(index);
      }
    });
  }

  Future<void> _advance() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_uploading || _loadingExisting) {
      return;
    }
    if (!_hasPrimary) {
      _showSaveRequirement('Add a main photo before saving.');
      return;
    }
    if (!_primaryReady) {
      _showSaveRequirement('Wait for the main photo safety check to finish.');
      return;
    }
    final localSlots = <int, String>{};
    for (int i = 0; i < 4; i++) {
      if (_paths[i] != null) localSlots[i] = _paths[i]!;
    }
    final paths = localSlots.values.toList(growable: false);
    final data = context.read<OnboardingCubit>().currentData.copyWith(
          photoLocalPaths: paths,
          photoPrivacy: _privacy,
        );
    setState(() => _uploading = true);
    try {
      final primaryModeration =
          await ProfilePhotoService.instance.syncPhotoSlots(
        localSlots,
        privacy: _privacy,
      );
      for (final slot in _removedRemoteSlots.toList()..sort()) {
        await ProfilePhotoService.instance.deleteMyPhotoSlot(slot);
      }
      if (primaryModeration?.decision == PhotoModerationDecision.approved) {
        await _makeProfileLive();
      }
      if (!mounted) return;
      final cubit = context.read<OnboardingCubit>();
      if (widget.returnToPreviousOnSave) {
        final saved = await cubit.updateProfile(data);
        if (!mounted) return;
        if (saved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photos saved.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
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

  void _showSaveRequirement(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: AppTypography.body),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
        ),
      );
  }

  void _explainDisabledSave() {
    if (_loadingExisting) {
      _showSaveRequirement('Loading your current photos…');
    } else if (_existingLoadError != null) {
      _showSaveRequirement(_existingLoadError!);
    } else if (!_hasPrimary) {
      _showSaveRequirement('Add a main photo before saving.');
    } else if (!_primaryReady) {
      _showSaveRequirement('Wait for the main photo safety check to finish.');
    }
  }

  Future<void> _makeProfileLive() async {
    final currentUserId = SupabaseService.currentUserId;
    if (currentUserId == null) {
      throw StateError('Please sign in again to publish your profile.');
    }

    await SupabaseService.client
        .from('profiles')
        .update({'visibility': 'visible'}).eq('user_id', currentUserId);

    try {
      final response = await SupabaseService.client.functions.invoke(
        'dispatch-notifications',
        body: {
          'user_id': currentUserId,
          'type': 'profile_live',
          'title': 'Your profile is now live! 🎉',
          'body': 'Muslims in your area can now find you on Silarah.',
        },
      );
      if (response.status < 200 || response.status >= 300) {
        debugPrint(
          '[PhotoUploadScreen] profile_live notification dispatch failed: ${response.status}',
        );
      }
    } catch (error) {
      // Publishing succeeded. Notification delivery is retried by the server
      // queue and must not send the user back through photo onboarding.
      debugPrint(
        '[PhotoUploadScreen] profile_live notification dispatch failed: $error',
      );
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
          ctaLabel: widget.returnToPreviousOnSave
              ? 'Save photos'
              : l10n.legal_button_continue,
          onCta: _advance,
          onBack: widget.returnToPreviousOnSave
              ? () => Navigator.pop(context, false)
              : null,
          showProgressHeader: !widget.returnToPreviousOnSave,
          headerTitle: 'Profile photos',
          isCtaEnabled: _hasPrimary &&
              _primaryReady &&
              !_uploading &&
              !_loadingExisting &&
              _existingLoadError == null,
          isCtaLoading: isLoading || _uploading || _loadingExisting,
          onCtaDisabledTap: _explainDisabledSave,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              StepHeader(
                title: widget.returnToPreviousOnSave
                    ? 'Manage your photos'
                    : (isGuardian
                        ? l10n.photo_title_guardian
                        : l10n.photo_title_self),
                subtitle: widget.returnToPreviousOnSave
                    ? 'Update your profile photos and privacy. Every photo is checked before it can appear publicly.'
                    : (isGuardian
                        ? l10n.photo_subtitle_guardian(getRelationString())
                        : l10n.photo_subtitle_self),
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
              if (_existingLoadError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.space12),
                  decoration: BoxDecoration(
                    color: AppColors.softCoral.withValues(alpha: 0.09),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: AppColors.softCoral.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: AppColors.softCoral, size: 20),
                      const SizedBox(width: AppDimensions.space10),
                      Expanded(
                        child: Text(
                          _existingLoadError!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.pearlWhite,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _loadingExisting = true;
                            _existingLoadError = null;
                          });
                          unawaited(_loadExistingPhotos());
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
              ],
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
                    remoteUrl: _remoteUrls[i],
                    moderation: _moderation[i],
                    uploading: (_loadingExisting || _uploading) &&
                        _bytes[i] == null &&
                        _remoteUrls[i] == null,
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
    required this.remoteUrl,
    required this.moderation,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final int index;
  final bool isPrimary;
  final Uint8List? bytes;
  final String? remoteUrl;
  final PhotoModerationResult? moderation;
  final bool uploading;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isRemote = bytes == null && remoteUrl != null;
    final isFilled = bytes != null || isRemote;
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
                child: bytes != null
                    ? Image.memory(bytes!, fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: remoteUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 480,
                        maxWidthDiskCache: 640,
                        placeholder: (_, __) => const Center(
                          child: SilarahPulseLoader(size: 34),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppColors.surfaceGlass,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.slateMist,
                            size: 32,
                          ),
                        ),
                      ),
              )
            else if (uploading)
              const Center(child: SilarahPulseLoader(size: 34))
            else
              _EmptySlot(isPrimary: isPrimary),

            // Content-safety status. Face/liveness status is intentionally not
            // represented here; it belongs to badge verification.
            if (isFilled && (moderation != null || isRemote))
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
                    color:
                        moderation?.decision == PhotoModerationDecision.flagged
                            ? AppColors.champagneGold.withValues(alpha: 0.92)
                            : AppColors.verifiedTeal.withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(AppDimensions.radiusCard),
                      bottomRight: Radius.circular(AppDimensions.radiusCard),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        moderation?.decision == PhotoModerationDecision.flagged
                            ? Icons.policy_outlined
                            : Icons.shield_outlined,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        moderation?.decision == PhotoModerationDecision.flagged
                            ? 'Review required'
                            : 'Content checked',
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
