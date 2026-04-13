// lib/features/home/screens/my_profile_screen.dart
// ============================================================
// NOOR — My Profile Screen
// Self-view of the user's own profile with settings.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space24,
              AppDimensions.space16,
              AppDimensions.space24,
              0,
            ),
            child: Row(
              children: [
                Text('My Profile', style: AppTypography.screenTitle),
                const Spacer(),
                // Settings icon
                Container(
                  width:  AppDimensions.minTouchTarget,
                  height: AppDimensions.minTouchTarget,
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border:       Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.slateMist,
                    size:  AppDimensions.iconSizeLarge,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.space28),

          // Profile card preview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
            child: _ProfilePreviewCard(),
          ),

          const SizedBox(height: AppDimensions.space28),

          // Edit profile button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
            child: SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.champagneGold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.champagneGold,
                  size:  AppDimensions.iconSizeMedium,
                ),
                label: Text(
                  'Edit Profile',
                  style: AppTypography.buttonSecondary,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Profile editing will be available in Step 6.',
                        style: AppTypography.body,
                      ),
                      backgroundColor: AppColors.surfaceGlassHover,
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space32),

          // Settings sections
          _SettingsSection(
            title: 'Privacy',
            items: [
              _SettingsItem(
                icon:     Icons.visibility_outlined,
                label:    'Profile Visibility',
                trailing: 'Public',
              ),
              _SettingsItem(
                icon:     Icons.photo_library_outlined,
                label:    'Photo Privacy',
                trailing: 'After Acceptance',
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.space16),

          _SettingsSection(
            title: 'Notifications',
            items: [
              _SettingsItem(
                icon:    Icons.notifications_outlined,
                label:   'New Interests',
                isToggle: true,
                isOn:    true,
              ),
              _SettingsItem(
                icon:    Icons.chat_bubble_outline_rounded,
                label:   'New Messages',
                isToggle: true,
                isOn:    true,
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.space16),

          _SettingsSection(
            title: 'Account',
            items: [
              _SettingsItem(
                icon:  Icons.help_outline_rounded,
                label: 'Help & Support',
              ),
              _SettingsItem(
                icon:  Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
              ),
            ],
          ),

          const SizedBox(height: AppDimensions.space16),

          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
            child: SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeight,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side:  const BorderSide(color: AppColors.softCoral),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.softCoral,
                  size:  AppDimensions.iconSizeMedium,
                ),
                label: Text(
                  'Sign Out',
                  style: AppTypography.buttonSecondary.copyWith(
                    color: AppColors.softCoral,
                  ),
                ),
                onPressed: () => context.read<AuthCubit>().signOut(),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space40),
        ],
      ),
    );
  }
}

// ── Profile Preview Card ──────────────────────────────────────

class _ProfilePreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.goldBorder),
        boxShadow: [
          BoxShadow(
            color:       AppColors.goldGlow,
            blurRadius:  20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width:  72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:  AppColors.surfaceGlassHover,
              border: Border.all(color: AppColors.goldBorder, width: 2),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.slateMist,
              size:  36,
            ),
          ),
          const SizedBox(width: AppDimensions.space16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your Name', style: AppTypography.userName.copyWith(fontSize: 20)),
                const SizedBox(height: AppDimensions.space4),
                Text('Add your city · Add your age',
                    style: AppTypography.caption),
                const SizedBox(height: AppDimensions.space8),
                // Profile completeness bar
                _CompletenessBar(percentage: 0.72),
                const SizedBox(height: AppDimensions.space4),
                Text('72% complete', style: AppTypography.caption.copyWith(
                  color: AppColors.champagneGold,
                  fontSize: 11,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletenessBar extends StatelessWidget {
  const _CompletenessBar({required this.percentage});
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 4,
          width:  constraints.maxWidth,
          decoration: BoxDecoration(
            color:        AppColors.progressBarBase,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color:        AppColors.champagneGold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Settings Section ──────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.items});
  final String             title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: AppTypography.sectionLabel),
          const SizedBox(height: AppDimensions.space10),
          Container(
            decoration: BoxDecoration(
              color:        AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border:       Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final item = e.value;
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    _SettingsTile(item: item),
                    if (!isLast)
                      const Divider(
                        color:  AppColors.divider,
                        height: 1,
                        indent: AppDimensions.space16,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem {
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.isToggle = false,
    this.isOn     = false,
  });
  final IconData icon;
  final String   label;
  final String?  trailing;
  final bool     isToggle;
  final bool     isOn;
}

class _SettingsTile extends StatefulWidget {
  const _SettingsTile({required this.item});
  final _SettingsItem item;

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  late bool _isOn;

  @override
  void initState() {
    super.initState();
    _isOn = widget.item.isOn;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16,
        vertical:   AppDimensions.space4,
      ),
      leading: Icon(
        widget.item.icon,
        color: AppColors.slateMist,
        size:  AppDimensions.iconSizeMedium,
      ),
      title: Text(widget.item.label, style: AppTypography.body),
      trailing: widget.item.isToggle
          ? Switch(
              value:            _isOn,
              onChanged:        (v) => setState(() => _isOn = v),
              activeColor:      AppColors.champagneGold,
              inactiveThumbColor: AppColors.slateMist,
              inactiveTrackColor: AppColors.surfaceGlassHover,
            )
          : widget.item.trailing != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.item.trailing!, style: AppTypography.caption),
                    const SizedBox(width: AppDimensions.space4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.slateMist,
                      size:  AppDimensions.iconSizeMedium,
                    ),
                  ],
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.slateMist,
                  size:  AppDimensions.iconSizeMedium,
                ),
    );
  }
}
