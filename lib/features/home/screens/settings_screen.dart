// lib/features/home/screens/settings_screen.dart
// ============================================================
// NOOR — Settings Screen
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
import 'legal_doc_screen.dart';


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
  final bool   isRtl;
}

const _kLanguages = [
  _LangOption(locale: 'en', nativeName: 'English',            englishName: 'English'),
  _LangOption(locale: 'ar', nativeName: 'العربية',             englishName: 'Arabic',    isRtl: true),
  // Phase 2+ — uncomment after adding .arb files:
  // _LangOption(locale: 'ur', nativeName: 'اردو',                englishName: 'Urdu',      isRtl: true),
  // _LangOption(locale: 'fr', nativeName: 'Français',            englishName: 'French'),
  // _LangOption(locale: 'de', nativeName: 'Deutsch',             englishName: 'German'),
  // _LangOption(locale: 'tr', nativeName: 'Türkçe',              englishName: 'Turkish'),
  // _LangOption(locale: 'id', nativeName: 'Bahasa Indonesia',    englishName: 'Indonesian'),
  // _LangOption(locale: 'ms', nativeName: 'Bahasa Melayu',       englishName: 'Malay'),
];

// ── Guardian prefs keys ───────────────────────────────────────

const _kGuardianEnabled      = 'guardian_enabled';
const _kGuardianName         = 'guardian_name';
const _kGuardianPhone        = 'guardian_phone';
const _kGuardianRelationship = 'guardian_relationship';
const _kGuardianMirror       = 'mirror_messages';
const _kGuardianCanReply     = 'guardian_can_reply';

// ── Privacy prefs keys ────────────────────────────────────────

const _kPhotoVisibility   = 'privacy_photo_visibility';
const _kShowOnlineStatus  = 'privacy_show_online';
const _kProfilePaused     = 'privacy_profile_paused';
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
  final _privacyKey  = GlobalKey();
  final _helpKey     = GlobalKey();
  final _accountKey  = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection());
    }
  }

  void _scrollToSection() {
    GlobalKey? key;
    switch (widget.initialSection) {
      case 'privacy':  key = _privacyKey;
      case 'help':     key = _helpKey;
      case 'account':  key = _accountKey;
    }
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(key!.currentContext!,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic);
    }
  }

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
        title: Text(AppLocalizations.of(context).settings_title,
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── 1. ACCOUNT ────────────────────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_account, key: _accountKey),
          _SettingsCard(children: [
            _NavTile(
              icon:  Icons.edit_outlined,
              label: 'Edit Profile',
              onTap: () => context.push('/edit-profile'),
            ),
            _Divider(),
            Builder(
              builder: (ctx) {
                final phone = ctx.read<OnboardingCubit>().currentData.phone;
                final masked = _maskPhone(phone);
                return _NavTile(
                  icon:  Icons.phone_outlined,
                  label: 'Phone Number',
                  value: masked,
                  onTap: () => _showInfoSnackbar(context, 'Phone number cannot be changed. Contact support for help.'),
                );
              },
            ),
            _Divider(),
            _NavTile(
              icon:  Icons.photo_library_outlined,
              label: 'Photo Privacy',
              value: 'After Acceptance',
              onTap: () => _showPhotoPrivacySheet(context),
            ),
          ]),

          // ── 2. NOTIFICATIONS ─────────────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_notifications),
          BlocBuilder<NotificationPrefsCubit, NotificationPrefsState>(
            builder: (context, prefs) => _SettingsCard(children: [
              _ToggleTile(
                icon:    Icons.favorite_outline_rounded,
                label:   'New Interests',
                value:   prefs.newInterest,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleNewInterest(v),
              ),
              _Divider(),
              _ToggleTile(
                icon:    Icons.check_circle_outline_rounded,
                label:   'Interest Accepted',
                value:   prefs.interestAccepted,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleInterestAccepted(v),
              ),
              _Divider(),
              _ToggleTile(
                icon:    Icons.chat_bubble_outline_rounded,
                label:   'New Messages',
                value:   prefs.newMessage,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleNewMessage(v),
              ),
              _Divider(),
              _ToggleTile(
                icon:    Icons.verified_outlined,
                label:   'Profile Approved',
                value:   prefs.profileApproved,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleProfileApproved(v),
              ),
              _Divider(),
              _ToggleTile(
                icon:    Icons.timer_outlined,
                label:   'Interest Expiring Soon',
                value:   prefs.interestExpiring,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleInterestExpiring(v),
              ),
              _Divider(),
              _ToggleTile(
                icon:    Icons.notifications_active_outlined,
                label:   'Activity Nudges',
                caption: 'Remind when inactive for 7+ days',
                value:   prefs.inactiveNudge,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleInactiveNudge(v),
              ),
              _Divider(),
              _ToggleTile(
                icon:    Icons.rocket_launch_outlined,
                label:   'Boost Reminders',
                caption: 'Remind when your weekly boost is ready',
                value:   prefs.boostAvailable,
                onChanged: (v) =>
                    context.read<NotificationPrefsCubit>().toggleBoostAvailable(v),
              ),
              _Divider(),
              _InfoTile(
                icon:  Icons.bedtime_outlined,
                label: 'Quiet Hours',
                value: '${_fmtHour(prefs.quietStartHour)} – ${_fmtHour(prefs.quietEndHour)}',
              ),
            ]),
          ),

          // ── 3. GUARDIAN (Feature 13) ──────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_guardian),
          const _GuardianSection(),

          // ── 4. PRIVACY (Feature 14) ───────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_privacy, key: _privacyKey),
          const _PrivacySection(),

          // ── 5. APP (Feature 16) ───────────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_app),
          _SettingsCard(children: [
            BlocBuilder<LocaleCubit, Locale>(
              builder: (context, locale) {
                final lang = _kLanguages
                    .firstWhere((l) => l.locale == locale.languageCode,
                        orElse: () => _kLanguages.first);
                return _NavTile(
                  icon:  Icons.language_rounded,
                  label: 'Language',
                  value: lang.englishName,
                  onTap: () => _showLanguageSheet(context, lang),
                );
              },
            ),
            _Divider(),
            _NavTile(
              icon:  Icons.star_outline_rounded,
              label: 'Rate NOOR',
              onTap: () => _showInfoSnackbar(context, 'Rating will be available once NOOR launches on the app store.'),
            ),
            _Divider(),
            const _InfoTile(
              icon:  Icons.info_outline_rounded,
              label: 'Version',
              value: '1.0.0 (build 1)',
            ),
          ]),

          // ── 6. SAFETY ─────────────────────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_safety),
          BlocBuilder<BlockReportCubit, BlockReportState>(
            builder: (context, brs) => _SettingsCard(children: [
           _NavTile(
                icon:  Icons.block_rounded,
                label: 'Blocked Profiles',
                value: brs.blockedUsers.isEmpty
                    ? 'None'
                    : '${brs.blockedUsers.length} blocked',
                onTap: () => context.push(AppRoutes.blockList),
              ),
              _Divider(),
              _NavTile(
                icon:  Icons.flag_outlined,
                label: 'Report History',
                value: brs.reportHistory.isEmpty
                    ? 'No reports submitted'
                    : '${brs.reportHistory.length} submitted',
                onTap: () => _showReportHistory(context, brs),
              ),
            ]),
          ),

          // ── 7. LEGAL ──────────────────────────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_legal, key: _helpKey),
          _SettingsCard(children: [
            _NavTile(
              icon:  Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LegalDocScreen(type: 'tos')),
              ),
            ),
            _Divider(),
            _NavTile(
              icon:  Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LegalDocScreen(type: 'privacy')),
              ),
            ),
          ]),

          // ── 8. DANGER ZONE (Feature 15) ──────────────────
          _SectionHeader(AppLocalizations.of(context).settings_section_dangerZone),
          _SettingsCard(
            borderColor: AppColors.softCoral.withValues(alpha: 0.3),
            children: [
              _NavTile(
                icon:      Icons.support_agent_rounded,
                label:     'Contact Support',
                iconColor: AppColors.slateMist,
                onTap:     () => _showSupportDialog(context),
              ),
              _Divider(),
               _NavTile(
                icon:       Icons.delete_forever_outlined,
                label:      AppLocalizations.of(context).settings_button_deleteAccount,
                iconColor:  AppColors.softCoral,
                labelColor: AppColors.softCoral,
                onTap: () => context.push(AppRoutes.deleteAccount),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'NOOR (نور) · For the sake of Allah',
              style: AppTypography.caption.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo privacy ──────────────────────────────────────────
  void _showPhotoPrivacySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SimplePickerSheet(
        title:   'Photo Privacy',
        options: const ['Public', 'After Acceptance'],
        initial: 'After Acceptance',
        onSelect: (_) {},
      ),
    );
  }

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
  static String _maskPhone(String? phone) {
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.support_agent_rounded,
                color: AppColors.champagneGold, size: 20),
            const SizedBox(width: 10),
            Text('Contact Support', style: AppTypography.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For any questions, concerns, or feedback:',
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
                      Text('support@noor.app',
                          style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.champagneGold)),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.space8),
                  Text(
                    'We aim to respond within 48 hours.',
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
            child: Text('Close',
                style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold)),
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
  bool   _enabled      = false;
  bool   _mirror       = false;
  bool   _canReply     = false;
  String _relationship = 'Father';
  final  _nameCtrl     = TextEditingController();
  final  _phoneCtrl    = TextEditingController();
  bool   _saved        = false;

  static const _relationships = ['Father', 'Mother', 'Brother', 'Uncle', 'Other'];

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
      _enabled      = prefs.getBool(_kGuardianEnabled) ?? false;
      _mirror       = prefs.getBool(_kGuardianMirror) ?? false;
      _canReply     = prefs.getBool(_kGuardianCanReply) ?? false;
      _relationship = prefs.getString(_kGuardianRelationship) ?? 'Father';
      _nameCtrl.text  = prefs.getString(_kGuardianName) ?? '';
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
      Future.delayed(const Duration(seconds: 2),
          () { if (mounted) setState(() => _saved = false); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(children: [
      // Guardian Mode master toggle
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: const Icon(Icons.supervisor_account_outlined,
            color: AppColors.champagneGold, size: 20),
        title: Text('Guardian Mode', style: AppTypography.body),
        subtitle: Text('Enable Wali oversight for messaging',
            style: AppTypography.caption),
        trailing: Switch(
          value:              _enabled,
          onChanged:          (v) => setState(() => _enabled = v),
          activeThumbColor:   AppColors.obsidianNight,
          activeTrackColor:   AppColors.champagneGold,
          inactiveThumbColor: AppColors.slateMist,
          inactiveTrackColor: AppColors.surfaceGlassHover,
        ),
      ),

      // Expandable guardian details
      AnimatedSize(
        duration: AppDimensions.durationReveal,
        curve:    Curves.easeOutCubic,
        child: _enabled
            ? Column(children: [
                const _DividerFull(),
                // Guardian name
                _TextFieldTile(
                  icon:        Icons.person_outline_rounded,
                  hint:        'Guardian Name',
                  controller:  _nameCtrl,
                ),
                const _DividerFull(),
                // Guardian phone
                _TextFieldTile(
                  icon:          Icons.phone_outlined,
                  hint:          'Guardian Phone',
                  controller:    _phoneCtrl,
                  keyboardType:  TextInputType.phone,
                ),
                const _DividerFull(),
                // Relationship dropdown
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.family_restroom_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text('Relationship', style: AppTypography.body),
                  trailing: DropdownButton<String>(
                    value:           _relationship,
                    dropdownColor:   const Color(0xFF1A1A25),
                    underline:       const SizedBox.shrink(),
                    style:           AppTypography.caption.copyWith(
                        color: AppColors.champagneGold),
                    icon: const Icon(Icons.expand_more_rounded,
                        color: AppColors.slateMist, size: 16),
                    items: _relationships.map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r, style: AppTypography.body),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _relationship = v);
                    },
                  ),
                ),
                const _DividerFull(),
                // Mirror messages toggle
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.content_copy_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text('Mirror Messages', style: AppTypography.body),
                  subtitle: Text('Send copies of all messages to guardian',
                      style: AppTypography.caption),
                  trailing: Switch(
                    value:              _mirror,
                    onChanged:          (v) => setState(() => _mirror = v),
                    activeThumbColor:   AppColors.obsidianNight,
                    activeTrackColor:   AppColors.champagneGold,
                    inactiveThumbColor: AppColors.slateMist,
                    inactiveTrackColor: AppColors.surfaceGlassHover,
                  ),
                ),
                const _DividerFull(),
                // Guardian can reply toggle
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: const Icon(Icons.reply_outlined,
                      color: AppColors.slateMist, size: 20),
                  title: Text('Allow Guardian to Reply', style: AppTypography.body),
                  subtitle: Text('Guardian may participate in conversations',
                      style: AppTypography.caption),
                  trailing: Switch(
                    value:              _canReply,
                    onChanged:          (v) => setState(() => _canReply = v),
                    activeThumbColor:   AppColors.obsidianNight,
                    activeTrackColor:   AppColors.champagneGold,
                    inactiveThumbColor: AppColors.slateMist,
                    inactiveTrackColor: AppColors.surfaceGlassHover,
                  ),
                ),
                const _DividerFull(),
                // Save button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width:  double.infinity,
                    height: AppDimensions.buttonHeightSmall,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.champagneGold,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
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
                                  Text('Saved',
                                      style: AppTypography.button),
                                ],
                              )
                            : Text('Save Guardian Settings',
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
  String _photoVisibility   = 'Everyone';
  bool   _showOnlineStatus  = true;
  bool   _profilePaused     = false;
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
    if (!mounted) return;
    setState(() {
      _photoVisibility   = prefs.getString(_kPhotoVisibility) ?? 'Everyone';
      _showOnlineStatus  = prefs.getBool(_kShowOnlineStatus) ?? true;
      _profilePaused     = prefs.getBool(_kProfilePaused) ?? false;
      _profileVisibility = prefs.getString(_kProfileVisibility) ?? 'All registered users';
    });
  }

  Future<void> _persist(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool)   { await prefs.setBool(key, value); }
    if (value is String) { await prefs.setString(key, value); }
    if (!mounted) return;
    setState(() => _savedIndicators[key] = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _savedIndicators[key] = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Photo Visibility ───────────────────────────────────
      _PrivacyCard(
        label:    'PHOTO VISIBILITY',
        subtitle: 'Who can see your photos',
        saved:    _savedIndicators[_kPhotoVisibility] ?? false,
        child: Column(children: [
          const SizedBox(height: 8),
          _RadioRow(
            label:     'Everyone',
            selected:  _photoVisibility == 'Everyone',
            onTap: () { setState(() => _photoVisibility = 'Everyone'); _persist(_kPhotoVisibility, 'Everyone'); },
          ),
          _RadioRow(
            label:     'Accepted interests only',
            selected:  _photoVisibility == 'Accepted interests only',
            onTap: () { setState(() => _photoVisibility = 'Accepted interests only'); _persist(_kPhotoVisibility, 'Accepted interests only'); },
          ),
        ]),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Online Status ──────────────────────────────────────
      _PrivacyCard(
        label:    'ONLINE STATUS',
        subtitle: 'Show when you were last active',
        saved:    _savedIndicators[_kShowOnlineStatus] ?? false,
        child: _PrivacyToggle(
          value:     _showOnlineStatus,
          onChanged: (v) { setState(() => _showOnlineStatus = v); _persist(_kShowOnlineStatus, v); },
        ),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Profile Pause ──────────────────────────────────────
      _PrivacyCard(
        label:    'PROFILE PAUSE',
        subtitle: 'Hide your profile from search',
        saved:    _savedIndicators[_kProfilePaused] ?? false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrivacyToggle(
              value:     _profilePaused,
              onChanged: (v) { setState(() => _profilePaused = v); _persist(_kProfilePaused, v); },
            ),
            if (_profilePaused) ...[
              const SizedBox(height: AppDimensions.space8),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space12),
                decoration: BoxDecoration(
                  color:        const Color(0x1AF6C344),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: const Color(0x4AF6C344)),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility_off_outlined,
                      color: Color(0xFFF6C344), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your profile is hidden. No one can find you.',
                      style: AppTypography.caption.copyWith(
                          color: const Color(0xFFF6C344)),
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
        label:    'WHO CAN SEE MY PROFILE',
        subtitle: 'Controls who can browse your profile',
        saved:    _savedIndicators[_kProfileVisibility] ?? false,
        child: Column(children: [
          const SizedBox(height: 8),
          _RadioRow(
            label:    'All registered users',
            selected: _profileVisibility == 'All registered users',
            onTap: () { setState(() => _profileVisibility = 'All registered users'); _persist(_kProfileVisibility, 'All registered users'); },
          ),
          _RadioRow(
            label:    'Subscribers only',
            selected: _profileVisibility == 'Subscribers only',
            onTap: () { setState(() => _profileVisibility = 'Subscribers only'); _persist(_kProfileVisibility, 'Subscribers only'); },
          ),
        ]),
      ),
      const SizedBox(height: AppDimensions.space8),

      // ── Download My Data (GDPR) ────────────────────────────
      _PrivacyCard(
        label:    'DOWNLOAD MY DATA',
        subtitle: 'Export a copy of your personal data under GDPR',
        saved:    false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.space12),
            Text(
              'Under GDPR and other privacy regulations, you can request a complete export of your '
              'profile, matching, and activity data. The file will be prepared and sent to your registered address.',
              style: AppTypography.caption.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppDimensions.space16),
            SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, color: AppColors.obsidianNight, size: 16),
                label: Text(
                  'Request Data Export',
                  style: AppTypography.button.copyWith(color: AppColors.obsidianNight),
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
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.download_done_rounded,
                color: AppColors.verifiedTeal, size: 20),
            const SizedBox(width: 10),
            Text('Export Requested', style: AppTypography.bodyMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your request has been received! We are compiling your personal data archive.',
              style: AppTypography.body.copyWith(height: 1.5),
            ),
            const SizedBox(height: AppDimensions.space16),
            Text(
              'A download link will be sent to your registered phone/email within 48 hours in compliance with GDPR guidelines.',
              style: AppTypography.caption.copyWith(height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Understood',
                style: AppTypography.caption.copyWith(
                    color: AppColors.champagneGold)),
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
  final bool   saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        border:       Border.all(color: AppColors.cardBorder),
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
                        Text('Saved',
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
  final bool             value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Switch(
        value:              value,
        onChanged:          onChanged,
        activeThumbColor:   AppColors.obsidianNight,
        activeTrackColor:   AppColors.champagneGold,
        inactiveThumbColor: AppColors.slateMist,
        inactiveTrackColor: AppColors.surfaceGlassHover,
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected, required this.onTap});
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:    onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space10),
        child: Row(children: [
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            width: 22, height: 22,
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
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Language',
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          ..._kLanguages.map((lang) {
            final isSelected = lang.locale == currentLocale;
            return GestureDetector(
              onTap: () async {
                await context.read<LocaleCubit>().setLocale(Locale(lang.locale));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Language updated to ${lang.englishName}',
                          style: AppTypography.body),
                      backgroundColor: AppColors.surfaceGlassHover,
                      behavior:        SnackBarBehavior.floating,
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
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: isSelected ? AppColors.goldGlow : AppColors.surfaceGlass,
                  border: Border.all(
                    color: isSelected ? AppColors.champagneGold : AppColors.cardBorder,
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
  final Color?       borderColor;
  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
      color:  AppColors.surfaceGlass,
      border: Border.all(color: borderColor ?? AppColors.cardBorder),
    ),
    child: Column(children: children),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
    color: AppColors.divider, height: 1, indent: 52, endIndent: 16,
  );
}

class _DividerFull extends StatelessWidget {
  const _DividerFull();
  @override
  Widget build(BuildContext context) =>
      const Divider(color: AppColors.divider, height: 1);
}

class _NavTile extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final String?    value;
  final VoidCallback onTap;
  final Color?     iconColor;
  final Color?     labelColor;

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
    title: Text(label, style: AppTypography.body.copyWith(color: labelColor)),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          Text(value!, style: AppTypography.caption.copyWith(
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
  final IconData   icon;
  final String     label;
  final String?    caption;
  final bool       value;
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
    leading:  Icon(icon, color: AppColors.slateMist, size: 20),
    title:    Text(label, style: AppTypography.body),
    subtitle: caption != null ? Text(caption!, style: AppTypography.caption) : null,
    trailing: Switch(
      value:              value,
      onChanged:          onChanged,
      activeThumbColor:   AppColors.obsidianNight,
      activeTrackColor:   AppColors.champagneGold,
      inactiveThumbColor: AppColors.slateMist,
      inactiveTrackColor: AppColors.surfaceGlassHover,
    ),
  );
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  value;

  const _InfoTile({required this.icon, required this.label, this.value});

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.slateMist, size: 20),
    title:   Text(label, style: AppTypography.body),
    trailing: value != null ? Text(value!, style: AppTypography.caption) : null,
  );
}

class _TextFieldTile extends StatelessWidget {
  const _TextFieldTile({
    required this.icon,
    required this.hint,
    required this.controller,
    this.keyboardType,
  });
  final IconData               icon;
  final String                 hint;
  final TextEditingController  controller;
  final TextInputType?         keyboardType;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, color: AppColors.slateMist, size: 20),
    title: TextField(
      controller:  controller,
      keyboardType: keyboardType,
      style:        AppTypography.body,
      decoration:   InputDecoration(
        hintText:       hint,
        hintStyle:      AppTypography.bodyMuted,
        border:         InputBorder.none,
        isDense:        true,
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
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Report History',
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Center(child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('No reports submitted', style: AppTypography.bodyMuted),
            ))
          else
            ...reports.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color:  AppColors.surfaceGlass,
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.flag_outlined,
                      color: AppColors.softCoral, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.reportedName, style: AppTypography.bodyMedium),
                      Text(r.reason.label, style: AppTypography.caption),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.surfaceGlassHover,
                    ),
                    child: Text('Pending',
                        style: AppTypography.caption.copyWith(fontSize: 10)),
                  ),
                ]),
              ),
            )),
        ],
      ),
    );
  }
}

// ── Simple Picker Sheet ───────────────────────────────────────

class _SimplePickerSheet extends StatefulWidget {
  final String              title;
  final List<String>        options;
  final String              initial;
  final ValueChanged<String> onSelect;

  const _SimplePickerSheet({
    required this.title,
    required this.options,
    required this.initial,
    required this.onSelect,
  });

  @override
  State<_SimplePickerSheet> createState() => _SimplePickerSheetState();
}

class _SimplePickerSheetState extends State<_SimplePickerSheet> {
  late String _selected;

  @override
  void initState() { super.initState(); _selected = widget.initial; }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF12121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(widget.title,
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          ...widget.options.map((opt) => GestureDetector(
            onTap: () {
              setState(() => _selected = opt);
              widget.onSelect(opt);
              Navigator.of(context).pop();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: _selected == opt ? AppColors.goldGlow : AppColors.surfaceGlass,
                border: Border.all(
                  color: _selected == opt
                      ? AppColors.champagneGold
                      : AppColors.cardBorder,
                  width: _selected == opt ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Expanded(child: Text(opt,
                    style: AppTypography.body.copyWith(
                      color: _selected == opt
                          ? AppColors.champagneGold
                          : AppColors.pearlWhite,
                    ))),
                if (_selected == opt)
                  const Icon(Icons.check_rounded,
                      color: AppColors.champagneGold, size: 18),
              ]),
            ),
          )),
        ],
      ),
    );
  }
}
