import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.pearlWhite, size: 20),
        ),
        title: Text(
          'Help & Support',
          style: AppTypography.screenTitle.copyWith(fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          _SupportCard(
            icon: Icons.support_agent_rounded,
            title: 'Contact Support',
            body:
                'For account, billing, safety, verification, or profile issues.',
            actionLabel: 'support@mithaq.app',
            onTap: () => _copyEmail(context, 'support@mithaq.app'),
          ),
          const SizedBox(height: AppDimensions.space12),
          _SupportCard(
            icon: Icons.verified_user_outlined,
            title: 'Safety & Reports',
            body:
                'Report abusive behavior from the profile menu. Urgent safety reviews are prioritized.',
            actionLabel: 'safety@mithaq.app',
            onTap: () => _copyEmail(context, 'safety@mithaq.app'),
          ),
          const SizedBox(height: AppDimensions.space12),
          _SupportCard(
            icon: Icons.gavel_outlined,
            title: 'Grievance Officer',
            body:
                'For formal grievance requests under applicable platform rules.',
            actionLabel: 'grievance@mithaq.app',
            onTap: () => _copyEmail(context, 'grievance@mithaq.app'),
          ),
          const SizedBox(height: AppDimensions.space20),
          const Text('Common Help', style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space8),
          const _FaqTile(
            question: 'Why are my photos not visible?',
            answer:
                'Public photos appear after upload and moderation. Private photos are shown only based on your photo privacy setting.',
          ),
          const _FaqTile(
            question: 'Why can I not message someone?',
            answer:
                'Messaging opens after a mutual interest. Some accounts also need an active plan depending on gender and subscription rules.',
          ),
          const _FaqTile(
            question: 'How does verification work?',
            answer:
                'Use Verify Your Profile from Profile to complete the selfie/badge flow. Verified profiles are ranked and trusted better.',
          ),
        ],
      ),
    );
  }

  static Future<void> _copyEmail(BuildContext context, String email) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('$email copied', style: AppTypography.body),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
        ),
      );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.champagneGold, size: 22),
              const SizedBox(width: AppDimensions.space8),
              Expanded(child: Text(title, style: AppTypography.bodyMedium)),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(body, style: AppTypography.caption.copyWith(height: 1.5)),
          const SizedBox(height: AppDimensions.space12),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.copy_rounded, size: 16),
              label: Text(actionLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.champagneGold,
                side: const BorderSide(color: AppColors.goldBorder),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.space8),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: ExpansionTile(
        collapsedIconColor: AppColors.slateMist,
        iconColor: AppColors.champagneGold,
        title: Text(question, style: AppTypography.body),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(answer,
                style: AppTypography.caption.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}
