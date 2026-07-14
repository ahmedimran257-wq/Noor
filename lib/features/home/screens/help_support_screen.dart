import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
          const _EmailTrustNotice(),
          const SizedBox(height: AppDimensions.space16),
          _SupportCard(
            icon: Icons.support_agent_rounded,
            title: 'Contact Support',
            body:
                'For account, billing, safety, verification, or profile issues.',
            actionLabel: 'support@silarah.com',
            onTap: () => _contactEmail(context, 'support@silarah.com'),
          ),
          const SizedBox(height: AppDimensions.space12),
          _SupportCard(
            icon: Icons.verified_user_outlined,
            title: 'Safety & Reports',
            body:
                'Report abusive behavior from the profile menu. Urgent safety reviews are prioritized.',
            actionLabel: 'safety@silarah.com',
            onTap: () => _contactEmail(context, 'safety@silarah.com'),
          ),
          const SizedBox(height: AppDimensions.space12),
          _SupportCard(
            icon: Icons.gavel_outlined,
            title: 'Grievance Officer',
            body:
                'For formal grievance requests under applicable platform rules.',
            actionLabel: 'grievance@silarah.com',
            onTap: () => _contactEmail(context, 'grievance@silarah.com'),
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
                'Profile photo verification uses a passive face and liveness scan. Identity verification separately matches a government ID with your selfie. Both are available in Profile under Trust & identity.',
          ),
        ],
      ),
    );
  }

  static Future<void> _contactEmail(BuildContext context, String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: const {'subject': 'Silarah support request'},
    );
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text('No email app found. $email was copied.',
              style: AppTypography.body),
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
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
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

class _EmailTrustNotice extends StatelessWidget {
  const _EmailTrustNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.mark_email_read_outlined,
              color: AppColors.champagneGold, size: 21),
          SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recognize official Silarah email',
                    style: AppTypography.bodyMedium),
                SizedBox(height: AppDimensions.space4),
                Text(
                  'Account and security messages use @mail.silarah.com. Product updates use @news.silarah.com. We never ask for passwords or verification codes.',
                  style: AppTypography.caption,
                ),
              ],
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
