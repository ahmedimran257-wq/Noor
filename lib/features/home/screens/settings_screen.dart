// lib/features/home/screens/settings_screen.dart
// ============================================================
// MITHAQ — Settings Screen
// Sections:
//   1. ACCOUNT   — phone, photo privacy
//   2. NOTIFICATIONS — per-category toggles
//   3. GUARDIAN  — full guardian mode with wali details (Feature 13)
//   4. PRIVACY   — full privacy settings section (Feature 14)
//   5. APP       — Language picker with LocaleCubit (Feature 16)
//   6. SAFETY    — block list, report history
//   7. LEGAL     — ToS, Privacy Policy
//   8. DANGER ZONE — Delete Account full screen (Feature 15)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../../core/cubits/locale/locale_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_state.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/services/supabase_service.dart';
import 'legal_doc_screen.dart';
import '../../../core/services/selfie_verification_service.dart';

// ── Languages ─────────────────────────────────────────────────

class _LangOption {
  const _LangOption({
    required this.locale,
    required this.nativeName,
    required this.englishName,
    this.isRtl = false,
  });
  final String locale;
  final String nativeName;
  final String englishName;
  final bool isRtl;
}

const _kLanguages = [
  _LangOption(locale: 'en', nativeName: 'English', englishName: 'English'),
  _LangOption(
      locale: 'ar', nativeName: 'العربية', englishName: 'Arabic', isRtl: true),
];

// ── Guardian prefs keys ───────────────────────────────────────

const _kGuardianEnabled = 'guardian_enabled';
const _kGuardianName = 'guardian_name';
const _kGuardianPhone = 'guardian_phone';
const _kGuardianRelationship = 'guardian_relationship';
const _kGuardianMirror = 'mirror_messages';
const _kGuardianCanReply = 'guardian_can_reply';

// ── Privacy prefs keys ────────────────────────────────────────

const _kPhotoVisibility = 'privacy_photo_visibility';
const _kShowOnlineStatus = 'privacy_show_online';
const _kProfilePaused = 'privacy_profile_paused';
const _kProfileVisibility = 'privacy_who_can_see';

// ═══════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═══════════════════════════════════════════════════════════════

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.initialSection});

  /// Optional section to scroll to on open: 'privacy', 'help', 'account', etc.
  final String? initialSection;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _privacyKey = GlobalKey();
  final _helpKey = GlobalKey();
  final _accountKey = GlobalKey();
  final _notificationsKey = GlobalKey();
  bool _isVerified = false;

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
    }
  }

  Future<void> _loadVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isVerified = prefs.getBool('selfie_verified') ?? false;
    });

    try {
      final status = await SelfieVerificationService.instance.getStatus();
      if (!mounted) return;
      final isVerified = status.status == 'verified';
      if (isVerified != _isVerified) {
        setState(() {
          _isVerified = isVerified;
        });
        await prefs.setBool('selfie_verified', isVerified);
      }
    } catch (e) {
      debugPrint('SettingsScreen: _loadVerificationStatus error: $e');
    }
  }

  void _scrollToSection() {
    GlobalKey? key;
    switch (widget.initialSection) {
      case 'privacy':
        key = _privacyKey;
      case 'help':
        key = _helpKey;
      case 'account':
        key = _accountKey;
      case 'notifications':
        key = _notificationsKey;
    }
    if (key?.currentContext != null) {
      _scrollToKey(key!);
    }
  }

  void _scrollToKey(GlobalKey key) {
    if (key.currentContext == null) return;
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
        title: Text(l10n.settings_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── 1. ACCOUNT ────────────────────────────────────
          _SectionHeader(l10n.settings_section_account, key: _accountKey),
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.edit_outlined,
              label: l10n.settings_label_editProfile,
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            _Divider(),
            Builder(
              builder: (ctx) {
                final data = ctx.read<OnboardingCubit>().currentData;
                final email = data.email ??
                    (SupabaseService.isInitialized
                        ? SupabaseService.client.auth.currentUser?.email
                        : null);
                return _NavTile(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: _maskEmail(email),
                  onTap: () => _showInfoSnackbar(
                      context, 'Email is your sign-in method.'),
                );
              },
            ),
            _Divider(),
            _NavTile(
              icon: Icons.photo_library_outlined,
              label: l10n.settings_label_photoPrivacy,
              value: 'Manage',
              onTap: () => _scrollToKey(_privacyKey),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.verified_outlined,
              label: l10n.settings_label_verifyProfile,
              value: _isVerified
                  ? 'Verified'
                  : l10n.settings_label_selfieChallenge,
              iconColor: _isVerified
                  ? AppColors.verifiedTeal
                  : AppColors.champagneGold,
              onTap: () async {
                await context.push(AppRoutes.verify);
                _loadVerificationStatus();
              },
            ),
          ]),

          // ── 2. NOTIFICATIONS ─────────────────────────────
          _SectionHeader(l10n.settings_section_notifications,
              key: _notificationsKey),
          BlocBuilder<NotificationPrefsCubit, NotificationPrefsState>(
            builder: (context, prefs) => _SettingsCard(children: [
              _ToggleTile(
                icon: Icons.favorite_outline_rounded,
                label: l10n.settings_notify_newInterest,
                value: prefs.newInterest,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleNewInterest(v),
              ),
              _Divider(),
              _ToggleTile(
                icon: Icons.check_circle_outline_rounded,
                label: l10n.settings_notify_interestAccepted,
                value: prefs.interestAccepted,
                onChanged: (v) => context
                    .read<NotificationPrefsCubit>()
                    .toggleInterestAccepted(v),
              ),
              _Divider(),
              _ToggleTile(
                icon: Icons.chat_bubble_outline_rounded,
                label: l10n.settings_notify_newMessage,
                value: prefs.newMessage,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleNewMessage(v),
              ),
              _Divider(),
              _ToggleTile(
                icon: Icons.verified_outlined,
                label: l10n.settings_notify_profileApproved,
                value: prefs.profileApproved,
                onChanged: (v) => context
                    .read<NotificationPrefsCubit>()
                    .toggleProfileApproved(v),
              ),
              _Divider(),
              _ToggleTile(
                icon: Icons.timer_outlined,
                label: l10n.settings_notify_interestExpiring,
                value: prefs.interestExpiring,
                onChanged: (v) => context
                    .read<NotificationPrefsCubit>()
                    .toggleInterestExpiring(v),
              ),
              _Divider(),
              _ToggleTile(
                icon: Icons.notifications_active_outlined,
                label: l10n.settings_notify_activityNudges,
                caption: l10n.settings_notify_activityNudgesSub,
                value: prefs.inactiveNudge,
                onChanged: (v) => context
                    .read<NotificationPrefsCubit>()
                    .toggleInactiveNudge(v),
              ),
              _Divider(),
              _ToggleTile(
                icon: Icons.rocket_launch_outlined,
                label: l10n.settings_notify_boostReminders,
                caption: l10n.settings_notify_boostRemindersSub,
                value: prefs.boostAvailable,
                onChanged: (v) => context
                    .read<NotificationPrefsCubit>()
                    .toggleBoostAvailable(v),
              ),
              _Divider(),
              _InfoTile(
                icon: Icons.bedtime_outlined,
                label: l10n.settings_notify_quietHours,
                value:
                    '${_fmtHour(prefs.quietStartHour)} – ${_fmtHour(prefs.quietEndHour)}',
              ),
            ]),
          ),

          // ── 3. GUARDIAN (Feature 13) ──────────────────────
          _SectionHeader(l10n.settings_section_guardian),
          const _GuardianSection(),

          // ── 4. PRIVACY (Feature 14) ───────────────────────
          _SectionHeader(l10n.settings_section_privacy, key: _privacyKey),
          const _PrivacySection(),

          // ── 5. APP (Feature 16) ───────────────────────────
          _SectionHeader(l10n.settings_section_app),
          _SettingsCard(children: [
            BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                final lang = _kLanguages.firstWhere(
                    (l) => l.locale == locale.languageCode,
                    orElse: () => _kLanguages.first);
                return _NavTile(
                  icon: Icons.language_rounded,
                  label: l10n.settings_label_language,
                  value: lang.englishName,
                  onTap: () => _showLanguageSheet(context, lang),
                );
              },
            ),
            _Divider(),
            _NavTile(
              icon: Icons.star_outline_rounded,
              label: l10n.settings_label_rate,
              onTap: () =>
                  _showInfoSnackbar(context, l10n.settings_label_rate_snackbar),
            ),
            _Divider(),
            _InfoTile(
              icon: Icons.info_outline_rounded,
              label: l10n.settings_label_version,
              value: '1.0.0 (build 1)',
            ),
          ]),

          // ── 6. SAFETY ─────────────────────────────────────
          _SectionHeader(l10n.settings_section_safety),
          BlocBuilder<BlockReportCubit, BlockReportState>(
            builder: (context, brs) => _SettingsCard(children: [
              _NavTile(
                icon: Icons.block_rounded,
                label: l10n.settings_label_blocked,
                value: brs.blockedUsers.isEmpty
                    ? l10n.settings_label_blocked_none
                    : l10n
                        .settings_label_blocked_count(brs.blockedUsers.length),
                onTap: () => context.push(AppRoutes.blockList),
              ),
              _Divider(),
              _NavTile(
                icon: Icons.flag_outlined,
                label: l10n.settings_label_reports,
                value: brs.reportHistory.isEmpty
                    ? l10n.settings_label_reports_none
                    : l10n
                        .settings_label_reports_count(brs.reportHistory.length),
                onTap: () => _showReportHistory(context, brs),
              ),
            ]),
          ),

          // ── 7. LEGAL ──────────────────────────────────────
          _SectionHeader('Help & Support', key: _helpKey),
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.help_outline_rounded,
              label: 'Help Center',
              onTap: () => context.push(AppRoutes.helpSupport),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.support_agent_rounded,
              label: l10n.settings_support_contact,
              onTap: () => _showSupportDialog(context),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.gavel_outlined,
              label: l10n.localeName == 'ar'
                  ? 'Ù…Ø³Ø¤ÙˆÙ„ Ø§Ù„Ø´ÙƒØ§ÙˆÙ‰'
                  : 'Grievance Officer',
              onTap: () => _showGrievanceInfo(context),
            ),
          ]),

          _SectionHeader(l10n.settings_section_legal),
          _SettingsCard(children: [
            _NavTile(
              icon: Icons.description_outlined,
              label:
                  l10n.localeName == 'ar' ? 'شروط الخدمة' : 'Terms of Service',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const LegalDocScreen(type: 'tos')),
              ),
            ),
            _Divider(),
            _NavTile(
              icon: Icons.privacy_tip_outlined,
              label:
                  l10n.localeName == 'ar' ? 'سياسة الخصوصية' : 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const LegalDocScreen(type: 'privacy')),
              ),
            ),
          ]),

          // ── 8. DANGER ZONE (Feature 15) ──────────────────
          _SectionHeader(l10n.settings_section_dangerZone),
          _SettingsCard(
            borderColor: AppColors.softCoral.withValues(alpha: 0.3),
            children: [
              _NavTile(
                icon: Icons.delete_forever_outlined,
                label: l10n.settings_button_deleteAccount,
                iconColor: AppColors.softCoral,
                labelColor: AppColors.softCoral,
                onTap: () => context.push(AppRoutes.deleteAccount),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              l10n.settings_brand_credit,
              style: AppTypography.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Grievance Officer (India IT Act 2021) ───────────────────
  static void _showGrievanceInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.gavel_outlined,
                color: AppColors.champagneGold, size: 20),
            SizedBox(width: 10),
            Text('Grievance Officer', style: AppTypography.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
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
                      const Icon(Icons.email_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: 8),
                      Text('grievance@mithaq.app',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.champagneGold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  const Text(
                    'Response time: Within 48 hours of receipt',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(
              'For users in India: We comply with the Information Technology '
              '(Intermediary Guidelines and Digital Media Ethics Code) Rules, 2021.',
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close',
                style: AppTypography.caption
                    .copyWith(color: AppColors.champagneGold)),
          ),
        ],
      ),
    );
  }

  // ── Photo privacy ──────────────────────────────────────────
  // ── Language sheet ─────────────────────────────────────────
  void _showLanguageSheet(BuildContext context, _LangOption current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<LocaleCubit>(),
        child: _LanguagePickerSheet(currentLocale: current.locale),
      ),
    );
  }

  void _showReportHistory(BuildContext context, BlockReportState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportHistorySheet(reports: state.reportHistory),
    );
  }

  static String _fmtHour(int h) => '${h.toString().padLeft(2, '0')}:00';

  // ── Helper snackbar ─────────────────────────────────────────
  static void _showInfoSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.body),
        backgroundColor: AppColors.surfaceGlassHover,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Phone masking helper ───────────────────────────────────
  static String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return 'Add email';
    final parts = email.split('@');
    if (parts.length != 2 || parts.first.isEmpty) return email;
    final name = parts.first;
    final domain = parts.last;
    if (name.length == 1) return '${name[0]}***@$domain';
    return '${name[0]}***${name[name.length - 1]}@$domain';
  }

  // ignore: unused_element
  static String maskPhone(String? phone) {
    if (phone == null || phone.isEmpty) return '•••• ••••';
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.length <= 4) return '•••• ••••';
    final last4 = digits.substring(digits.length - 4);
    final prefix = digits.substring(0, digits.length - 4);
    final masked = prefix.replaceAll(RegExp(r'\d'), '•');
    return '$masked$last4';
  }

  // ── Support dialog ──────────────────────────────────────────
  static void _showSupportDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded,
                color: AppColors.champagneGold, size: 20),
            const SizedBox(width: 10),
            Text(l10n.settings_support_contact,
                style: AppTypography.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings_support_body,
              style: AppTypography.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppDimensions.space16),
            Container(
              width: double.infinity,
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
                      const Icon(Icons.email_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: 8),
                      Text('support@mithaq.app',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.champagneGold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    l10n.settings_support_note,
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.settings_support_btn_close,
                style: AppTypography.caption
                    .copyWith(color: AppColors.champagneGold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GUARDIAN SECTION (Feature 13)
// ═══════════════════════════════════════════════════════════════

class _GuardianSection extends StatefulWidget {
  const _GuardianSection();

  @override
  State<_GuardianSection> createState() => _GuardianSectionState();
}

class _GuardianSectionState extends State<_GuardianSection> {
  bool _enabled = false;
  bool _mirror = false;
  bool _canReply = false;
  String _relationship = 'Father';
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saved = false;

  static const _relationships = [
    'Father',
    'Mother',
    'Brother',
    'Uncle',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool(_kGuardianEnabled) ?? false;
      _mirror = prefs.getBool(_kGuardianMirror) ?? false;
      _canReply = prefs.getBool(_kGuardianCanReply) ?? false;
      _relationship = prefs.getString(_kGuardianRelationship) ?? 'Father';
      _nameCtrl.text = prefs.getString(_kGuardianName) ?? '';
      _phoneCtrl.text = prefs.getString(_kGuardianPhone) ?? '';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuardianEnabled, _enabled);
    await prefs.setString(_kGuardianName, _nameCtrl.text.trim());
    await prefs.setString(_kGuardianPhone, _phoneCtrl.text.trim());
    await prefs.setString(_kGuardianRelationship, _relationship);
    await prefs.setBool(_kGuardianMirror, _mirror);
    await prefs.setBool(_kGuardianCanReply, _canReply);
    if (mounted) {
      setState(() => _saved = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    }
  }

  String _relationLabel(AppLocalizations l10n, String relation) {
    switch (relation) {
      case 'Father':
        return l10n.settings_relation_father;
      case 'Mother':
        return l10n.settings_relation_mother;
      case 'Brother':
        return l10n.settings_relation_brother;
      case 'Uncle':
        return l10n.settings_relation_uncle;
      case 'Other':
        return l10n.settings_relation_other;
      default:
        return relation;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsCard(children: [
      // Guardian Mode master toggle
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: const Icon(Icons.supervisor_account_outlined,
            color: AppColors.champagneGold, size: 20),
        title: Text(l10n.settings_guardian_title, style: AppTypography.body),
        subtitle:
            Text(l10n.settings_guardian_sub, style: AppTypography.caption),
        trailing: Switch(
          value: _enabled,
          onChanged: (v) => setState(() => _enabled = v),
          activeThumbColor: AppColors.obsidianNight,
          activeTrackColor: AppColors.champagneGold,
          inactiveThumbColor: AppColors.slateMist,
          inactiveTrackColor: AppColors.surfaceGlassHover,
        ),
      ),

      // Expandable guardian details
      AnimatedSize(
        duration: AppDimensions.durationReveal,
        curve: Curves.easeOutCubic,
        child: _enabled
            ? Column(children: [
                const _DividerFull(),
                // Guardian name
                _TextFieldTile(
                  icon: Icons.person_outline_rounded,
                  hint: l10n.settings_guardian_name_hint,
                  controller: _nameCtrl,
                ),
                const _DividerFull(),
                // Guardian phone
                _TextFieldTile(
                  icon: Icons.phone_outlined,
                  hint: l10n.settings_guardian_phone_hint,
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const _DividerFull(),
                // Relationship dropdown
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.family_restroom_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text(l10n.settings_guardian_relationship,
                      style: AppTypography.body),
                  trailing: DropdownButton<String>(
                    value: _relationship,
                    dropdownColor: AppColors.surfaceDark,
                    underline: const SizedBox.shrink(),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.champagneGold),
                    icon: const Icon(Icons.expand_more_rounded,
                        color: AppColors.slateMist, size: 16),
                    items: _relationships
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(_relationLabel(l10n, r),
                                  style: AppTypography.body),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _relationship = v);
                    },
                  ),
                ),
                const _DividerFull(),
                // Mirror messages toggle
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.content_copy_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text(l10n.settings_guardian_mirror,
                      style: AppTypography.body),
                  subtitle: Text(l10n.settings_guardian_mirror_sub,
                      style: AppTypography.caption),
                  trailing: Switch(
                    value: _mirror,
                    onChanged: (v) => setState(() => _mirror = v),
                    activeThumbColor: AppColors.obsidianNight,
                    activeTrackColor: AppColors.champagneGold,
                    inactiveThumbColor: AppColors.slateMist,
                    inactiveTrackColor: AppColors.surfaceGlassHover,
                  ),
                ),
                const _DividerFull(),
                // Guardian can reply toggle
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.reply_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text(l10n.settings_guardian_reply,
                      style: AppTypography.body),
                  subtitle: Text(l10n.settings_guardian_reply_sub,
                      style: AppTypography.caption),
                  trailing: Switch(
                    value: _canReply,
                    onChanged: (v) => setState(() => _canReply = v),
                    activeThumbColor: AppColors.obsidianNight,
                    activeTrackColor: AppColors.champagneGold,
                    inactiveThumbColor: AppColors.slateMist,
                    inactiveTrackColor: AppColors.surfaceGlassHover,
                  ),
                ),
                const _DividerFull(),
                // Save button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeightSmall,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.champagneGold,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                      ),
                      onPressed: _save,
                      child: AnimatedSwitcher(
                        duration: AppDimensions.durationTransition,
                        child: _saved
                            ? Row(
                                key: const ValueKey('saved'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_rounded,
                                      color: AppColors.obsidianNight, size: 16),
                                  const SizedBox(width: 6),
                                  Text(l10n.settings_guardian_saved,
                                      style: AppTypography.button),
                                ],
                              )
                            : Text(l10n.settings_guardian_save,
                                key: const ValueKey('save'),
                                style: AppTypography.button),
                      ),
                    ),
                  ),
                ),
              ])
            : const SizedBox.shrink(),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════
// PRIVACY SECTION (Feature 14)
// ═══════════════════════════════════════════════════════════════

class _PrivacySection extends StatefulWidget {
  const _PrivacySection();
  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  // Defaults
  String _photoVisibility = 'Everyone';
  bool _showOnlineStatus = true;
  bool _profilePaused = false;
  String _profileVisibility = 'All registered users';

  // Animated save checkmark
  final Map<String, bool> _savedIndicators = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var photoVisibility = prefs.getString(_kPhotoVisibility) ?? 'Everyone';
    var profilePaused = prefs.getBool(_kProfilePaused) ?? false;

    if (SupabaseService.isInitialized &&
        SupabaseService.currentUserId != null) {
      try {
        final row = await SupabaseService.client
            .from('profiles')
            .select('photo_privacy, visibility')
            .eq('user_id', SupabaseService.currentUserId!)
            .maybeSingle();
        final dbPhotoPrivacy = row?['photo_privacy'] as String?;
        final dbVisibility = row?['visibility'] as String?;
        photoVisibility = _photoVisibilityFromDb(dbPhotoPrivacy);
        profilePaused = dbVisibility == 'paused';
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _photoVisibility = photoVisibility;
      _showOnlineStatus = prefs.getBool(_kShowOnlineStatus) ?? true;
      _profilePaused = profilePaused;
      _profileVisibility =
          prefs.getString(_kProfileVisibility) ?? 'All registered users';
    });
  }

  Future<void> _persist(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    }
    if (value is String) {
      await prefs.setString(key, value);
    }
    await _persistBackend(key, value);
    if (!mounted) return;
    setState(() => _savedIndicators[key] = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedIndicators[key] = false);
    });
  }

  Future<void> _persistBackend(String key, dynamic value) async {
    if (!SupabaseService.isInitialized ||
        SupabaseService.currentUserId == null) {
      return;
    }
    try {
      final updates = <String, dynamic>{};
      if (key == _kPhotoVisibility && value is String) {
        updates['photo_privacy'] = _photoVisibilityToDb(value);
      } else if (key == _kProfilePaused && value is bool) {
        updates['visibility'] = value ? 'paused' : 'visible';
      }
      if (updates.isEmpty) return;
      await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('user_id', SupabaseService.currentUserId!);
    } catch (e) {
      debugPrint('SettingsScreen: failed to persist privacy setting: $e');
    }
  }

  String _photoVisibilityFromDb(String? value) {
    switch (value) {
      case 'mutual_only':
        return 'Accepted interests only';
      case 'request_only':
        return 'Request to view';
      case 'public':
      default:
        return 'Everyone';
    }
  }

  String _photoVisibilityToDb(String value) {
    switch (value) {
      case 'Accepted interests only':
        return 'mutual_only';
      case 'Request to view':
        return 'request_only';
      case 'Everyone':
      default:
        return 'public';
    }
  }

  String _photoPrivacyLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'Public':
        return l10n.settings_photo_privacy_public;
      case 'After Acceptance':
        return l10n.settings_photo_privacy_after_acceptance;
      case 'Request Only':
        return l10n.settings_photo_privacy_request_only;
      case 'Everyone':
        return l10n.settings_photo_privacy_everyone;
      case 'Accepted interests only':
        return l10n.settings_photo_privacy_accepted_interests;
      case 'Request to view':
        return l10n.settings_photo_privacy_request_to_view;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(children: [
      // ── Photo Visibility ───────────────────────────────────
      _PrivacyCard(
        label: l10n.settings_privacy_photo_label,
        subtitle: l10n.settings_privacy_photo_sub,
        saved: _savedIndicators[_kPhotoVisibility] ?? false,
        child: Column(children: [
          const SizedBox(height: 8),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Everyone'),
            selected: _photoVisibility == 'Everyone',
            onTap: () {
              setState(() => _photoVisibility = 'Everyone');
              _persist(_kPhotoVisibility, 'Everyone');
            },
          ),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Accepted interests only'),
            selected: _photoVisibility == 'Accepted interests only',
            onTap: () {
              setState(() => _photoVisibility = 'Accepted interests only');
              _persist(_kPhotoVisibility, 'Accepted interests only');
            },
          ),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Request to view'),
            selected: _photoVisibility == 'Request to view',
            onTap: () {
              setState(() => _photoVisibility = 'Request to view');
              _persist(_kPhotoVisibility, 'Request to view');
            },
          ),
        ]),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Online Status ──────────────────────────────────────
      _PrivacyCard(
        label: l10n.settings_privacy_online_label,
        subtitle: l10n.settings_privacy_online_sub,
        saved: _savedIndicators[_kShowOnlineStatus] ?? false,
        child: _PrivacyToggle(
          value: _showOnlineStatus,
          onChanged: (v) {
            setState(() => _showOnlineStatus = v);
            _persist(_kShowOnlineStatus, v);
          },
        ),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Profile Pause ──────────────────────────────────────
      _PrivacyCard(
        label: l10n.settings_privacy_pause_label,
        subtitle: l10n.settings_privacy_pause_sub,
        saved: _savedIndicators[_kProfilePaused] ?? false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrivacyToggle(
              value: _profilePaused,
              onChanged: (v) {
                setState(() => _profilePaused = v);
                _persist(_kProfilePaused, v);
              },
            ),
            if (_profilePaused) ...[
              const SizedBox(height: AppDimensions.space8),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color: AppColors.premiumGold.withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(
                      color: AppColors.premiumGold.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility_off_outlined,
                      color: AppColors.premiumGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.settings_privacy_pause_warning,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.premiumGold),
                    ),
                  ),
                ]),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Who Can See My Profile ─────────────────────────────
      _PrivacyCard(
        label: l10n.settings_privacy_visibility_label,
        subtitle: l10n.settings_privacy_visibility_sub,
        saved: _savedIndicators[_kProfileVisibility] ?? false,
        child: Column(children: [
          const SizedBox(height: 8),
          _RadioRow(
            label: l10n.settings_privacy_visibility_all,
            selected: _profileVisibility == 'All registered users',
            onTap: () {
              setState(() => _profileVisibility = 'All registered users');
              _persist(_kProfileVisibility, 'All registered users');
            },
          ),
          _RadioRow(
            label: l10n.settings_privacy_visibility_subscribers,
            selected: _profileVisibility == 'Subscribers only',
            onTap: () {
              setState(() => _profileVisibility = 'Subscribers only');
              _persist(_kProfileVisibility, 'Subscribers only');
            },
          ),
        ]),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Download My Data (GDPR) ────────────────────────────
      _PrivacyCard(
        label: l10n.settings_privacy_download_label,
        subtitle: l10n.settings_privacy_download_sub,
        saved: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.space12),
            Text(
              l10n.settings_privacy_download_body,
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppDimensions.space16),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.download_rounded,
                    color: AppColors.obsidianNight, size: 16),
                label: Text(
                  l10n.settings_privacy_download_btn,
                  style: AppTypography.button
                      .copyWith(color: AppColors.obsidianNight),
                ),
                onPressed: () => _triggerDataExport(context),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  void _triggerDataExport(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceMid,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.download_done_rounded,
                color: AppColors.verifiedTeal, size: 20),
            const SizedBox(width: 10),
            Text(l10n.settings_privacy_export_title,
                style: AppTypography.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settings_privacy_export_body,
              style: AppTypography.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(
              l10n.settings_privacy_export_subbody,
              style: AppTypography.caption.copyWith(height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.settings_privacy_export_btn_close,
                style: AppTypography.caption
                    .copyWith(color: AppColors.champagneGold)),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.label,
    required this.subtitle,
    required this.child,
    required this.saved,
  });
  final String label;
  final String subtitle;
  final Widget child;
  final bool saved;

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
          Row(children: [
            Expanded(
              child: Text(label, style: AppTypography.sectionLabel),
            ),
            AnimatedSwitcher(
              duration: AppDimensions.durationTransition,
              child: saved
                  ? Row(
                      key: const ValueKey('saved'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: AppColors.verifiedTeal, size: 14),
                        const SizedBox(width: 3),
                        Text(
                            AppLocalizations.of(context)
                                .settings_guardian_saved,
                            style: AppTypography.caption.copyWith(
                                color: AppColors.verifiedTeal, fontSize: 11)),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('empty')),
            ),
          ]),
          const SizedBox(height: 2),
          Text(subtitle, style: AppTypography.caption),
          child,
        ],
      ),
    );
  }
}

class _PrivacyToggle extends StatelessWidget {
  const _PrivacyToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.obsidianNight,
        activeTrackColor: AppColors.champagneGold,
        inactiveThumbColor: AppColors.slateMist,
        inactiveTrackColor: AppColors.surfaceGlassHover,
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space10),
        child: Row(children: [
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? AppColors.champagneGold : Colors.transparent,
              border: Border.all(
                color: selected ? AppColors.champagneGold : AppColors.slateMist,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    color: AppColors.obsidianNight, size: 14)
                : null,
          ),
          const SizedBox(width: AppDimensions.space12),
          Text(label, style: AppTypography.body),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LANGUAGE PICKER SHEET (Feature 16)
// ═══════════════════════════════════════════════════════════════

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.currentLocale});
  final String currentLocale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text(l10n.settings_label_language,
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          ..._kLanguages.map((lang) {
            final isSelected = lang.locale == currentLocale;
            return GestureDetector(
              onTap: () async {
                await context
                    .read<LocaleCubit>()
                    .setLocale(Locale(lang.locale));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          l10n.localeName == 'ar'
                              ? 'تم تحديث اللغة إلى ${lang.nativeName}'
                              : 'Language updated to ${lang.englishName}',
                          style: AppTypography.body),
                      backgroundColor: AppColors.surfaceGlassHover,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color:
                      isSelected ? AppColors.goldGlow : AppColors.surfaceGlass,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.champagneGold
                        : AppColors.cardBorder,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Expanded(
                    child: lang.isRtl
                        ? Directionality(
                            textDirection: TextDirection.rtl,
                            child: Row(children: [
                              Text(lang.nativeName,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: isSelected
                                        ? AppColors.champagneGold
                                        : AppColors.pearlWhite,
                                  )),
                              const SizedBox(width: 8),
                              Text('(${lang.englishName})',
                                  style: AppTypography.caption),
                            ]),
                          )
                        : Row(children: [
                            Text(lang.nativeName,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.champagneGold
                                      : AppColors.pearlWhite,
                                )),
                            if (lang.nativeName != lang.englishName) ...[
                              const SizedBox(width: 8),
                              Text('(${lang.englishName})',
                                  style: AppTypography.caption),
                            ],
                          ]),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_rounded,
                        color: AppColors.champagneGold, size: 18),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SHARED TILE & CARD WIDGETS
// ═══════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
        child: Text(label, style: AppTypography.sectionLabel),
      );
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color? borderColor;
  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          color: AppColors.surfaceGlass,
          border: Border.all(color: borderColor ?? AppColors.cardBorder),
        ),
        child: Column(children: children),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
        color: AppColors.divider,
        height: 1,
        indent: 52,
        endIndent: 16,
      );
}

class _DividerFull extends StatelessWidget {
  const _DividerFull();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.divider, height: 1);
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: iconColor ?? AppColors.slateMist, size: 20),
        title:
            Text(label, style: AppTypography.body.copyWith(color: labelColor)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Text(value!,
                  style: AppTypography.caption.copyWith(
                    color: labelColor != null
                        ? labelColor!.withValues(alpha: 0.7)
                        : AppColors.slateMist,
                  )),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: iconColor ?? AppColors.slateMist, size: 18),
          ],
        ),
      );
}

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: AppColors.slateMist, size: 20),
        title: Text(label, style: AppTypography.body),
        subtitle: caption != null
            ? Text(caption!, style: AppTypography.caption)
            : null,
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.obsidianNight,
          activeTrackColor: AppColors.champagneGold,
          inactiveThumbColor: AppColors.slateMist,
          inactiveTrackColor: AppColors.surfaceGlassHover,
        ),
      );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoTile({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: AppColors.slateMist, size: 20),
        title: Text(label, style: AppTypography.body),
        trailing:
            value != null ? Text(value!, style: AppTypography.caption) : null,
      );
}

class _TextFieldTile extends StatelessWidget {
  const _TextFieldTile({
    required this.icon,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });
  final IconData icon;
  final String hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(icon, color: AppColors.slateMist, size: 20),
        title: TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: AppTypography.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.bodyMuted,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );
}

// ── Report History Sheet ──────────────────────────────────────

class _ReportHistorySheet extends StatelessWidget {
  final List<ReportEntry> reports;
  const _ReportHistorySheet({required this.reports});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.cardBorder,
                      borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(l10n.settings_label_reports,
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(l10n.settings_label_reports_none,
                  style: AppTypography.bodyMuted),
            ))
          else
            ...reports.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.surfaceGlass,
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(children: [
                      const Icon(Icons.flag_outlined,
                          color: AppColors.softCoral, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.reportedName, style: AppTypography.bodyMedium),
                          Text(r.reason.label, style: AppTypography.caption),
                        ],
                      )),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          color: AppColors.surfaceGlassHover,
                        ),
                        child: Text(
                            l10n.localeName == 'ar'
                                ? 'قيد المراجعة'
                                : 'Pending',
                            style:
                                AppTypography.caption.copyWith(fontSize: 10)),
                      ),
                    ]),
                  ),
                )),
        ],
      ),
    );
  }
}
