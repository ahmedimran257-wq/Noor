// lib/features/home/screens/legal_doc_screen.dart
// ============================================================
// MITHAQ — Legal Document Screen
// Displays Terms of Service or Privacy Policy content.
// Uses the MITHAQ Quiet Luxury design language.
//
// ============================================================

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.type});

  /// 'tos' for Terms of Service, 'privacy' for Privacy Policy.
  final String type;

  bool get _isTos => type == 'tos';

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
          _isTos ? 'Terms of Service' : 'Privacy Policy',
          style: AppTypography.screenTitle.copyWith(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space20),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isTos
                            ? Icons.description_outlined
                            : Icons.privacy_tip_outlined,
                        color: AppColors.champagneGold,
                        size: 20,
                      ),
                      const SizedBox(width: AppDimensions.space10),
                      Text(
                        _isTos ? 'Terms of Service' : 'Privacy Policy',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  const Text(
                    'Last updated: May 1, 2026',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space24),

            // Sections
            ..._buildSections(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSections() {
    final sections = _isTos ? _tosSections : _privacySections;
    return sections
        .expand((section) => [
              Text(
                section.title.toUpperCase(),
                style: AppTypography.sectionLabel,
              ),
              const SizedBox(height: AppDimensions.space8),
              const Divider(color: AppColors.divider, height: 1),
              const SizedBox(height: AppDimensions.space12),
              Text(
                section.body,
                style: AppTypography.body.copyWith(height: 1.7),
              ),
              const SizedBox(height: AppDimensions.space28),
            ])
        .toList();
  }
}

// ── Section model ─────────────────────────────────────────────

class _LegalSection {
  const _LegalSection({required this.title, required this.body});
  final String title;
  final String body;
}

// ── Terms of Service Content ──────────────────────────────────

const _tosSections = <_LegalSection>[
  _LegalSection(
    title: '1. Acceptance of Terms',
    body: 'By creating an account on MITHAQ, you agree to be bound by these '
        'Terms of Service. MITHAQ is a matrimony platform designed for the '
        'Muslim community, built on principles of respect, sincerity, and '
        'the pursuit of halal relationships. If you do not agree with any '
        'part of these terms, please do not use the service.',
  ),
  _LegalSection(
    title: '2. Eligibility',
    body: 'You must be at least 18 years old to use MITHAQ. By using the app, '
        'you represent that you are of legal age to enter a marriage contract '
        'in your jurisdiction. Guardian accounts may be created by parents or '
        'authorized walis for eligible candidates.',
  ),
  _LegalSection(
    title: '3. Account & Profile',
    body: 'You are responsible for maintaining the accuracy and truthfulness '
        'of your profile information. Misrepresentation of identity, marital '
        'status, age, or other material facts may result in account suspension '
        'or permanent removal. Profile photos must be of the candidate only '
        'and must comply with community standards.',
  ),
  _LegalSection(
    title: '4. Conduct',
    body: 'MITHAQ is a safe space. Users are expected to interact with adab '
        '(respect) and sincerity. Harassment, solicitation, scamming, hate '
        'speech, and inappropriate content are strictly prohibited. Three '
        'verified reports against a user may trigger automatic suspension.',
  ),
  _LegalSection(
    title: '5. Subscriptions & Payments',
    body: 'MITHAQ offers free and premium tiers. Women always message free. '
        'Men require a subscription to send messages. Subscription fees are '
        'billed according to the selected plan (monthly or annual). Prices '
        'are displayed in your local currency. Subscriptions auto-renew unless '
        'cancelled at least 24 hours before the renewal date.',
  ),
  _LegalSection(
    title: '6. Termination',
    body: 'You may delete your account at any time from the Settings screen. '
        'MITHAQ reserves the right to suspend or terminate accounts that violate '
        'these terms. Upon deletion, your personal data will be removed in '
        'accordance with our Privacy Policy.',
  ),
  _LegalSection(
    title: '7. Disclaimer',
    body: 'MITHAQ does not conduct background checks on users. We are not '
        'responsible for the conduct of users on or off the platform. MITHAQ '
        'is provided "as is" without warranties of any kind. We encourage '
        'all users to exercise caution and involve family in the process.',
  ),
];

// ── Privacy Policy Content ────────────────────────────────────

const _privacySections = <_LegalSection>[
  _LegalSection(
    title: '1. Information We Collect',
    body: 'We collect information you provide when creating your profile: '
        'name, age, location, photos, religious background, education, '
        'occupation, and partner preferences. Guardian accounts also provide '
        'guardian contact information. We also collect device information, '
        'usage data, and notification preferences.',
  ),
  _LegalSection(
    title: '2. How We Use Your Information',
    body: 'Your information is used to: create and display your profile to '
        'potential matches, facilitate communication between interested '
        'parties, personalize your discovery feed, enforce community '
        'guidelines, and improve the app. We do not sell your personal '
        'information to third parties.',
  ),
  _LegalSection(
    title: '3. Data Storage & Security',
    body: 'Your data is stored securely using industry-standard encryption. '
        'Sensitive information such as guardian phone numbers is stored using '
        'encrypted storage. We implement appropriate technical and '
        'organizational measures to protect your personal data against '
        'unauthorized access, alteration, or destruction.',
  ),
  _LegalSection(
    title: '4. Photo Privacy',
    body: 'MITHAQ respects your photo privacy preferences. You may choose to '
        'make your photos visible to everyone, or restrict them to users '
        'whose interest you have accepted. This setting can be changed at '
        'any time from your profile settings.',
  ),
  _LegalSection(
    title: '5. Data Sharing',
    body: 'We may share your information with: service providers who assist '
        'in operating the platform, law enforcement when required by law, '
        'and with your consent. Profile information is visible to other '
        'registered users according to your privacy settings.',
  ),
  _LegalSection(
    title: '6. Your Rights',
    body: 'You have the right to: access your personal data, correct '
        'inaccurate information, delete your account and associated data, '
        'export your data, and withdraw consent for data processing. To '
        'exercise these rights, contact us through the app or via email.',
  ),
  _LegalSection(
    title: '7. Contact',
    body: 'For any privacy-related questions or concerns, please contact '
        'our support team through the app settings or email us at '
        'privacy@mithaq.app. We aim to respond to all inquiries within '
        '48 hours.',
  ),
];
