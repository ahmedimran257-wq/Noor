// SILARAH — Referral & Ambassador Screen
// Allows users to view their referral code, copy/share it, and track the
// one-time three-day referral Premium reward.
import 'package:silarah/l10n/ui_copy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/referral_service.dart';
import '../../../core/services/platform_action_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../l10n/generated/app_localizations.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _service = ReferralService.instance;
  bool _isLoading = true;
  String _code = 'SILARAH';
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
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _copyToClipboard() async {
    HapticFeedback.mediumImpact();
    final message = AppLocalizations.of(context).referral_copied;
    await Clipboard.setData(ClipboardData(text: _code));
    _showSnackBar(message);
  }

  Future<void> _shareReferral() async {
    HapticFeedback.mediumImpact();
    if (!SupabaseService.isInitialized) return;
    final l10n = AppLocalizations.of(context);
    final code = await _service.getOrCreateCode();
    await PlatformActionService.instance.shareText(
      text: l10n.referral_shareText(code),
      subject: l10n.referral_shareSubject,
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: UiText(
          message,
          style: AppTypography.body.copyWith(
            color: AppColors.readableOn(AppColors.surfaceGlassHover),
          ),
        ),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          side: BorderSide(color: AppColors.cardBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: l10n.common_button_back,
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.pearlWhite),
          onPressed: () => Navigator.pop(context),
        ),
        title: UiText(l10n.referral_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: _isLoading
          ? Center(child: SilarahPulseLoader(label: l10n.referral_loading))
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
                    child: Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.champagneGold,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space24),
                  UiText(
                    l10n.referral_heading,
                    style: AppTypography.screenTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  UiText(
                    l10n.referral_body,
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
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusCard),
                      border: Border.all(color: AppColors.goldBorder, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.champagneGold.withValues(alpha: 0.03),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        UiText(
                          l10n.referral_codeLabel,
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
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusButton),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                UiText(
                                  _code,
                                  style: AppTypography.screenTitle.copyWith(
                                    color: AppColors.champagneGold,
                                    letterSpacing: 4,
                                    fontSize: 26,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.space16),
                                Icon(Icons.copy_rounded,
                                    color: AppColors.champagneGold, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space12),
                        UiText(
                          l10n.referral_tapToCopy,
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
                          label: l10n.referral_totalInvited,
                          value: '${_stats.totalReferrals}',
                        ),
                      ),
                      const SizedBox(width: AppDimensions.space12),
                      Expanded(
                        child: _StatCard(
                          label: l10n.referral_rewardsEarned,
                          value: '${_stats.rewardsEarned}',
                          subtitle: l10n
                              .referral_premiumDays(_stats.premiumDaysEarned),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  _StatCard(
                    label: l10n.referral_pending,
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
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.share_rounded, size: 20),
                      label: UiText(l10n.referral_shareButton,
                          style: AppTypography.button),
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
          UiText(label,
              style: AppTypography.captionMedium.copyWith(fontSize: 11)),
          const SizedBox(height: 8),
          UiText(
            value,
            style: AppTypography.screenTitle.copyWith(
              fontSize: 24,
              color: AppColors.pearlWhite,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            UiText(
              subtitle!,
              style: AppTypography.caption
                  .copyWith(color: AppColors.champagneGold, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
