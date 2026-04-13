// lib/features/onboarding/screens/photo_upload_screen.dart
// ============================================================
// NOOR — Photo Upload Screen (Onboarding Step 8)
// 4-slot grid. Slot 0 = verification selfie (mock face detection).
// Photo privacy toggle for women.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/step_header.dart';

class PhotoUploadScreen extends StatefulWidget {
  const PhotoUploadScreen({super.key});

  @override
  State<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends State<PhotoUploadScreen> {
  // In production: List<File?> paths. Here we track slots with labels.
  final List<String?> _slots = [null, null, null, null];
  bool _uploading = false;
  PhotoPrivacy _privacy = PhotoPrivacy.publicAll;

  bool get _hasAtLeastOne => _slots.any((s) => s != null);
  Gender? get _gender =>
      context.read<OnboardingCubit>().currentData.gender;

  /// Mocks an upload for a slot.
  Future<void> _mockUpload(int index, bool selfie) async {
    setState(() => _uploading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _slots[index] = selfie
          ? 'mock://selfie_${DateTime.now().millisecondsSinceEpoch}'
          : 'mock://photo_${DateTime.now().millisecondsSinceEpoch}';
      _uploading = false;
    });
  }

  void _removePhoto(int index) {
    setState(() => _slots[index] = null);
  }

  void _advance() {
    final paths = _slots.whereType<String>().toList();
    final data  = context.read<OnboardingCubit>().currentData.copyWith(
      photoLocalPaths: paths,
      photoPrivacy:    _privacy,
    );
    context.read<OnboardingCubit>().saveAndAdvance(data);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingCubit, OnboardingState>(
      builder: (context, state) {
        final isLoading = state is OnboardingLoading;
        return OnboardingScaffold(
          step:         8,
          ctaLabel:     'Continue',
          onCta:        _advance,
          isCtaEnabled: _hasAtLeastOne,
          isCtaLoading: isLoading,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.space32),
              const StepHeader(
                title:    'Add your photos',
                subtitle: 'At least one photo is required. Maximum four.',
              ),
              const SizedBox(height: AppDimensions.space24),

              // Face detection note
              Container(
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color:        AppColors.goldGlow,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.face_retouching_natural_outlined,
                        color: AppColors.champagneGold, size: 18),
                    const SizedBox(width: AppDimensions.space8),
                    Expanded(
                      child: Text(
                        'Each photo is scanned to ensure a visible face. '
                        'Group photos are not allowed as your primary photo.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.space24),

              // Photo grid (2 x 2)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount:    2,
                  crossAxisSpacing:  AppDimensions.space12,
                  mainAxisSpacing:   AppDimensions.space12,
                  childAspectRatio:  3 / 4,
                ),
                itemCount: 4,
                itemBuilder: (context, i) {
                  final isSelfie = i == 1;
                  return _PhotoSlot(
                    index:     i,
                    isSelfie:  isSelfie,
                    imagePath: _slots[i],
                    uploading: _uploading && _slots[i] == null,
                    onAdd:     () => _mockUpload(i, isSelfie),
                    onRemove:  () => _removePhoto(i),
                  );
                },
              ),

              // Slot labels
              const SizedBox(height: AppDimensions.space12),
              Row(
                children: const [
                  Expanded(child: Center(
                    child: _SlotLabel('Primary photo', isRequired: true),
                  )),
                  SizedBox(width: AppDimensions.space12),
                  Expanded(child: Center(
                    child: _SlotLabel('Verification selfie', isRequired: false),
                  )),
                ],
              ),

              // Privacy toggle for women
              if (_gender == Gender.female) ...[
                const SizedBox(height: AppDimensions.space24),
                Text('PHOTO PRIVACY', style: AppTypography.sectionLabel),
                const SizedBox(height: AppDimensions.space12),
                _PrivacyToggle(
                  current:   _privacy,
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
    required this.isSelfie,
    required this.imagePath,
    required this.uploading,
    required this.onAdd,
    required this.onRemove,
  });

  final int index;
  final bool isSelfie;
  final String? imagePath;
  final bool uploading;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: imagePath == null ? onAdd : null,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        decoration: BoxDecoration(
          color: imagePath != null
              ? AppColors.surfaceGlassHover
              : AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border: Border.all(
            color: imagePath != null
                ? AppColors.champagneGold.withValues(alpha: 0.4)
                : isSelfie
                    ? AppColors.verifiedTeal.withValues(alpha: 0.4)
                    : AppColors.cardBorder,
            width: imagePath != null ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imagePath != null)
              _MockPhotoFilled(isSelfie: isSelfie)
            else if (uploading)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.champagneGold,
                ),
              )
            else
              _EmptySlot(isSelfie: isSelfie),

            if (imagePath != null)
              Positioned(
                top: 8, right: 8,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color:  AppColors.softCoral.withValues(alpha: 0.9),
                      shape:  BoxShape.circle,
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
  const _EmptySlot({required this.isSelfie});
  final bool isSelfie;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          isSelfie ? Icons.camera_front_outlined : Icons.add_photo_alternate_outlined,
          color: isSelfie ? AppColors.verifiedTeal : AppColors.slateMist,
          size:  AppDimensions.iconSizeXLarge,
        ),
        const SizedBox(height: AppDimensions.space8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
          child: Text(
            isSelfie ? 'Selfie\n(camera only)' : 'Add photo',
            style: AppTypography.caption.copyWith(
              color: isSelfie ? AppColors.verifiedTeal : AppColors.slateMist,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MockPhotoFilled extends StatelessWidget {
  const _MockPhotoFilled({required this.isSelfie});
  final bool isSelfie;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: isSelfie
              ? [const Color(0xFF0D2B26), const Color(0xFF12121A)]
              : [const Color(0xFF1A1A2F), const Color(0xFF0A0A0F)],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelfie ? Icons.face_retouching_natural : Icons.person_outline_rounded,
            color: isSelfie ? AppColors.verifiedTeal : AppColors.champagneGold,
            size:  48,
          ),
          const SizedBox(height: AppDimensions.space8),
          Icon(Icons.check_circle_outline,
              color: AppColors.verifiedTeal, size: 20),
          const SizedBox(height: AppDimensions.space4),
          Text(
            isSelfie ? 'Selfie added' : 'Face detected',
            style: AppTypography.caption.copyWith(
              color: AppColors.verifiedTeal,
            ),
          ),
        ],
      ),
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
          Text('*', style: AppTypography.caption.copyWith(
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
    return Column(
      children: [
        _PrivacyTile(
          icon:       Icons.public_outlined,
          label:      'Visible to everyone',
          subtitle:   'All members can see your photos.',
          isSelected: current == PhotoPrivacy.publicAll,
          onTap:      () => onChanged(PhotoPrivacy.publicAll),
        ),
        const SizedBox(height: AppDimensions.space8),
        _PrivacyTile(
          icon:       Icons.lock_outline_rounded,
          label:      'Visible after mutual interest',
          subtitle:   'Photos only reveal when both parties express interest.',
          isSelected: current == PhotoPrivacy.mutualOnly,
          onTap:      () => onChanged(PhotoPrivacy.mutualOnly),
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
      onTap: onTap,
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
            width: isSelected ? AppDimensions.borderFocus : AppDimensions.borderThin,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppColors.champagneGold : AppColors.slateMist,
                size:  AppDimensions.iconSizeLarge),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.bodyMedium.copyWith(
                    color: isSelected ? AppColors.champagneGold : AppColors.pearlWhite,
                  )),
                  const SizedBox(height: AppDimensions.space4),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 20, height: 20,
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
