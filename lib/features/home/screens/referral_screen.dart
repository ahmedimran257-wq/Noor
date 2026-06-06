// lib/features/home/screens/referral_screen.dart
// ============================================================
// NOOR — Referral & Ambassador Screen
// Allows users to view their referral code, copy/share it,
// and track their rewards (7 days of free premium per opposite
// gender referral).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _service = ReferralService.instance;
  bool _isLoading = true;
  String _code = 'NOORXX';
  ReferralStats _stats = const ReferralStats(
    totalReferrals: 0,
    rewardsEarned: 0,
    pendingReferrals: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    if (SupabaseService.isInitialized) {
      try {
        final code = await _service.getOrCreateCode();
        final stats = await _service.getStats();
        if (mounted) {
          setState(() {
            _code = code;
            _stats = stats;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('[ReferralScreen] Error loading referral data: $e');
        if (mounted) setState(() => _isLoading = false);
      }
    } else {
      // Mock mode
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        setState(() {
          _code = 'MOCK99';
          _stats = const ReferralStats(
            totalReferrals: 5,
            rewardsEarned: 2,
            pendingReferrals: 3,
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    HapticFeedback.mediumImpact();
    await Clipboard.setData(ClipboardData(text: _code));
    _showSnackBar('Referral code copied to clipboard!');
  }

  Future<void> _shareReferral() async {
    HapticFeedback.mediumImpact();
    String shareText = '';
    if (SupabaseService.isInitialized) {
      shareText = await _service.getShareText();
    } else {
      shareText = 'Join NOOR — the most trusted Muslim matrimony app. Use my referral code: $_code\n\nDownload: https://noor.app/r/$_code';
    }
    await Clipboard.setData(ClipboardData(text: shareText));
    _showSnackBar('Referral link & code copied! Paste it to share.');
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.body),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.pearlWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Refer a Friend', style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.champagneGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppDimensions.space12),
                  // Trophy / Gift Icon Illustration
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.goldBorder, width: 2),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.champagneGold,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  const Text(
                    'Spread the word, earn Premium!',
                    style: AppTypography.screenTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  const Text(
                    'Invite your friends to NOOR. When someone of the opposite gender completes onboarding using your code, you both get 7 days of FREE Premium!',
                    style: AppTypography.bodyMuted,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.space32),

                  // Referral Code Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.space24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                      border: Border.all(color: AppColors.goldBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.champagneGold.withValues(alpha: 0.03),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'YOUR REFERRAL CODE',
                          style: AppTypography.captionMedium,
                        ),
                        const SizedBox(height: AppDimensions.space16),
                        GestureDetector(
                          onTap: _copyToClipboard,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.space24,
                              vertical: AppDimensions.space12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.inputSurface,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _code,
                                  style: AppTypography.screenTitle.copyWith(
                                    color: AppColors.champagneGold,
                                    letterSpacing: 4,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.space16),
                                const Icon(Icons.copy_rounded, color: AppColors.champagneGold, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        const Text(
                          'Tap code to copy',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.space28),

                  // Stats Section
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          label: 'Total Invited',
                          value: '${_stats.totalReferrals}',
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: _StatCard(
                          label: 'Rewards Earned',
                          value: '${_stats.rewardsEarned}',
                          subtitle: '${_stats.premiumDaysEarned} premium days',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  _StatCard(
                    label: 'Pending Registrations',
                    value: '${_stats.pendingReferrals}',
                    alignment: Alignment.center,
                  ),

                  const SizedBox(height: AppDimensions.space40),

                  // Share CTA button
                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.champagneGold,
                        foregroundColor: AppColors.obsidianNight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: const Text('Share Code with Friends', style: AppTypography.button),
                      onPressed: _shareReferral,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.subtitle,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final String value;
  final String? subtitle;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: alignment == Alignment.center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.captionMedium.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTypography.screenTitle.copyWith(
              fontSize: 24,
              color: AppColors.pearlWhite,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppTypography.caption.copyWith(color: AppColors.champagneGold, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
