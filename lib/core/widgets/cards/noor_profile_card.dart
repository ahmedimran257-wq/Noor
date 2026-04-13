// lib/core/widgets/cards/noor_profile_card.dart
// ============================================================
// The NOOR Card — "The Discovery Engine"
// "The most critical component. It must look like a
//  luxury portfolio cover."
//
// Ratio: 3:4 Portrait
// Border: 1px solid rgba(255,255,255,0.1)
// Gradient: Transparent (top) → 30% Obsidian (mid) → 100% Obsidian (bottom)
// Name: Playfair Display 24px, bottom-left
// Location: Inter 14px, below name
// Focus effect: center card scale 1.0, adjacent cards scale 0.95
// ============================================================

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../buttons/noor_pressable.dart';

class NoorProfileCard extends StatelessWidget {
  const NoorProfileCard({
    super.key,
    required this.firstName,
    required this.lastNameInitial,
    required this.age,
    required this.cityName,
    this.sect,
    this.deenLevel,
    this.photoUrl,
    this.photoCount = 0,
    this.isPhotoPrivate = false,
    this.isVerified = false,
    this.isFocused = true,          // Controls the scale focus effect
    this.onTap,
    this.onSendInterest,
    this.onBookmark,
    this.isInterestSent = false,
  });

  final String firstName;
  final String lastNameInitial;
  final int age;
  final String cityName;
  final String? sect;
  final String? deenLevel;
  final String? photoUrl;
  final int photoCount;
  final bool isPhotoPrivate;
  final bool isVerified;
  final bool isFocused;
  final VoidCallback? onTap;
  final VoidCallback? onSendInterest;
  final VoidCallback? onBookmark;
  final bool isInterestSent;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale:    isFocused ? 1.0 : 0.95,
      duration: AppDimensions.durationTransition,
      curve:    Curves.easeInOutQuart,
      child: NoorPressable(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: AppDimensions.cardAspectRatio,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: AppColors.cardBorder,
                width: AppDimensions.borderThin,
              ),
              color: AppColors.surfaceGlass,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Photo Layer ──────────────────────────────
                if (photoUrl != null && !isPhotoPrivate)
                  _PhotoLayer(url: photoUrl!)
                else
                  _PrivatePhotoPlaceholder(
                    photoCount: photoCount,
                    isPrivate:  isPhotoPrivate,
                  ),

                // ── Gradient Overlay (always on top of photo)
                const _GradientOverlay(),

                // ── Content Layer ────────────────────────────
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.space20),
                    child: Column(
                      children: [
                        // Verified badge — top right
                        if (isVerified)
                          Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: _VerifiedBadge(),
                          ),
                        const Spacer(),

                        // Name + location + chips — bottom
                        Align(
                          alignment: AlignmentDirectional.bottomStart,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Name
                              Text(
                                '$firstName $lastNameInitial.',
                                style: AppTypography.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppDimensions.space4),

                              // Age · City
                              Text(
                                '$age · $cityName',
                                style: AppTypography.cardLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                              // Chips row
                              if (sect != null || deenLevel != null) ...[
                                const SizedBox(height: AppDimensions.space12),
                                Wrap(
                                  spacing: AppDimensions.space8,
                                  runSpacing: AppDimensions.space6,
                                  children: [
                                    if (sect != null)
                                      _InfoChip(label: sect!),
                                    if (deenLevel != null)
                                      _InfoChip(label: _formatDeen(deenLevel!)),
                                  ],
                                ),
                              ],

                              const SizedBox(height: AppDimensions.space16),

                              // Action row: bookmark + send interest
                              Row(
                                children: [
                                  // Bookmark
                                  _IconActionButton(
                                    icon:    Icons.bookmark_outline_rounded,
                                    onTap:   onBookmark,
                                    tooltip: 'Save',
                                  ),
                                  const SizedBox(width: AppDimensions.space12),

                                  // Send Interest — fills remaining space
                                  Expanded(
                                    child: _SendInterestButton(
                                      isSent:  isInterestSent,
                                      onTap:   isInterestSent ? null : onSendInterest,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDeen(String raw) {
    switch (raw) {
      case 'practicing': return 'Practicing';
      case 'moderate':   return 'Moderate';
      case 'cultural':   return 'Cultural';
      default:           return raw;
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────

class _PhotoLayer extends StatelessWidget {
  const _PhotoLayer({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _PhotoError(),
      loadingBuilder: (context, child, chunk) {
        if (chunk == null) return child;
        return Container(color: AppColors.surfaceGlassHover);
      },
    );
  }
}

class _PhotoError extends StatelessWidget {
  const _PhotoError();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceGlassHover,
      child: const Center(
        child: Icon(
          Icons.person_outline_rounded,
          color: AppColors.slateMist,
          size: 64,
        ),
      ),
    );
  }
}

class _PrivatePhotoPlaceholder extends StatelessWidget {
  const _PrivatePhotoPlaceholder({
    required this.photoCount,
    required this.isPrivate,
  });
  final int photoCount;
  final bool isPrivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceGlassHover,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Gold ring silhouette placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.goldBorder,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.slateMist,
                size: 40,
              ),
            ),
            if (isPrivate && photoCount > 0) ...[
              const SizedBox(height: AppDimensions.space12),
              Text(
                '$photoCount photo${photoCount > 1 ? 's' : ''} · visible after acceptance',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientOverlay extends StatelessWidget {
  const _GradientOverlay();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end:   Alignment.bottomCenter,
          colors: [
            AppColors.cardGradientTop,    // Transparent
            AppColors.cardGradientMid,    // 30% opacity
            AppColors.cardGradientBottom, // Fully opaque
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        AppColors.verifiedTeal.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.verifiedTeal,
          width: AppDimensions.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.verifiedTeal,
            size:  12,
          ),
          const SizedBox(width: AppDimensions.space4),
          Text(
            'Verified',
            style: AppTypography.caption.copyWith(
              color: AppColors.verifiedTeal,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical:   AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.cardBorder,
          width: AppDimensions.borderThin,
        ),
      ),
      child: Text(label, style: AppTypography.chipLabel),
    );
  }
}

class _SendInterestButton extends StatelessWidget {
  const _SendInterestButton({required this.isSent, this.onTap});
  final bool isSent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NoorPressable(
      onTap:   onTap,
      enabled: !isSent,
      child: AnimatedContainer(
        duration: AppDimensions.durationTransition,
        height: 44,
        decoration: BoxDecoration(
          color: isSent
              ? AppColors.champagneGold.withValues(alpha: 0.15)
              : AppColors.champagneGold,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: isSent
              ? Border.all(color: AppColors.champagneGold, width: AppDimensions.borderThin)
              : null,
        ),
        child: Center(
          child: Text(
            isSent ? 'Interest Sent ✓' : 'Send Interest',
            style: isSent
                ? AppTypography.button.copyWith(
                    color: AppColors.champagneGold,
                    fontSize: 14,
                  )
                : AppTypography.button.copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return NoorPressable(
      onTap: onTap,
      child: Container(
        width:  44,
        height: 44,
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: AppColors.cardBorder,
            width: AppDimensions.borderThin,
          ),
        ),
        child: Icon(
          icon,
          color: AppColors.pearlWhite,
          size:  AppDimensions.iconSizeMedium,
        ),
      ),
    );
  }
}
