// lib/features/home/screens/settings_screen.dart
// ============================================================
// SILARAH — Settings Screen
// Sections:
//   1. ACCOUNT   — phone, photo privacy
//   2. NOTIFICATIONS — per-category toggles
//   3. GUARDIAN  — wali and guardian details
//   4. PRIVACY   — profile and photo visibility
//   5. APP       — language and version
//   6. SAFETY    — block list, report history
//   7. LEGAL     — ToS, Privacy Policy
//   8. DANGER ZONE — account deletion
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/generated/app_localizations.dart';

import '../../../core/cubits/locale/locale_cubit.dart';
import '../../../core/cubits/theme/theme_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_state.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/account_standing/account_standing_cubit.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/profile_photo_service.dart';
import '../../../core/services/app_lifecycle_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/wali_mode_service.dart';
import '../../../core/legal/legal_documents.dart';
import 'legal_doc_screen.dart';

const _kLanguages = LocaleCubit.supportedLanguages;

// ── Guardian prefs keys ───────────────────────────────────────

const _kGuardianPhoneUnavailable =
    'Saved securely. Re-enter only if you need to change it.';

// ── Privacy prefs keys ────────────────────────────────────────

const _kPhotoVisibility = 'privacy_photo_visibility';
const _kProfilePaused = 'privacy_profile_paused';

IconData _legalIcon(String slug) => switch (slug) {
      'terms' => Icons.description_outlined,
      'privacy' => Icons.privacy_tip_outlined,
      'community-guidelines' => Icons.groups_2_outlined,
      'child-safety' => Icons.child_care_outlined,
      'refund-policy' => Icons.receipt_long_outlined,
      'data-deletion' => Icons.delete_sweep_outlined,
      'verification-policy' => Icons.badge_outlined,
      'photo-moderation-policy' => Icons.photo_filter_outlined,
      'guardian-policy' => Icons.family_restroom_outlined,
      _ => Icons.policy_outlined,
    };

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
  String _appVersion = '—';

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
    }
  }

  Future<void> _loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = '${info.version} (${info.buildNumber})');
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
          icon: Icon(Icons.arrow_back_ios_new_rounded,
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
            Builder(
              builder: (ctx) {
                final data = ctx.read<OnboardingCubit>().currentData;
                final email = data.email ??
                    (SupabaseService.isInitialized
                        ? SupabaseService.client.auth.currentUser?.email
                        : null);
                return _InfoTile(
                  icon: Icons.alternate_email_rounded,
                  label: 'Email',
                  value: _maskEmail(email),
                );
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
                icon: Icons.public_rounded,
                label: 'Profile goes live',
                caption: 'Confirmation when your profile becomes visible',
                value: prefs.profileLive,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleProfileLive(v),
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
              _NavTile(
                icon: Icons.bedtime_outlined,
                label: l10n.settings_notify_quietHours,
                value:
                    '${_fmtHour(prefs.quietStartHour)} – ${_fmtHour(prefs.quietEndHour)}',
                onTap: () => _changeQuietHours(context, prefs),
              ),
            ]),
          ),

          // ── 3. GUARDIAN ───────────────────────────────────
          _SectionHeader(l10n.settings_section_guardian),
          const _GuardianSection(),

          // ── 4. PRIVACY ────────────────────────────────────
          _SectionHeader(l10n.settings_section_privacy, key: _privacyKey),
          const _PrivacySection(),

          // ── 5. APP ────────────────────────────────────────
          _SectionHeader(l10n.settings_section_app),
          _SettingsCard(children: [
            BlocBuilder<ThemeCubit, ThemeSelectionState>(
              builder: (context, themeState) => _NavTile(
                icon: Icons.palette_outlined,
                label: 'Appearance',
                value: themeState.requiresRestart
                    ? '${themeState.selectedMode.label} · restart'
                    : themeState.activeMode.label,
                onTap: () => _showThemeSheet(context),
              ),
            ),
            _Divider(),
            BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                final lang = _kLanguages.firstWhere(
                    (l) => l.code == locale.languageCode,
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
            _InfoTile(
              icon: Icons.info_outline_rounded,
              label: l10n.settings_label_version,
              value: _appVersion,
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
              icon: Icons.gavel_outlined,
              label: l10n.localeName == 'ar'
                  ? 'مسؤول الشكاوى'
                  : 'Grievance Officer',
              onTap: () => _showGrievanceInfo(context),
            ),
          ]),

          _SectionHeader(l10n.settings_section_legal),
          _SettingsCard(
            children: [
              for (var index = 0;
                  index < LegalDocuments.all.length;
                  index++) ...[
                _NavTile(
                  icon: _legalIcon(LegalDocuments.all[index].slug),
                  label: LegalDocuments.all[index].title,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LegalDocScreen(
                        type: LegalDocuments.all[index].slug,
                      ),
                    ),
                  ),
                ),
                if (index != LegalDocuments.all.length - 1) _Divider(),
              ],
            ],
          ),

          // ── 8. DANGER ZONE ────────────────────────────────
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
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            Icon(Icons.gavel_outlined,
                color: AppColors.champagneGold, size: 20),
            const SizedBox(width: 10),
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
                      Icon(Icons.email_outlined,
                          color: AppColors.champagneGold, size: 16),
                      const SizedBox(width: 8),
                      Text('grievance@silarah.com',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.champagneGold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space12),
                  Text(
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
  void _showThemeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayBlack55,
      builder: (sheetContext) => BlocProvider<ThemeCubit>.value(
        value: context.read<ThemeCubit>(),
        child: _ThemePickerSheet(
          onThemeScheduled: (mode) {
            Navigator.of(sheetContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) _showThemeRestartSheet(context, mode);
            });
          },
        ),
      ),
    );
  }

  void _showThemeRestartSheet(
    BuildContext context,
    SilarahThemeMode mode,
  ) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.overlayBlack55,
      builder: (_) => _ThemeRestartSheet(mode: mode),
    );
  }

  void _showLanguageSheet(BuildContext context, SupportedLanguage current) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => BlocProvider.value(
        value: context.read<LocaleCubit>(),
        child: _LanguagePickerSheet(currentLocale: current.code),
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

  Future<void> _changeQuietHours(
    BuildContext context,
    NotificationPrefsState prefs,
  ) async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.quietStartHour, minute: 0),
      helpText: 'Quiet hours start',
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (start == null || !context.mounted) return;

    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: prefs.quietEndHour, minute: 0),
      helpText: 'Quiet hours end',
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (end == null || !context.mounted) return;

    context.read<NotificationPrefsCubit>().setQuietHours(
          startHour: start.hour,
          endHour: end.hour,
        );
  }

  // ── Helper snackbar ─────────────────────────────────────────
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
}

// ═══════════════════════════════════════════════════════════════
// GUARDIAN SECTION
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
  bool _saving = false;
  bool _hasGuardianPhoneOnServer = false;

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
    if (!SupabaseService.isInitialized) return;
    final info = await WaliModeService.instance.getMyGuardianInfo();
    if (!mounted) return;
    if (info == null) return;
    setState(() {
      _enabled = true;
      _mirror = true;
      _canReply = info.mode == 'active';
      _relationship = _relationLabelFromDb(info.relationship);
      _nameCtrl.text = info.name;
      _phoneCtrl.clear();
      _hasGuardianPhoneOnServer = true;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_enabled &&
        (_nameCtrl.text.trim().isEmpty ||
            (!_hasGuardianPhoneOnServer && _phoneCtrl.text.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.settings_guardian_name_hint} and ${l10n.settings_guardian_phone_hint} are required.',
          ),
        ),
      );
      return;
    }

    if (!SupabaseService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian settings require a backend connection.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await WaliModeService.instance.saveMyGuardianSettings(
        enabled: _enabled,
        guardianName: _nameCtrl.text,
        guardianPhone: _phoneCtrl.text,
        relationship: _relationship,
        canReply: _canReply,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save guardian settings. Please try again.'),
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _saving = false;
        _saved = true;
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

  String _relationLabelFromDb(String? relation) {
    switch (relation) {
      case 'father':
        return 'Father';
      case 'mother':
        return 'Mother';
      case 'brother':
        return 'Brother';
      case 'uncle':
        return 'Uncle';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SettingsCard(children: [
      // Guardian Mode master toggle
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(Icons.supervisor_account_outlined,
            color: AppColors.champagneGold, size: 20),
        title: Text(l10n.settings_guardian_title, style: AppTypography.body),
        subtitle:
            Text(l10n.settings_guardian_sub, style: AppTypography.caption),
        trailing: Switch(
          value: _enabled,
          onChanged: (v) => setState(() {
            _enabled = v;
            if (v) _mirror = true;
            if (!v) {
              _mirror = false;
              _canReply = false;
            }
          }),
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
                if (_hasGuardianPhoneOnServer && _phoneCtrl.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                    child: Text(
                      _kGuardianPhoneUnavailable,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                      ),
                    ),
                  ),
                const _DividerFull(),
                // Relationship dropdown
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Icon(Icons.family_restroom_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text(l10n.settings_guardian_relationship,
                      style: AppTypography.body),
                  trailing: DropdownButton<String>(
                    value: _relationship,
                    dropdownColor: AppColors.surfaceDark,
                    underline: const SizedBox.shrink(),
                    style: AppTypography.caption
                        .copyWith(color: AppColors.champagneGold),
                    icon: Icon(Icons.expand_more_rounded,
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
                  leading: Icon(Icons.content_copy_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text(l10n.settings_guardian_mirror,
                      style: AppTypography.body),
                  subtitle: Text(l10n.settings_guardian_mirror_sub,
                      style: AppTypography.caption),
                  trailing: Switch(
                    value: _mirror,
                    onChanged: (v) => setState(() {
                      _mirror = v;
                      if (!v) _canReply = false;
                    }),
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
                  leading: Icon(Icons.reply_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text(l10n.settings_guardian_reply,
                      style: AppTypography.body),
                  subtitle: Text(l10n.settings_guardian_reply_sub,
                      style: AppTypography.caption),
                  trailing: Switch(
                    value: _canReply,
                    onChanged: (v) => setState(() {
                      _canReply = v;
                      if (v) _mirror = true;
                    }),
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
                      onPressed: _saving ? null : _save,
                      child: AnimatedSwitcher(
                        duration: AppDimensions.durationTransition,
                        child: _saving
                            ? SilarahPulseLoader(
                                key: const ValueKey('saving'),
                                size: 24,
                                accentColor: AppColors.obsidianNight,
                                highlightColor: AppColors.obsidianDeep,
                                markColor: AppColors.champagneLight,
                                coreGradientColors: [
                                  AppColors.obsidianNight,
                                  AppColors.obsidianDeep,
                                ],
                              )
                            : _saved
                                ? Row(
                                    key: const ValueKey('saved'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check_rounded,
                                          color: AppColors.obsidianNight,
                                          size: 16),
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
// PRIVACY SECTION
// ═══════════════════════════════════════════════════════════════

class _PrivacySection extends StatefulWidget {
  const _PrivacySection();
  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  // Defaults
  String _photoVisibility = 'Everyone';
  bool _profilePaused = false;
  bool _profilePauseSaving = false;
  String _profileVisibility = 'visible';
  String? _visibilityBlockReason;
  // Animated save checkmark
  final Map<String, bool> _savedIndicators = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var photoVisibility = 'Everyone';
    var profilePaused = false;

    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (SupabaseService.isInitialized && userId != null) {
      try {
        final row = await SupabaseService.client
            .from('profiles')
            .select('id, photo_privacy, visibility, onboarding_completed')
            .eq('user_id', userId)
            .maybeSingle();
        final dbPhotoPrivacy = row?['photo_privacy'] as String?;
        final dbVisibility = row?['visibility'] as String?;
        photoVisibility = _photoVisibilityFromDb(dbPhotoPrivacy);
        _profileVisibility = dbVisibility ?? 'visible';
        profilePaused = _profileVisibility != 'visible';
        _visibilityBlockReason = await _visibilityBlockReasonFor(row);
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _photoVisibility = photoVisibility;
      _profilePaused = profilePaused;
    });
  }

  Future<void> _persist(String key, dynamic value,
      {Object? previousValue}) async {
    final backendError = await _persistBackend(key, value);
    if (backendError != null) {
      if (!mounted) return;
      setState(() {
        if (key == _kPhotoVisibility) {
          _photoVisibility = previousValue as String? ?? _photoVisibility;
        } else if (key == _kProfilePaused) {
          _profilePaused = previousValue as bool? ?? _profilePaused;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(backendError)),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _savedIndicators[key] = true);
  }

  Future<String?> _persistBackend(String key, dynamic value) async {
    if (!SupabaseService.isInitialized) {
      return 'Could not connect to Silarah. Please try again.';
    }
    final userId = await SupabaseService.currentUserIdOrRefresh();
    if (userId == null) {
      return 'Please sign in again to update this setting.';
    }
    try {
      final updates = <String, dynamic>{};
      if (key == _kPhotoVisibility && value is String) {
        updates['photo_privacy'] = _photoVisibilityToDb(value);
      } else if (key == _kProfilePaused && value is bool) {
        final response = await SupabaseService.client.rpc(
          'set_profile_pause',
          params: {'p_paused': value},
        );
        final rows = response as List<dynamic>;
        if (rows.isNotEmpty && mounted) {
          final row = Map<String, dynamic>.from(rows.first as Map);
          setState(() => _profilePaused = row['is_paused'] == true);
          _profileVisibility = row['visibility']?.toString() ?? 'visible';
          _visibilityBlockReason = null;
        }
        if (mounted) {
          await context.read<AccountStandingCubit>().refresh();
        }
        return null;
      }
      if (updates.isEmpty) return null;
      await SupabaseService.client
          .from('profiles')
          .update(updates)
          .eq('user_id', userId);
      if (key == _kPhotoVisibility && value is String && mounted) {
        final privacy = switch (_photoVisibilityToDb(value)) {
          'mutual_only' => PhotoPrivacy.mutualOnly,
          'request_only' => PhotoPrivacy.requestOnly,
          _ => PhotoPrivacy.publicAll,
        };
        await context.read<OnboardingCubit>().syncPhotoPrivacy(privacy);
        ProfilePhotoService.instance.invalidateAllPhotoUrls();
      }
      return null;
    } on PostgrestException catch (error) {
      return _settingsErrorMessage(error.message);
    } catch (error) {
      return _settingsErrorMessage(error.toString());
    }
  }

  Future<String?> _visibilityBlockReasonFor(Map<String, dynamic>? row) async {
    if (row == null) return 'Complete your profile before changing visibility.';
    final visibility = row['visibility'] as String? ?? 'visible';
    if (visibility == 'suspended') {
      return 'This profile is suspended and cannot be made visible from settings.';
    }
    if (visibility == 'deactivated') {
      return 'This profile is deactivated and cannot be made visible from settings.';
    }
    if (row['onboarding_completed'] != true) {
      return 'Complete onboarding before making your profile visible.';
    }
    final profileId = row['id'] as String?;
    if (profileId == null || profileId.isEmpty) {
      return 'Complete your profile before changing visibility.';
    }
    final photos = await SupabaseService.client
        .from('photos')
        .select('id')
        .eq('profile_id', profileId)
        .eq('order_index', 0)
        .eq('status', 'active')
        .eq('moderation_status', 'approved')
        .eq('admin_approved', true)
        .eq('nsfw_cleared', true)
        .limit(1);
    if ((photos as List<dynamic>).isEmpty) {
      return 'Add a profile photo that passes the safety scan before making your profile visible.';
    }
    return null;
  }

  String _settingsErrorMessage(String message) {
    final cleaned = message
        .replaceAll('Exception:', '')
        .replaceAll('PostgrestException(message:', '')
        .trim();
    if (cleaned.isEmpty || cleaned == 'null') {
      return 'Could not save. Please try again.';
    }
    return cleaned;
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
    final unpauseBlocked = _profilePaused && _visibilityBlockReason != null;
    final pauseWarning =
        _visibilityBlockReason ?? l10n.settings_privacy_pause_warning;
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
              final previous = _photoVisibility;
              setState(() => _photoVisibility = 'Everyone');
              _persist(_kPhotoVisibility, 'Everyone', previousValue: previous);
            },
          ),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Accepted interests only'),
            selected: _photoVisibility == 'Accepted interests only',
            onTap: () {
              final previous = _photoVisibility;
              setState(() => _photoVisibility = 'Accepted interests only');
              _persist(
                _kPhotoVisibility,
                'Accepted interests only',
                previousValue: previous,
              );
            },
          ),
          _RadioRow(
            label: _photoPrivacyLabel(l10n, 'Request to view'),
            selected: _photoVisibility == 'Request to view',
            onTap: () {
              final previous = _photoVisibility;
              setState(() => _photoVisibility = 'Request to view');
              _persist(
                _kPhotoVisibility,
                'Request to view',
                previousValue: previous,
              );
            },
          ),
          Divider(color: AppColors.cardBorder, height: 24),
          Semantics(
            button: true,
            label: 'Manage photo access requests',
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              onTap: () => context.push(AppRoutes.photoRequests),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.admin_panel_settings_outlined,
                        color: AppColors.champagneGold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manage photo requests',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.pearlWhite,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Approve access, decline requests, or revoke sharing',
                            style: AppTypography.caption,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.slateMist,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
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
              onChanged: _profilePauseSaving || unpauseBlocked
                  ? null
                  : (v) {
                      final previous = _profilePaused;
                      setState(() {
                        _profilePaused = v;
                        _profilePauseSaving = true;
                      });
                      _persist(
                        _kProfilePaused,
                        v,
                        previousValue: previous,
                      ).whenComplete(() {
                        if (mounted) {
                          setState(() => _profilePauseSaving = false);
                        }
                      });
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
                  Icon(Icons.visibility_off_outlined,
                      color: AppColors.premiumGold, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pauseWarning,
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

      // ── Download My Data (GDPR) ────────────────────────────
    ]);
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
                        Icon(Icons.check_rounded,
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
  final ValueChanged<bool>? onChanged;

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
                ? Icon(Icons.check_rounded,
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

class _ThemeRestartSheet extends StatefulWidget {
  const _ThemeRestartSheet({required this.mode});

  final SilarahThemeMode mode;

  @override
  State<_ThemeRestartSheet> createState() => _ThemeRestartSheetState();
}

class _ThemeRestartSheetState extends State<_ThemeRestartSheet> {
  bool _restarting = false;
  bool _restartFailed = false;

  Future<void> _restartNow() async {
    if (_restarting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _restarting = true;
      _restartFailed = false;
    });
    final accepted = await AppLifecycleService.restartNow();
    if (!mounted || accepted) return;
    setState(() {
      _restarting = false;
      _restartFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final supportsRestart = AppLifecycleService.supportsInPlaceRestart;
    return PopScope(
      canPop: !_restarting,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          18,
          24,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 24),
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: .12),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: _restarting
                  ? Padding(
                      padding: const EdgeInsets.all(17),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.champagneGold,
                      ),
                    )
                  : Icon(
                      Icons.restart_alt_rounded,
                      color: AppColors.champagneGold,
                      size: 28,
                    ),
            ),
            const SizedBox(height: 18),
            Text(
              _restarting
                  ? 'Restarting Silarah…'
                  : '${widget.mode.label} is ready',
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              supportsRestart
                  ? 'Restart now to apply the new identity consistently to every screen and system control.'
                  : 'Close and reopen Silarah to apply the new identity consistently to every screen and system control.',
              style: AppTypography.bodyMuted.copyWith(height: 1.5),
              textAlign: TextAlign.center,
            ),
            AnimatedSize(
              duration: AppDimensions.durationTransition,
              curve: Curves.easeOutCubic,
              child: _restartFailed
                  ? Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.softCoral.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.softCoral.withValues(alpha: .4),
                            ),
                          ),
                          child: Text(
                            'Silarah could not restart automatically. Your theme is saved—close and reopen the app to finish.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.softCoral,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 22),
            if (supportsRestart)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _restarting ? null : _restartNow,
                  child: const Text('Restart now'),
                ),
              ),
            if (supportsRestart) const SizedBox(height: 6),
            TextButton(
              onPressed: _restarting ? null : () => Navigator.of(context).pop(),
              child: Text(supportsRestart ? 'Later' : 'Done'),
            ),
            const SizedBox(height: 4),
            Text(
              'Your account session and saved data stay protected.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// THEME PICKER SHEET
// ═══════════════════════════════════════════════════════════════

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet({required this.onThemeScheduled});

  final ValueChanged<SilarahThemeMode> onThemeScheduled;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return BlocBuilder<ThemeCubit, ThemeSelectionState>(
      builder: (context, themeState) => AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMid,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 36,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + bottomInset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Choose your atmosphere',
                style: AppTypography.screenTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 6),
              Text(
                'A complete visual identity—not a color filter. Every surface, '
                'field and system control is applied together after restart.',
                style: AppTypography.bodyMuted,
              ),
              const SizedBox(height: 24),
              for (final mode in SilarahThemeMode.values) ...[
                _ThemePreviewCard(
                  mode: mode,
                  selected: mode == themeState.selectedMode,
                  onTap: () async {
                    if (mode == themeState.selectedMode) return;
                    HapticFeedback.selectionClick();
                    await context.read<ThemeCubit>().scheduleForRestart(mode);
                    if (context.mounted) onThemeScheduled(mode);
                  },
                ),
                if (mode != SilarahThemeMode.values.last)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restart_alt_rounded,
                    color: AppColors.verifiedTeal,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Saved on this device · restart to apply fully',
                    style: AppTypography.caption.copyWith(fontSize: 12),
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

class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SilarahThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = SilarahPalette.forMode(mode);
    return Semantics(
      button: true,
      selected: selected,
      label: '${mode.label} theme. ${mode.description}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.goldGlow : AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.champagneGold : AppColors.cardBorder,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _ThemeMiniature(palette: palette),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: AppTypography.bodyMedium.copyWith(
                        fontSize: 16,
                        color: selected
                            ? AppColors.champagneGold
                            : AppColors.pearlWhite,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(mode.description, style: AppTypography.caption),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: selected
                    ? Container(
                        key: const ValueKey('selected'),
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.champagneGold,
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: AppColors.obsidianNight,
                          size: 17,
                        ),
                      )
                    : Icon(
                        Icons.arrow_forward_ios_rounded,
                        key: const ValueKey('available'),
                        color: AppColors.slateMist,
                        size: 15,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeMiniature extends StatelessWidget {
  const _ThemeMiniature({required this.palette});

  final SilarahPalette palette;

  @override
  Widget build(BuildContext context) => Container(
        width: 72,
        height: 82,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.contentPrimary.withValues(alpha: .65),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surfaceInteractive,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 7),
            Container(
              width: double.infinity,
              height: 7,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      );
}

class _LanguagePickerSheet extends StatelessWidget {
  const _LanguagePickerSheet({required this.currentLocale});
  final String currentLocale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: ListView(
        shrinkWrap: true,
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
            final isSelected = lang.code == currentLocale;
            return GestureDetector(
              onTap: () async {
                await context.read<LocaleCubit>().setLocale(Locale(lang.code));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Language · ${lang.nativeName}',
                        style: AppTypography.body,
                      ),
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
                    Icon(Icons.check_rounded,
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
  Widget build(BuildContext context) => Divider(
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
      Divider(color: AppColors.divider, height: 1);
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
            filled: false,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
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
      decoration: BoxDecoration(
        color: AppColors.surfaceMid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      Icon(Icons.flag_outlined,
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
