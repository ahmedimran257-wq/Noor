import 'package:flutter/material.dart';
import 'package:silarah/l10n/ui_copy.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Member-controlled guidance, displayed in its own layout space.
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
      child: Material(
        color: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.champagneGold),
                  const SizedBox(width: 10),
                  Expanded(
                      child: UiText(title, style: AppTypography.bodyMedium)),
                ],
              ),
              const SizedBox(height: 4),
              UiText(message,
                  style: AppTypography.caption.copyWith(height: 1.4)),
              Wrap(
                spacing: 12,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.champagneGold,
                    ),
                    onPressed: onDismiss,
                    child: UiText(context.uiCopy('Got it')),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: AppColors.slateMist,
                    ),
                    onPressed: onDisableAll,
                    child: UiText(context.uiCopy('Hide tips')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
