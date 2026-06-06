// lib/core/utils/validation_snackbar.dart
// ============================================================
// NOOR — Validation Snackbar Helper
// Shows a themed snackbar listing missing mandatory fields.
// ============================================================

import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// Shows a themed snackbar with a list of missing mandatory fields.
void showValidationSnackbar(BuildContext context, List<String> missingFields) {
  if (missingFields.isEmpty) return;

  final message = missingFields.length == 1
      ? 'Please fill in: ${missingFields.first}'
      : 'Please fill in:\n• ${missingFields.join('\n• ')}';

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.champagneGold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body.copyWith(fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.snackbarSurface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: const BorderSide(color: AppColors.goldBorder),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
}
