import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';
import 'buttons/silarah_pressable.dart';

/// A one-time contextual guide. It deliberately does not use a toast: the
/// member controls when it disappears and assistive technology can read it.
class SilarahCoachMark extends StatelessWidget {
  const SilarahCoachMark({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.onDismiss,
    required this.onDisableAll,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback onDisableAll;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.fromLTRB(14, 13, 10, 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.champagneGold.withValues(alpha: .55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .16),
                blurRadius: 24,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.goldGlow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppColors.champagneGold),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    UiText(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    UiText(
                      message,
                      style: AppTypography.caption.copyWith(height: 1.35),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 14,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SilarahPressable(
                          semanticLabel: 'Got it',
                          onTap: onDismiss,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 5,
                            ),
                            child: UiText(
                              context.uiCopy('Got it'),
                              style: AppTypography.captionMedium.copyWith(
                                color: AppColors.champagneGold,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SilarahPressable(
                          semanticLabel: 'Hide all tips',
                          onTap: onDisableAll,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2,
                              vertical: 5,
                            ),
                            child: UiText(
                              context.uiCopy('Hide tips'),
                              style: AppTypography.caption.copyWith(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SilarahPressable(
                semanticLabel: 'Dismiss',
                onTap: onDismiss,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.space4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: AppColors.slateMist,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
