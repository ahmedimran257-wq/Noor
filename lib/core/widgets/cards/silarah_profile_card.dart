// The SILARAH Card — "The Discovery Engine"
// "The most critical component. It must look like a
//  luxury portfolio cover."
//
// Ratio: 7:10 editorial portrait
// Frame: one uninterrupted, theme-aware perimeter above the media.
// Gradient: Transparent (top) → 30% Obsidian (mid) → 100% Obsidian (bottom)
// Name: Playfair Display 24px, bottom-left
// Location: Inter 14px, below name
// Focus effect: center card scale 1.0, adjacent cards scale 0.95
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_typography.dart';
import '../buttons/silarah_pressable.dart';
import '../loaders/silarah_blur_image.dart';

class SilarahProfileCard extends StatelessWidget {
  const SilarahProfileCard({
    super.key,
    required this.displayName,
    required this.age,
    required this.cityName,
    this.sect,
    this.deenLevel,
    this.profession,
    this.photoUrl,
    this.photoCount = 0,
    this.isPhotoPrivate = false,
    this.isVerified = false,
    this.phoneVerified = false,
    this.isGuardianManaged = false,
    this.isFocused = true, // Controls the scale focus effect
    this.onTap,
    this.onSendInterest,
    this.onBookmark,
    this.isBookmarked = false,
    this.interestActionLabel = 'Send Interest',
    this.isInterestActionEnabled = true,
    this.lastActiveLabel,
    this.previousMatchLabel,
    this.cardScale = 1.0,
    this.blurhash,
  });

  final String displayName;
  final int age;
  final String cityName;
  final String? sect;
  final String? deenLevel;
  final String? profession; // blueprint: shown on card below location
  final String? photoUrl;
  final int photoCount;
  final bool isPhotoPrivate;
  final bool isVerified;
  final bool phoneVerified;
  final bool isGuardianManaged;
  final bool isFocused;
  final VoidCallback? onTap;
  final VoidCallback? onSendInterest;
  final VoidCallback? onBookmark;
  final bool isBookmarked;
  final String interestActionLabel;
  final bool isInterestActionEnabled;
  final String? lastActiveLabel;
  final String? previousMatchLabel;
  final double cardScale; // Continuous scale driven by scroll offset
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    final frameColor = AppColors.active.mode == SilarahThemeMode.blackWhite
        ? AppColors.champagneLight.withValues(alpha: 0.9)
        : AppColors.champagneLight.withValues(alpha: 0.82);

    return Transform.scale(
      scale: cardScale,
      child: SilarahPressable(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: AppDimensions.cardAspectRatio,
          child: Container(
            key: const Key('discovery_profile_card_frame'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surfacePanelTop,
                  AppColors.obsidianNight,
                ],
              ),
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 34,
                        spreadRadius: -8,
                        offset: const Offset(0, 20),
                      ),
                      BoxShadow(
                        color: AppColors.goldGlow,
                        blurRadius: 28,
                        spreadRadius: -12,
                      ),
                    ]
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              border: Border.all(
                color: isFocused
                    ? frameColor
                    : AppColors.onMedia.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo Layer
                if (photoUrl != null && !isPhotoPrivate)
                  _PhotoLayer(url: photoUrl!, blurhash: blurhash)
                else
                  _PrivatePhotoPlaceholder(
                    photoCount: photoCount,
                    isPrivate: isPhotoPrivate,
                  ),

                // ── Gradient Overlay (always on top of photo)
                const _GradientOverlay(),

                // Content Layer
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.space16),
                    child: Column(
                      children: [
                        // Top row: photo count + activity, clear of the portrait.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Photo count pill — public, multiple photos
                            if (!isPhotoPrivate && photoCount > 1)
                              _PhotoCountPill(count: photoCount)
                            else if (isPhotoPrivate && photoCount > 0)
                              _PrivatePhotoCountPill(count: photoCount),

                            // Activity remains independent of ID verification.
                            const Spacer(),
                            if (lastActiveLabel != null &&
                                lastActiveLabel!.isNotEmpty)
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
                              UiText(
                                displayName,
                                style: AppTypography.userName.copyWith(
                                  color: AppColors.onMedia,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  height: 1.12,
                                  shadows: const [
                                    Shadow(
                                      color: AppColors.overlayBlack55,
                                      blurRadius: 12,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppDimensions.space6),

                              // Age · City
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 15,
                                    color: Color(0xD9F8F8FA),
                                  ),
                                  const SizedBox(width: AppDimensions.space4),
                                  Expanded(
                                    child: UiText(
                                      '$age · $cityName',
                                      style:
                                          AppTypography.cardLocation.copyWith(
                                        color: AppColors.onMedia.withValues(
                                          alpha: 0.88,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(
                                      width: AppDimensions.space8,
                                    ),
                                    _VerifiedBadge(),
                                  ],
                                  if (phoneVerified) ...[
                                    const SizedBox(
                                      width: AppDimensions.space6,
                                    ),
                                    const _PhoneVerifiedBadge(),
                                  ],
                                ],
                              ),

                              if (previousMatchLabel != null) ...[
                                const SizedBox(height: AppDimensions.space8),
                                _PreviousMatchPill(label: previousMatchLabel!),
                              ],

                              if (isGuardianManaged) ...[
                                const SizedBox(height: AppDimensions.space8),
                                const _GuardianManagedPill(),
                              ],

                              // Profession line
                              if (profession != null) ...[
                                const SizedBox(height: AppDimensions.space8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.work_outline_rounded,
                                      size: 14,
                                      color: AppColors.onMedia.withValues(
                                        alpha: 0.68,
                                      ),
                                    ),
                                    const SizedBox(width: AppDimensions.space6),
                                    Expanded(
                                      child: UiText(
                                        profession!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.onMedia.withValues(
                                            alpha: 0.74,
                                          ),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Chips row
                              if (sect != null || deenLevel != null) ...[
                                const SizedBox(height: AppDimensions.space10),
                                Wrap(
                                  spacing: AppDimensions.space8,
                                  runSpacing: AppDimensions.space6,
                                  children: [
                                    if (sect != null) _InfoChip(label: sect!),
                                    if (deenLevel != null)
                                      _InfoChip(label: _formatDeen(deenLevel!)),
                                  ],
                                ),
                              ],

                              const SizedBox(height: AppDimensions.space14),

                              // Action row: bookmark + send interest
                              Row(
                                children: [
                                  // Bookmark
                                  _IconActionButton(
                                    icon: isBookmarked
                                        ? Icons.bookmark_rounded
                                        : Icons.bookmark_outline_rounded,
                                    isActive: isBookmarked,
                                    onTap: onBookmark,
                                    tooltip: isBookmarked
                                        ? 'Remove saved profile'
                                        : 'Save profile',
                                  ),
                                  const SizedBox(width: AppDimensions.space12),

                                  // Send Interest — fills remaining space
                                  Expanded(
                                    child: _SendInterestButton(
                                      label: interestActionLabel,
                                      enabled: isInterestActionEnabled,
                                      onTap: onSendInterest,
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

                if (isPhotoPrivate && photoCount > 0)
                  Positioned(
                    top: 72,
                    left: 0,
                    right: 0,
                    child: Center(
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
      case 'practicing':
        return 'Practicing';
      case 'moderate':
        return 'Moderate';
      case 'cultural':
        return 'Cultural';
      default:
        return raw;
    }
  }
}

// Sub-widgets
class _PhotoLayer extends StatelessWidget {
  const _PhotoLayer({required this.url, this.blurhash});
  final String url;
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    return SilarahBlurImage(
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
              child: Icon(
                Icons.person_outline_rounded,
                color: AppColors.slateMist,
                size: 40,
              ),
            ),
            if (isPrivate && photoCount > 0) ...[
              const SizedBox(height: AppDimensions.space12),
              UiText(
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
          end: Alignment.bottomCenter,
          colors: [
            Color(0x08000000),
            Color(0x18000000),
            Color(0xB8000000),
            Color(0xFA000000),
          ],
          stops: [0.0, 0.38, 0.68, 1.0],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final trustColor = AppColors.active.mode == SilarahThemeMode.blackWhite
        ? AppColors.onMedia
        : AppColors.verifiedTeal;

    return Semantics(
      label: context.uiCopy('Profile photo verified'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayBlack55,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(
            color: trustColor.withValues(alpha: 0.72),
            width: AppDimensions.borderThin,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.face_retouching_natural_rounded,
              color: trustColor,
              size: 13,
            ),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Photo'),
              style: AppTypography.caption.copyWith(
                color: trustColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhoneVerifiedBadge extends StatelessWidget {
  const _PhoneVerifiedBadge();

  @override
  Widget build(BuildContext context) {
    final trustColor = AppColors.active.mode == SilarahThemeMode.blackWhite
        ? AppColors.onMedia
        : AppColors.champagneGold;
    return Semantics(
      label: context.uiCopy('Phone number verified by SMS'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayBlack55,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: trustColor.withValues(alpha: 0.72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.phone_iphone_rounded, color: trustColor, size: 13),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Phone'),
              style: AppTypography.caption.copyWith(
                color: trustColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianManagedPill extends StatelessWidget {
  const _GuardianManagedPill();

  @override
  Widget build(BuildContext context) {
    final color = AppColors.active.mode == SilarahThemeMode.blackWhite
        ? AppColors.onMedia
        : AppColors.champagneLight;
    return Semantics(
      label: context.uiCopy('Guardian-managed profile'),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space8,
          vertical: AppDimensions.space4,
        ),
        decoration: BoxDecoration(
          color: AppColors.overlayBlack55,
          borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
          border: Border.all(color: color.withValues(alpha: 0.72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.family_restroom_rounded, color: color, size: 13),
            const SizedBox(width: AppDimensions.space4),
            UiText(
              context.uiCopy('Guardian-managed profile'),
              style: AppTypography.caption.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviousMatchPill extends StatelessWidget {
  const _PreviousMatchPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack55,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history_rounded,
            color: AppColors.onMedia.withValues(alpha: 0.88),
            size: 14,
          ),
          const SizedBox(width: AppDimensions.space6),
          Expanded(
            child: UiText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: AppColors.onMedia.withValues(alpha: 0.9),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrostedPhotoPill extends StatelessWidget {
  const _FrostedPhotoPill({required this.photoCount});
  final int photoCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack55,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.onMedia, size: 14),
          const SizedBox(width: AppDimensions.space6),
          UiText(
            '$photoCount photo${photoCount > 1 ? 's' : ''} · visible after acceptance',
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCountPill extends StatelessWidget {
  const _PhotoCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.camera_alt_outlined,
              color: AppColors.onMedia, size: 12),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            '$count',
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivatePhotoCountPill extends StatelessWidget {
  const _PrivatePhotoCountPill({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.onMedia,
            size: 12,
          ),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            '$count',
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
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
        vertical: AppDimensions.space6,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xD1000000),
            Color(0x99000000),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.22),
          width: AppDimensions.borderThin,
        ),
      ),
      child: UiText(
        label,
        style: AppTypography.chipLabel.copyWith(
          color: AppColors.onMedia,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SendInterestButton extends StatelessWidget {
  const _SendInterestButton({
    required this.label,
    required this.enabled,
    this.onTap,
  });
  final String label;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isSending = label == 'Sending...';
    final isConfirmed = label == 'Interest Sent';
    final isInteractive = enabled && onTap != null;
    final enabledColors = AppColors.active.mode == SilarahThemeMode.blackWhite
        ? const [Color(0xFFFFFFFF), Color(0xFFE7E7E7)]
        : [
            AppColors.champagneLight,
            AppColors.champagneGold,
            AppColors.antiqueGold,
          ];
    final foreground = isInteractive
        ? AppColors.readableOn(enabledColors[1])
        : AppColors.onMedia.withValues(alpha: 0.64);
    final glowColor = AppColors.active.mode == SilarahThemeMode.blackWhite
        ? AppColors.onMedia.withValues(alpha: 0.24)
        : AppColors.champagneGold.withValues(alpha: 0.38);

    return SilarahPressable(
      onTap: onTap,
      enabled: isInteractive,
      semanticLabel: label,
      child: AnimatedContainer(
        key: const Key('discovery_interest_action'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 52,
        decoration: BoxDecoration(
          gradient: !isInteractive
              ? const LinearGradient(
                  colors: [
                    AppColors.overlayBlack55,
                    AppColors.overlayBlack87,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enabledColors,
                ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: !isInteractive
                ? AppColors.onMedia.withValues(alpha: 0.22)
                : AppColors.active.mode == SilarahThemeMode.blackWhite
                    ? AppColors.onMedia
                    : AppColors.champagneLight.withValues(alpha: 0.92),
            width: 1.25,
          ),
          boxShadow: !isInteractive
              ? null
              : [
                  BoxShadow(
                    color: glowColor,
                    blurRadius: 22,
                    spreadRadius: -5,
                    offset: const Offset(0, 10),
                  ),
                  const BoxShadow(
                    color: AppColors.overlayBlack45,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 360),
            reverseDuration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSending) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foreground),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ] else if (isConfirmed) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ] else ...[
                  Icon(
                    Icons.favorite_rounded,
                    size: 18,
                    color: foreground,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                ],
                Flexible(
                  child: UiText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.button.copyWith(
                      color: foreground,
                      fontSize: 14.5,
                      fontWeight:
                          isInteractive ? FontWeight.w800 : FontWeight.w700,
                      letterSpacing: isInteractive ? 0.1 : 0,
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
}

class _IconActionButton extends StatelessWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    this.isActive = false,
    this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SilarahPressable(
      onTap: onTap,
      semanticLabel: tooltip,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isActive
                ? [
                    AppColors.onMedia,
                    AppColors.onMedia.withValues(alpha: 0.88),
                  ]
                : [
                    AppColors.overlayBlack87,
                    AppColors.overlayBlack55,
                  ],
          ),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(
            color: isActive
                ? AppColors.overlayBlack45
                : AppColors.onMedia.withValues(alpha: 0.72),
            width: AppDimensions.borderThin,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.overlayBlack55,
              blurRadius: 14,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: isActive ? AppColors.overlayBlack87 : AppColors.onMedia,
          size: AppDimensions.iconSizeMedium,
        ),
      ),
    );
  }
}

// Last active stays visible alongside the identity badge.
class _LastActivePill extends StatelessWidget {
  const _LastActivePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isOnline = label == 'Online now';
    final activeColor = isOnline
        ? (AppColors.active.mode == SilarahThemeMode.blackWhite
            ? AppColors.onMedia
            : AppColors.onlineGreen)
        : AppColors.onMedia.withValues(alpha: 0.58);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.overlayBlack45,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: AppColors.onMedia.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: activeColor,
            ),
          ),
          const SizedBox(width: AppDimensions.space4),
          UiText(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onMedia,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
