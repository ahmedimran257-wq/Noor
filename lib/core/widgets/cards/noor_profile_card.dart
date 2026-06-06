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
import '../loaders/noor_blur_image.dart';

class NoorProfileCard extends StatelessWidget {
  const NoorProfileCard({
    super.key,
    required this.firstName,
    required this.lastNameInitial,
    required this.age,
    required this.cityName,
    this.sect,
    this.deenLevel,
    this.profession,
    this.photoUrl,
    this.photoCount = 0,
    this.isPhotoPrivate = false,
    this.isVerified = false,
    this.isFocused = true,          // Controls the scale focus effect
    this.onTap,
    this.onSendInterest,
    this.onBookmark,
    this.isInterestSent = false,
    this.lastActiveLabel,
    this.cardScale = 1.0,
    this.blurhash,
  });

  final String firstName;
  final String lastNameInitial;
  final int age;
  final String cityName;
  final String? sect;
  final String? deenLevel;
  final String? profession;   // blueprint: shown on card below location
  final String? photoUrl;
  final int photoCount;
  final bool isPhotoPrivate;
  final bool isVerified;
  final bool isFocused;
  final VoidCallback? onTap;
  final VoidCallback? onSendInterest;
  final VoidCallback? onBookmark;
  final bool isInterestSent;
  final String? lastActiveLabel;
  final double cardScale;  // Continuous scale driven by scroll offset
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: cardScale,
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
                  _PhotoLayer(url: photoUrl!, blurhash: blurhash)
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
                        // Top row: verified badge (left) + photo count pill (right)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo count pill — public, multiple photos
                            if (!isPhotoPrivate && photoCount > 1)
                              _PhotoCountPill(count: photoCount)
                            else
                              const SizedBox.shrink(),

                            // Verified badge — top right
                            if (isVerified)
                              _VerifiedBadge()
                            else if (lastActiveLabel != null && lastActiveLabel!.isNotEmpty)
                              _LastActivePill(label: lastActiveLabel!)
                            else
                              const SizedBox.shrink(),
                          ],
                        ),
                        const Spacer(),

                        // Names + location + chips — bottom
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

                              // Profession line
                              if (profession != null) ...[
                                const SizedBox(height: AppDimensions.space4),
                                Text(
                                  profession!,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.pearlWhite.withValues(alpha: 0.7),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],

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

                // Item 20: frosted lock pill — private photos, bottom-center
                if (isPhotoPrivate && photoCount > 0)
                  Positioned(
                    bottom: 90,  // above the action row
                    left:   0,
                    right:  0,
                    child:  Center(
                      child: _FrostedPhotoPill(photoCount: photoCount),
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
  const _PhotoLayer({required this.url, this.blurhash});
  final String url;
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    return NoorBlurImage(
      imageUrl: url,
      blurhash: blurhash,
      fit: BoxFit.cover,
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
    return const DecoratedBox(
      decoration: BoxDecoration(
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

// Item 20: Frosted lock pill — private photos, bottom-centre of card
class _FrostedPhotoPill extends StatelessWidget {
  const _FrostedPhotoPill({required this.photoCount});
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical:   AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color:        AppColors.overlayBlack55,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.pearlWhite, size: 14),
          const SizedBox(width: AppDimensions.space6),
          Text(
            '$photoCount photo${photoCount > 1 ? 's' : ''} · visible after acceptance',
            style: AppTypography.caption.copyWith(
              color:    AppColors.pearlWhite,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// Item 20: Camera count pill — public profiles with multiple photos
class _PhotoCountPill extends StatelessWidget {
  const _PhotoCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: AppColors.pearlWhite, size: 12),
          const SizedBox(width: AppDimensions.space4),
          Text(
            '$count',
            style: AppTypography.caption.copyWith(
              color:    AppColors.pearlWhite,
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

// D3: Last active indicator pill — shown in top-right when not verified
class _LastActivePill extends StatelessWidget {
  const _LastActivePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isOnline = label == 'Online now';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOnline
                  ? AppColors.onlineGreen
                  : AppColors.slateMist,
            ),
          ),
          const SizedBox(width: AppDimensions.space4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color:    AppColors.pearlWhite,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
