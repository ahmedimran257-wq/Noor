// lib/features/home/screens/my_profile_screen.dart
// ============================================================
// NOOR — My Profile Screen
// Self-view: completeness bar, boost section, profile views
// row, saved profiles, settings sections, sign out.
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/cubits/subscription/subscription_state.dart';
import '../../../core/cubits/notifications/notifications_cubit.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/noor_empty_state.dart';
import 'edit_profile_screen.dart';
import 'delete_account_screen.dart';
import 'legal_doc_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'profile_views_screen.dart';
import 'notifications_screen.dart';

// ── Completeness score ────────────────────────────────────────

({int score, String? nudge}) _calcCompleteness(OnboardingData d) {
  int score = 0;
  final hasPrimaryPhoto = d.photoLocalPaths != null && d.photoLocalPaths!.isNotEmpty;
  if (hasPrimaryPhoto) score += 25;
  final hasBio = (d.bio?.length ?? 0) >= 50;
  if (hasBio) score += 15;
  final hasIslamic = d.sect != null && d.deenLevel != null;
  if (hasIslamic) score += 15;
  final hasEduPro = (d.educationLabel != null || d.educationRank != null) &&
      (d.profession?.isNotEmpty ?? false);
  if (hasEduPro) score += 10;
  final hasFamily = d.familyType != null;
  if (hasFamily) score += 10;
  final hasPartnerPrefs = d.preferredAgeMin != null && d.preferredAgeMax != null;
  if (hasPartnerPrefs) score += 10;
  final hasSecondPhoto = d.photoLocalPaths != null && d.photoLocalPaths!.length >= 2;
  if (hasSecondPhoto) score += 8;
  final hasIncome = d.incomeBracketId != null;
  if (hasIncome) score += 4;
  final hasLangs = d.languages != null && d.languages!.isNotEmpty;
  if (hasLangs) score += 3;

  String? nudge;
  if (!hasPrimaryPhoto)      { nudge = 'Add a profile photo to reach ${score + 25}%'; }
  else if (!hasBio)          { nudge = 'Add a bio to reach ${score + 15}%'; }
  else if (!hasIslamic)      { nudge = 'Complete Islamic identity to reach ${score + 15}%'; }
  else if (!hasEduPro)       { nudge = 'Add education & profession to reach ${score + 10}%'; }
  else if (!hasFamily)       { nudge = 'Add family background to reach ${score + 10}%'; }
  else if (!hasPartnerPrefs) { nudge = 'Set partner preferences to reach ${score + 10}%'; }
  else if (!hasSecondPhoto)  { nudge = 'Add a second photo to reach ${score + 8}%'; }
  else if (!hasIncome)       { nudge = 'Add income range to reach ${score + 4}%'; }
  else if (!hasLangs)        { nudge = 'Add languages to reach ${score + 3}%'; }

  return (score: score.clamp(0, 100), nudge: nudge);
}

// ── Screen ────────────────────────────────────────────────────

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  Set<String> _bookmarked = {};
  bool _guardianEnabled = false;

  // Mock views count
  static const _viewCount = 10;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    _loadGuardian();
  }

  Future<void> _loadBookmarks() async {
    final ids = await BookmarkService.load();
    if (mounted) setState(() => _bookmarked = ids);
  }

  Future<void> _loadGuardian() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() =>
          _guardianEnabled = prefs.getBool('guardian_enabled') ?? false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // ── Header row ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(
              children: [
                Text('My Profile', style: AppTypography.screenTitle),
                const Spacer(),
                // Notification bell (from Feature 11)
                BlocBuilder<NotificationsCubit, NotificationsState>(
                  builder: (context, ns) {
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: AppDimensions.minTouchTarget,
                            height: AppDimensions.minTouchTarget,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceGlass,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              color: AppColors.slateMist,
                              size: AppDimensions.iconSizeLarge,
                            ),
                          ),
                          if (ns.unreadCount > 0)
                            Positioned(
                              top: 6, right: 6,
                              child: Container(
                                width:  8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.champagneGold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppDimensions.space8),
                // Settings
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen()),
                  ),
                  child: Container(
                    width: AppDimensions.minTouchTarget,
                    height: AppDimensions.minTouchTarget,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: const Icon(
                      Icons.settings_outlined,
                      color: AppColors.slateMist,
                      size: AppDimensions.iconSizeLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppDimensions.space28),

          // Profile card preview (live completeness)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<OnboardingCubit, OnboardingState>(
              builder: (context, _) {
                final data   = context.read<OnboardingCubit>().currentData;
                final result = _calcCompleteness(data);
                return _ProfilePreviewCard(
                  score: result.score,
                  nudge: result.nudge,
                  data:  data,
                  guardianEnabled: _guardianEnabled,
                );
              },
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Profile Views row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ProfileViewsScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space16),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space8),
                      decoration: BoxDecoration(
                        color:  AppColors.champagneGold.withValues(alpha: 0.12),
                        shape:  BoxShape.circle,
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: const Icon(
                        Icons.remove_red_eye_outlined,
                        color: AppColors.champagneGold,
                        size:  AppDimensions.iconSizeMedium,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Profile Views', style: AppTypography.bodyMedium),
                          Text('This week', style: AppTypography.caption),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color:        AppColors.champagneGold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$_viewCount',
                        style: AppTypography.captionMedium.copyWith(
                            color: AppColors.obsidianNight),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space8),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.slateMist,
                        size: AppDimensions.iconSizeMedium),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Subscription card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SubscriptionCard(),
          ),

          const SizedBox(height: AppDimensions.space16),

          // ── Boost Section ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _BoostSection(),
          ),

          const SizedBox(height: AppDimensions.space16),

          // Edit profile button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.champagneGold,
                    size:  AppDimensions.iconSizeMedium),
                label: Text('Edit Profile', style: AppTypography.buttonSecondary),
                onPressed: () => Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: AppDimensions.durationReveal,
                    pageBuilder: (context, animation, _) => FadeTransition(
                      opacity: animation,
                      child: const EditProfileScreen(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.space28),

          // Saved profiles section — always shown (empty state if none)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SavedProfilesSection(bookmarked: _bookmarked),
          ),
          const SizedBox(height: AppDimensions.space20),

          // Settings sections
          _SettingsSection(
            title: 'Privacy',
            items: [
              _SettingsItem(
                icon:     Icons.visibility_outlined,
                label:    'Profile Visibility',
                trailing: 'Public',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(initialSection: 'privacy'),
                  ),
                ),
              ),
              _SettingsItem(
                icon:     Icons.photo_library_outlined,
                label:    'Photo Privacy',
                trailing: 'After Acceptance',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(initialSection: 'privacy'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),
          _SettingsSection(
            title: 'Notifications',
            items: [
              _SettingsItem(
                icon: Icons.notifications_outlined,
                label: 'New Interests',
                isToggle: true, isOn: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
              ),
              _SettingsItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'New Messages',
                isToggle: true, isOn: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                ),
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(initialSection: 'help'),
                  ),
                ),
              ),
              _SettingsItem(
                icon:  Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const LegalDocScreen(type: 'privacy'),
                  ),
                ),
              ),
              _SettingsItem(
                icon:  Icons.delete_outline_rounded,
                label: 'Delete Account',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DeleteAccountScreen(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),

          // D4: "I Found My Match" — graceful profile deactivation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _IFoundMyMatchButton(),
          ),
          const SizedBox(height: AppDimensions.space16),

          // Sign out
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.softCoral,
                    size:  AppDimensions.iconSizeMedium),
                label: Text('Sign Out',
                    style: AppTypography.buttonSecondary.copyWith(
                        color: AppColors.softCoral)),
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

// ── Boost Section (Feature 12) ────────────────────────────────

class _BoostSection extends StatefulWidget {
  @override
  State<_BoostSection> createState() => _BoostSectionState();
}

class _BoostSectionState extends State<_BoostSection> {
  DateTime? _boostedAt;
  Timer?    _timer;

  @override
  void initState() {
    super.initState();
    _loadBoostState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadBoostState() async {
    final prefs = await SharedPreferences.getInstance();
    final ms    = prefs.getInt('boost_activated_at');
    if (ms != null) {
      final at = DateTime.fromMillisecondsSinceEpoch(ms);
      if (DateTime.now().difference(at) < const Duration(hours: 2)) {
        if (mounted) {
          setState(() => _boostedAt = at);
          _startTimer();
        }
      } else {
        prefs.remove('boost_activated_at');
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_boostedAt == null) return;
      final remaining = const Duration(hours: 2) -
          DateTime.now().difference(_boostedAt!);
      if (remaining.isNegative) {
        setState(() => _boostedAt = null);
        _timer?.cancel();
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _activate() async {
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();
    await prefs.setInt('boost_activated_at', now.millisecondsSinceEpoch);
    if (mounted) {
      setState(() => _boostedAt = now);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.rocket_launch_rounded,
                color: AppColors.champagneGold, size: 16),
            const SizedBox(width: 8),
            Text('Your profile is boosted for 2 hours!',
                style: AppTypography.body),
          ]),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _countdown() {
    if (_boostedAt == null) return '';
    final remaining = const Duration(hours: 2) -
        DateTime.now().difference(_boostedAt!);
    if (remaining.isNegative) return '00:00:00';
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Blueprint: Women always free. Never show subscription
    // messaging to female users.
    final authState = context.watch<AuthCubit>().state;
    final gender = authState is AuthAuthenticated
        ? (authState.gender ?? 'male')
        : 'male';
    final isFemale = gender == 'female';

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, subState) {
        final isActive = _boostedAt != null;

        // Women: always show boost as available (free, no paywall).
        // Men with no subscription: show locked state.
        final showAsSubscribed = isFemale || subState.isSubscribed;

        return AnimatedContainer(
          duration: AppDimensions.durationTransition,
          padding: const EdgeInsets.all(AppDimensions.space16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            gradient: showAsSubscribed
                ? LinearGradient(
                    colors: [
                      AppColors.champagneGold.withValues(alpha: 0.18),
                      AppColors.champagneGold.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end:   Alignment.bottomRight,
                  )
                : null,
            color: showAsSubscribed ? null : AppColors.surfaceGlass,
            border: Border.all(
              color: showAsSubscribed ? AppColors.goldBorder : AppColors.cardBorder,
            ),
          ),
          child: showAsSubscribed
              ? _BoostActiveOrAvailable(
                  isActive:  isActive,
                  countdown: _countdown(),
                  onActivate: _activate,
                )
              : _BoostLocked(
                  onNavigate: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const SubscriptionScreen()),
                  ),
                ),
        );
      },
    );
  }
}

class _BoostActiveOrAvailable extends StatelessWidget {
  const _BoostActiveOrAvailable({
    required this.isActive,
    required this.countdown,
    required this.onActivate,
  });
  final bool         isActive;
  final String       countdown;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rocket_launch_rounded,
                color: AppColors.champagneGold, size: 22),
            const SizedBox(width: AppDimensions.space8),
            Text('Boost Profile', style: AppTypography.bodyMedium.copyWith(
                color: AppColors.champagneGold)),
            const Spacer(),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Text('ACTIVE',
                    style: AppTypography.caption.copyWith(
                      color:      AppColors.champagneGold,
                      fontSize:   9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    )),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.space8),
        Text(
          isActive
              ? 'Your profile is at the top of searches.'
              : 'Appear at the top of searches for 2 hours.',
          style: AppTypography.caption,
        ),
        const SizedBox(height: AppDimensions.space12),
        SizedBox(
          width:  double.infinity,
          height: AppDimensions.buttonHeightSmall,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive
                  ? AppColors.surfaceGlassHover
                  : AppColors.champagneGold,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              ),
            ),
            onPressed: isActive ? null : onActivate,
            child: Text(
              isActive ? countdown : 'Activate Boost',
              style: AppTypography.button.copyWith(
                color: isActive ? AppColors.slateMist : AppColors.obsidianNight,
                fontVariations: const [FontVariation('wght', 700)],
                letterSpacing:  isActive ? 2 : 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BoostLocked extends StatelessWidget {
  const _BoostLocked({required this.onNavigate});
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onNavigate,
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.slateMist, size: 22),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile Boost', style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.slateMist)),
                const SizedBox(height: AppDimensions.space4),
                Text('Subscribe to unlock weekly profile boost.',
                    style: AppTypography.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.slateMist, size: AppDimensions.iconSizeMedium),
        ],
      ),
    );
  }
}

// ── Subscription Card ─────────────────────────────────────────

class _SubscriptionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    final gender = authState is AuthAuthenticated
        ? (authState.gender ?? 'male')
        : 'male';
    if (gender == 'female') return const SizedBox.shrink();

    return BlocBuilder<SubscriptionCubit, SubscriptionState>(
      builder: (context, state) {
        return switch (state.status) {
          SubscriptionStatus.active => _buildActive(context, state),
          SubscriptionStatus.grace  => _buildGrace(context),
          SubscriptionStatus.none   => _buildUpgrade(context),
        };
      },
    );
  }

  Widget _buildActive(BuildContext context, SubscriptionState state) {
    final expiry = state.expiresAt;
    return _CardShell(
      borderColor: AppColors.verifiedTeal,
      glowColor:   AppColors.verifiedTeal.withValues(alpha: 0.1),
      child: Row(children: [
        const Icon(Icons.workspace_premium_rounded,
            color: AppColors.verifiedTeal, size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NOOR Premium · Active',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.verifiedTeal)),
            if (expiry != null)
              Text('Renews ${_fmtDate(expiry)}',
                  style: AppTypography.caption),
          ],
        )),
      ]),
    );
  }

  Widget _buildGrace(BuildContext context) {
    return _CardShell(
      borderColor: const Color(0xFFF6C344),
      glowColor:   const Color(0x1AF6C344),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: Color(0xFFF6C344), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Text('Payment issue — subscription in grace period.',
            style: AppTypography.caption)),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
                builder: (_) => const SubscriptionScreen())),
          child: Text('Fix', style: AppTypography.captionMedium
              .copyWith(color: const Color(0xFFF6C344))),
        ),
      ]),
    );
  }

  Widget _buildUpgrade(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
            builder: (_) => const SubscriptionScreen())),
      child: _CardShell(
        borderColor: AppColors.goldBorder,
        glowColor:   AppColors.goldGlow,
        child: Row(children: [
          const Icon(Icons.lock_outline_rounded,
              color: AppColors.champagneGold, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upgrade to NOOR Premium',
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold)),
              Text('Unlock messaging from ₹249/mo',
                  style: AppTypography.caption),
            ],
          )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:        AppColors.champagneGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Plans', style: AppTypography.caption.copyWith(
              color: AppColors.obsidianNight, fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }

  String _fmtDate(DateTime dt) =>
      '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, required this.borderColor, required this.glowColor});
  final Widget child;
  final Color  borderColor;
  final Color  glowColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        color: AppColors.surfaceGlass,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: glowColor, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: child,
    );
  }
}

// ── Profile Preview Card ──────────────────────────────────────

class _ProfilePreviewCard extends StatelessWidget {
  const _ProfilePreviewCard({
    required this.score,
    required this.nudge,
    required this.data,
    required this.guardianEnabled,
  });
  final int          score;
  final String?      nudge;
  final OnboardingData data;
  final bool         guardianEnabled;

  @override
  Widget build(BuildContext context) {
    final pct = score / 100.0;
    // Derive display name from real OnboardingData fields
    final displayName = [data.firstName, data.lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    // Compute age from dateOfBirth
    final dob = data.dateOfBirth;
    int? age;
    if (dob != null) {
      final now = DateTime.now();
      age = now.year - dob.year;
      if (now.month < dob.month ||
          (now.month == dob.month && now.day < dob.day)) { age--; }
    }
    return Container(
      padding: const EdgeInsets.all(AppDimensions.space20),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.goldBorder),
        boxShadow: [BoxShadow(color: AppColors.goldGlow, blurRadius: 20)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceGlassHover,
                  border: Border.all(color: AppColors.goldBorder, width: 2),
                ),
                child: const Icon(Icons.person_outline_rounded,
                    color: AppColors.slateMist, size: 36),
              ),
              const SizedBox(width: AppDimensions.space16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      displayName.isEmpty ? 'Your Name' : displayName,
                      style: AppTypography.userName.copyWith(fontSize: 20),
                    ),
                    if (guardianEnabled) ...[
                      const SizedBox(width: AppDimensions.space8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        AppColors.champagneGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.goldBorder),
                        ),
                        child: Text('Guardian Mode',
                            style: AppTypography.caption.copyWith(
                              color:    AppColors.champagneGold,
                              fontSize: 10,
                            )),
                      ),
                    ],
                  ]),
                  const SizedBox(height: AppDimensions.space4),
                  Text(_buildSubtitle(age), style: AppTypography.caption),
                ],
              )),
            ],
          ),
          const SizedBox(height: AppDimensions.space16),

          LayoutBuilder(builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('$score% complete',
                      style: AppTypography.captionMedium.copyWith(
                          color: AppColors.champagneGold)),
                  const Spacer(),
                  Text(score >= 80 ? '✓ Great profile!' : 'Keep going!',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold)),
                ]),
                const SizedBox(height: AppDimensions.space8),
                Container(
                  height: 6,
                  width: constraints.maxWidth,
                  decoration: BoxDecoration(
                    color:        AppColors.progressBarBase,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve:    Curves.easeOutCubic,
                    width:    constraints.maxWidth * pct,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.champagneGold,
                        AppColors.champagneGold.withValues(alpha: 0.7),
                      ]),
                      borderRadius: BorderRadius.circular(3),
                      boxShadow: [
                        BoxShadow(
                          color:      AppColors.champagneGold.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                if (nudge != null) ...[
                  const SizedBox(height: AppDimensions.space8),
                  Row(children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.champagneGold, size: 13),
                    const SizedBox(width: 4),
                    Expanded(child: Text(nudge!,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.champagneGold, fontSize: 11))),
                  ]),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  String _buildSubtitle(int? age) {
    final parts = <String>[];
    if (age != null) parts.add('$age yrs');
    if (data.cityName?.isNotEmpty == true) parts.add(data.cityName!);
    return parts.isEmpty ? 'Complete your profile below' : parts.join(' · ');
  }
}

// ── Saved Profiles ────────────────────────────────────────────

class _SavedProfilesSection extends StatelessWidget {
  const _SavedProfilesSection({required this.bookmarked});
  final Set<String> bookmarked;

  @override
  Widget build(BuildContext context) {
    final saved = kMockProfiles.where((p) => bookmarked.contains(p.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SAVED PROFILES', style: AppTypography.sectionLabel),
        const SizedBox(height: AppDimensions.space12),
        if (saved.isEmpty)
          NoorEmptyState(
            icon:     Icons.bookmark_border_rounded,
            title:    'No saved profiles yet',
            subtitle: 'Tap the bookmark icon on any\nprofile to save it here.',
          )
        else
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount:       saved.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.space12),
              itemBuilder: (context, i) {
                final p = saved[i];
                return GestureDetector(
                  onTap: () {
                    // Navigate to profile detail — reuse Navigator push
                    // (go_router not wired for arbitrary profile IDs)
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SizedBox.shrink(),
                      ),
                    );
                  },
                  child: Container(
                    width: 90,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceGlass,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      border:       Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Avatar circle — 52 px
                        Container(
                          width:  52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceGlassHover,
                            border: Border.all(
                                color: AppColors.goldBorder, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            color: AppColors.slateMist,
                            size:  24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Name
                        Text(
                          p.firstName,
                          style: AppTypography.caption.copyWith(
                            color:      AppColors.pearlWhite,
                            fontWeight: FontWeight.w600,
                            fontSize:   12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        // City
                        Text(
                          p.cityName,
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Settings sections (recycled from before) ──────────────────

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.items});
  final String              title;
  final List<_SettingsItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
            child: Column(children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(children: [
                _SettingsTile(item: e.value),
                if (!isLast)
                  const Divider(color: AppColors.divider, height: 1, indent: 16),
              ]);
            }).toList()),
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
    this.onTap,
  });
  final IconData icon;
  final String   label;
  final String?  trailing;
  final bool     isToggle;
  final bool     isOn;
  final VoidCallback? onTap;
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
  void initState() { super.initState(); _isOn = widget.item.isOn; }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: widget.item.onTap != null
          ? () {
              HapticFeedback.selectionClick();
              widget.item.onTap!();
            }
          : null,
      splashColor: AppColors.champagneGold.withValues(alpha: 0.08),
      leading: Icon(widget.item.icon, color: AppColors.slateMist,
          size: AppDimensions.iconSizeMedium),
      title: Text(widget.item.label, style: AppTypography.body),
      trailing: widget.item.isToggle
          ? Switch(
              value: _isOn,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _isOn = v);
              },
              activeThumbColor:   AppColors.obsidianNight,
              activeTrackColor:   AppColors.champagneGold,
              inactiveThumbColor: AppColors.slateMist,
              inactiveTrackColor: AppColors.surfaceGlassHover,
            )
          : widget.item.trailing != null
              ? Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.item.trailing!, style: AppTypography.caption),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.slateMist,
                      size: AppDimensions.iconSizeMedium),
                ])
              : const Icon(Icons.chevron_right_rounded,
                  color: AppColors.slateMist,
                  size: AppDimensions.iconSizeMedium),
    );
  }
}

// ── D4: "I Found My Match" ────────────────────────────────────

class _IFoundMyMatchButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showConfirmation(context),
      child: Container(
        width:   double.infinity,
        padding: const EdgeInsets.all(AppDimensions.space16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          gradient: LinearGradient(
            colors: [
              AppColors.champagneGold.withValues(alpha: 0.12),
              AppColors.champagneGold.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.space8),
              decoration: BoxDecoration(
                color:  AppColors.champagneGold.withValues(alpha: 0.15),
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: AppColors.champagneGold,
                size:  AppDimensions.iconSizeMedium,
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('I Found My Match',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.champagneGold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.space4),
                  Text('Alhamdulillah! Deactivate your profile.',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.champagneGold,
                size: AppDimensions.iconSizeMedium),
          ],
        ),
      ),
    );
  }

  void _showConfirmation(BuildContext context) {
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin:  const EdgeInsets.all(AppDimensions.space16),
        padding: const EdgeInsets.all(AppDimensions.space24),
        decoration: BoxDecoration(
          color:        const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          border:       Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            const SizedBox(height: AppDimensions.space24),
            const Icon(Icons.favorite_rounded,
                color: AppColors.champagneGold, size: 48),
            const SizedBox(height: AppDimensions.space16),
            Text('Alhamdulillah!',
              style: AppTypography.screenTitle.copyWith(
                color: AppColors.champagneGold, fontSize: 24,
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            Text(
              'May Allah bless your union with\nlove, mercy, and barakah.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space6),
            Text(
              'Your profile will be hidden from searches.\nYou can reactivate anytime.',
              style: AppTypography.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  // Deactivate + sign out
                  context.read<AuthCubit>().signOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Your profile has been deactivated. Mubarak!',
                        style: AppTypography.body,
                      ),
                      backgroundColor: AppColors.surfaceGlassHover,
                      behavior:        SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        side: const BorderSide(color: AppColors.goldBorder),
                      ),
                    ),
                  );
                },
                child: Text('Confirm & Deactivate', style: AppTypography.button),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
            SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeightSmall,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side:  const BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel',
                    style: AppTypography.button.copyWith(
                        color: AppColors.slateMist)),
              ),
            ),
            const SizedBox(height: AppDimensions.space8),
          ],
        ),
      ),
    );
  }
}
