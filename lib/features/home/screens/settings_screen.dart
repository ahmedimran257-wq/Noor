// lib/features/home/screens/settings_screen.dart
// ============================================================
// NOOR — Settings Screen (Step 10)
//
// Blueprint (Part 8 — Settings):
//   Sections:
//   1. Account  — phone, profile pause, photo privacy
//   2. Notifications — per-category toggles (NotificationPrefsCubit)
//   3. Guardian — guardian phone, message mirror
//   4. Safety   — Block List (with unblock), Report History
//   5. App      — Language (8 options), version, rate app
//   6. Legal    — ToS, Privacy Policy
//   7. Danger Zone — Delete Account (30-day grace), Contact Support
//
// IMPORTANT (blueprint): When account is soft-deleted:
//   OneSignal.logout() MUST be called to prevent ghost notifications
//   on recycled telecom numbers.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_cubit.dart';
import '../../../core/cubits/notification_prefs/notification_prefs_state.dart';
import '../../../core/cubits/block_report/block_report_cubit.dart';
import '../../../core/cubits/block_report/block_report_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.pearlWhite, size: 20),
        ),
        title: Text('Settings', style: AppTypography.screenTitle.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // ── 1. ACCOUNT ────────────────────────────────────
          _SectionHeader('ACCOUNT'),
          _SettingsCard(children: [
            _NavTile(
              icon:  Icons.phone_outlined,
              label: 'Phone Number',
              value: '+91 •••• ••7890',
              onTap: () {},
            ),
            _Divider(),
            _ToggleTile(
              icon:    Icons.pause_circle_outline_rounded,
              label:   'Pause Profile',
              caption: 'Hide your profile from discovery',
              value:   false,
              onChanged: (v) {},
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
          _SectionHeader('NOTIFICATIONS'),
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

          // ── 3. GUARDIAN ───────────────────────────────────
          _SectionHeader('GUARDIAN'),
          _SettingsCard(children: [
            _NavTile(
              icon:  Icons.supervisor_account_outlined,
              label: 'Guardian Phone',
              value: 'Not set',
              onTap: () {},
            ),
            _Divider(),
            _ToggleTile(
              icon:    Icons.content_copy_outlined,
              label:   'Message Mirror',
              caption: 'Send copies of all messages to guardian',
              value:   false,
              onChanged: (v) {},
            ),
          ]),

          // ── 4. SAFETY ─────────────────────────────────────
          _SectionHeader('SAFETY'),
          BlocBuilder<BlockReportCubit, BlockReportState>(
            builder: (context, brs) => _SettingsCard(children: [
              _NavTile(
                icon:  Icons.block_rounded,
                label: 'Block List',
                value: brs.blockedUsers.isEmpty
                    ? 'No blocked users'
                    : '${brs.blockedUsers.length} blocked',
                onTap: () => _showBlockList(context, brs),
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

          // ── 5. APP ────────────────────────────────────────
          _SectionHeader('APP'),
          _SettingsCard(children: [
            _NavTile(
              icon:  Icons.language_rounded,
              label: 'Language',
              value: 'English',
              onTap: () => _showLanguageSheet(context),
            ),
            _Divider(),
            _NavTile(
              icon:  Icons.star_outline_rounded,
              label: 'Rate NOOR',
              onTap: () {},
            ),
            _Divider(),
            _InfoTile(
              icon:  Icons.info_outline_rounded,
              label: 'Version',
              value: '1.0.0 (build 1)',
            ),
          ]),

          // ── 6. LEGAL ──────────────────────────────────────
          _SectionHeader('LEGAL'),
          _SettingsCard(children: [
            _NavTile(
              icon:  Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () {},
            ),
            _Divider(),
            _NavTile(
              icon:  Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () {},
            ),
          ]),

          // ── 7. DANGER ZONE ────────────────────────────────
          _SectionHeader('DANGER ZONE'),
          _SettingsCard(
            borderColor: AppColors.softCoral.withValues(alpha: 0.3),
            children: [
              _NavTile(
                icon:      Icons.support_agent_rounded,
                label:     'Contact Support',
                iconColor: AppColors.slateMist,
                onTap:     () {},
              ),
              _Divider(),
              _NavTile(
                icon:      Icons.delete_forever_outlined,
                label:     'Delete Account',
                iconColor: AppColors.softCoral,
                labelColor: AppColors.softCoral,
                onTap:     () => _showDeleteConfirm(context),
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

  // ── Photo privacy sheet ───────────────────────────────────

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

  // ── Language sheet ────────────────────────────────────────

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SimplePickerSheet(
        title:   'Language',
        options: const [
          'English', 'العربية', 'اردو',
          'Bahasa Indonesia', 'Bahasa Melayu',
          'Türkçe', 'Deutsch', 'Français',
        ],
        initial: 'English',
        onSelect: (_) {},
      ),
    );
  }

  // ── Block list sheet ──────────────────────────────────────

  void _showBlockList(BuildContext context, BlockReportState state) {
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<BlockReportCubit>(),
        child: _BlockListSheet(blocked: state.blockedUsers),
      ),
    );
  }

  // ── Report history sheet ──────────────────────────────────

  void _showReportHistory(BuildContext context, BlockReportState state) {
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _ReportHistorySheet(reports: state.reportHistory),
    );
  }

  // ── Delete account confirm ────────────────────────────────

  void _showDeleteConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF12121A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Account?',
            style: AppTypography.screenTitle.copyWith(fontSize: 20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your account will enter a 30-day grace period before permanent deletion. During this time you can reactivate by signing in.',
              style: AppTypography.bodyMuted,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: AppColors.softCoral.withValues(alpha: 0.10),
                border: Border.all(
                    color: AppColors.softCoral.withValues(alpha: 0.3)),
              ),
              child: Text(
                'All your matches, messages, and profile data will be permanently deleted after 30 days.',
                style: AppTypography.caption.copyWith(
                    color: AppColors.softCoral.withValues(alpha: 0.9)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: AppTypography.body),
          ),
          TextButton(
            onPressed: () {
              // Blueprint: MUST call OneSignal.logout() here
              // to prevent ghost pushes on recycled numbers.
              // Step 12: OneSignal.logout() + supabase signOut
              Navigator.of(context).pop(); // close dialog
              context.read<AuthCubit>().signOut();
            },
            child: Text('Delete Account',
                style: AppTypography.body
                    .copyWith(color: AppColors.softCoral)),
          ),
        ],
      ),
    );
  }

  static String _fmtHour(int h) =>
      '${h.toString().padLeft(2, '0')}:00';
}

// ── Section Header ────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 0, 8),
      child: Text(label, style: AppTypography.sectionLabel),
    );
  }
}

// ── Settings Card Container ───────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final Color?       borderColor;

  const _SettingsCard({required this.children, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        color:  AppColors.surfaceGlass,
        border: Border.all(color: borderColor ?? AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
        color: AppColors.divider, height: 1,
        indent: 52, endIndent: 16,
      );
}

// ── Tile Types ────────────────────────────────────────────────

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
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: iconColor ?? AppColors.slateMist, size: 20),
      title: Text(label,
          style: AppTypography.body.copyWith(color: labelColor)),
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
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading:  Icon(icon, color: AppColors.slateMist, size: 20),
      title:    Text(label, style: AppTypography.body),
      subtitle: caption != null
          ? Text(caption!, style: AppTypography.caption)
          : null,
      trailing: Switch(
        value:              value,
        onChanged:          onChanged,
        activeThumbColor:    AppColors.obsidianNight,
        activeTrackColor:    AppColors.champagneGold,
        inactiveThumbColor: AppColors.slateMist,
        inactiveTrackColor: AppColors.surfaceGlassHover,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String?  value;

  const _InfoTile({
    required this.icon,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppColors.slateMist, size: 20),
      title:   Text(label, style: AppTypography.body),
      trailing: value != null
          ? Text(value!, style: AppTypography.caption)
          : null,
    );
  }
}

// ── Block List Sheet ──────────────────────────────────────────

class _BlockListSheet extends StatelessWidget {
  final List<BlockedUser> blocked;
  const _BlockListSheet({required this.blocked});

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
          Text('Blocked Users',
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          if (blocked.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No blocked users',
                    style: AppTypography.bodyMuted),
              ),
            )
          else
            ...blocked.map((b) => _BlockedUserTile(user: b)),
        ],
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final BlockedUser user;
  const _BlockedUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppColors.surfaceGlass,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceGlassHover),
              child: const Icon(Icons.person_outline_rounded,
                  color: AppColors.slateMist, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${user.name} ${user.lastInitial}.',
                      style: AppTypography.bodyMedium),
                  Text('Blocked ${_timeAgo(user.blockedAt)}',
                      style: AppTypography.caption),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context
                  .read<BlockReportCubit>()
                  .unblockUser(user.userId),
              child: Text('Unblock',
                  style: AppTypography.caption.copyWith(
                      color: AppColors.champagneGold,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
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
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Report History',
              style: AppTypography.screenTitle.copyWith(fontSize: 20)),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('No reports submitted',
                    style: AppTypography.bodyMuted),
              ),
            )
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
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined,
                            color: AppColors.softCoral, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.reportedName,
                                  style: AppTypography.bodyMedium),
                              Text(r.reason.label,
                                  style: AppTypography.caption),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color: AppColors.surfaceGlassHover,
                          ),
                          child: Text('Pending',
                              style: AppTypography.caption
                                  .copyWith(fontSize: 10)),
                        ),
                      ],
                    ),
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
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: _selected == opt
                        ? AppColors.goldGlow
                        : AppColors.surfaceGlass,
                    border: Border.all(
                      color: _selected == opt
                          ? AppColors.champagneGold
                          : AppColors.cardBorder,
                      width: _selected == opt ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(opt,
                            style: AppTypography.body.copyWith(
                              color: _selected == opt
                                  ? AppColors.champagneGold
                                  : AppColors.pearlWhite,
                            )),
                      ),
                      if (_selected == opt)
                        const Icon(Icons.check_rounded,
                            color: AppColors.champagneGold, size: 18),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
