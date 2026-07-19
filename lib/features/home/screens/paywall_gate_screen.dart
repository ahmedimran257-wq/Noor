// lib/features/home/screens/paywall_gate_screen.dart
// ============================================================
// SILARAH — Paywall Gate (Step 9)
//
// Shown as a bottom sheet when a male non-subscriber tries
// to open a chat conversation.
//
// Blueprint (Part 8):
//   "Non-subscriber men who try to open a chat see:
//    'Subscribe to unlock messaging. Women always message
//     free on SILARAH.' The price shown is in their local currency."
//
// Usage:
//   PaywallGateSheet.show(context);
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'subscription_screen.dart';

class PaywallGateSheet {
  /// Shows the paywall as a modal bottom sheet.
  ///
  /// Blueprint: "Women always message free on SILARAH."
  /// This method is a no-op if the current user is female —
  /// defence-in-depth on top of the call-site check in
  /// chat_list_screen.dart and chat_screen.dart.
  static Future<void> show(BuildContext context) {
    // Runtime guard: never show paywall to women.
    final authState = context.read<AuthCubit>().state;
    final gender =
        authState is AuthAuthenticated ? (authState.gender ?? 'male') : 'male';
    if (gender == 'female') return Future.value();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PaywallGateContent(),
    );
  }
}

class _PaywallGateContent extends StatelessWidget {
  const _PaywallGateContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.goldBorder, width: 1),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).viewPadding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 28),

          // Lock icon with gold ring
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.goldGlow,
              border: Border.all(color: AppColors.goldBorder, width: 1.5),
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: AppColors.champagneGold,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Subscribe to Unlock Messaging',
            style: AppTypography.screenTitle.copyWith(fontSize: 22),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          Text(
            'Women can message their matches at no cost.\nMen unlock conversations with Silarah Premium.',
            style: AppTypography.bodyMuted.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Price highlight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.goldGlow,
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Text(
              'Plans are shown in your local currency',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.champagneGold),
            ),
          ),

          const SizedBox(height: 28),

          // Subscribe CTA
          GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SubscriptionScreen(),
                ),
              );
            },
            child: Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AppColors.champagneGold,
              ),
              alignment: Alignment.center,
              child: Text('See Plans', style: AppTypography.button),
            ),
          ),

          const SizedBox(height: 12),

          // Not Now
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Not Now',
              style: AppTypography.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}
