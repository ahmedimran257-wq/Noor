// lib/features/home/home_screen.dart
// ============================================================
// SILARAH — Home Screen Shell
// IndexedStack with 4 tabs + SilarahBottomNav.
// Preserves scroll state across tab switches.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/cubits/account_standing/account_standing_cubit.dart';
import '../../core/cubits/account_standing/account_standing_state.dart';
import '../../core/cubits/chat/chat_cubit.dart';
import '../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../core/cubits/interests/interests_cubit.dart';
import '../../core/cubits/interests/interests_state.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimensions.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons/silarah_pressable.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/my_profile_screen.dart';
import 'widgets/silarah_bottom_nav.dart';
import 'widgets/interest_quota_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab});
  final int? initialTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentTab = 0;
  late final List<Widget?> _tabCache;
  int _profileRefreshToken = 0;
  static const _tabCount = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialTab != null) {
      _currentTab = widget.initialTab!;
    }
    _tabCache = List<Widget?>.filled(_tabCount, null);
    _ensureTabBuilt(_currentTab);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshTabData(_currentTab);
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null &&
        widget.initialTab != oldWidget.initialTab) {
      _ensureTabBuilt(widget.initialTab!);
      _currentTab = widget.initialTab!;
    }
  }

  /// Allows child widgets (e.g. DiscoveryFeedScreen) to switch tabs programmatically.
  void switchToTab(int index) {
    if (index < 0 || index >= _tabCount || index == _currentTab) return;
    setState(() {
      _ensureTabBuilt(index);
      if (index == 3) {
        _tabCache[3] = MyProfileScreen(refreshToken: ++_profileRefreshToken);
      }
      _currentTab = index;
    });
    _refreshTabData(index);
  }

  void _selectTab(int index) {
    if (index == _currentTab) {
      _refreshTabData(index);
      return;
    }
    setState(() {
      _ensureTabBuilt(index);
      if (index == 3) {
        _tabCache[3] = MyProfileScreen(refreshToken: ++_profileRefreshToken);
      }
      _currentTab = index;
    });
    _refreshTabData(index);
  }

  void _refreshTabData(int index) {
    switch (index) {
      case 0:
        context.read<DiscoveryFeedCubit>().refreshIfChanged();
      case 1:
        context.read<InterestsCubit>().loadData(force: true);
      case 2:
        context
            .read<ChatCubit>()
            .loadConversations(showLoading: false, force: true);
    }
  }

  void _ensureTabBuilt(int index) {
    _tabCache[index] ??= switch (index) {
      0 => DiscoveryFeedScreen(onOpenTab: switchToTab),
      1 => const InterestsScreen(),
      2 => const ChatListScreen(),
      _ => MyProfileScreen(refreshToken: _profileRefreshToken),
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<InterestsCubit, InterestsState>(
      listenWhen: (previous, current) =>
          (!previous.limitError && current.limitError) ||
          (!previous.quotaUnavailable && current.quotaUnavailable),
      listener: (context, quota) {
        if (quota.limitError) {
          InterestQuotaSheet.show(context, quota: quota);
          context.read<InterestsCubit>().clearLimitError();
          return;
        }
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(const SnackBar(
            content: Text(
              'We could not verify your daily allowance. Check your connection and try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ));
        context.read<InterestsCubit>().clearQuotaUnavailable();
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianNight,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              BlocBuilder<AccountStandingCubit, AccountStandingState>(
                buildWhen: (previous, current) =>
                    previous.kind != current.kind ||
                    previous.updating != current.updating ||
                    previous.errorMessage != current.errorMessage,
                builder: (context, standing) => AnimatedSwitcher(
                  duration: AppDimensions.durationReveal,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: standing.showsPersistentNotice
                      ? _PersistentStandingBanner(
                          key: ValueKey(standing.kind),
                          standing: standing,
                        )
                      : const SizedBox.shrink(key: ValueKey('standing-clear')),
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _currentTab,
                  children: List.generate(
                    _tabCount,
                    (index) => TickerMode(
                      enabled: index == _currentTab,
                      child: ExcludeSemantics(
                        excluding: index != _currentTab,
                        child: RepaintBoundary(
                          child: _tabCache[index] ?? const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SilarahBottomNav(
          currentIndex: _currentTab,
          onTabSelected: _selectTab,
        ),
        resizeToAvoidBottomInset: false,
      ),
    );
  }
}

class _PersistentStandingBanner extends StatelessWidget {
  const _PersistentStandingBanner({
    super.key,
    required this.standing,
  });

  final AccountStandingState standing;

  @override
  Widget build(BuildContext context) {
    final restricted = standing.isRestricted;
    final accent = restricted ? AppColors.softCoral : AppColors.champagneGold;
    final (title, message, icon) = switch (standing.kind) {
      AccountStandingKind.paused => (
          'Profile paused',
          'You are hidden from discovery.',
          Icons.pause_circle_outline_rounded,
        ),
      AccountStandingKind.suspended => (
          'Profile suspended',
          'Discovery access is restricted. Support can review this decision.',
          Icons.gpp_maybe_outlined,
        ),
      AccountStandingKind.banned => (
          'Account banned',
          'Your account has an enforced restriction. Contact support to appeal.',
          Icons.block_rounded,
        ),
      _ => (
          'Profile unavailable',
          'Contact support for help restoring your profile.',
          Icons.person_off_outlined,
        ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: accent.withValues(alpha: 0.42)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.captionMedium.copyWith(color: accent),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    standing.errorMessage ?? message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(height: 1.25),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SilarahPressable(
              semanticLabel: restricted ? 'Contact support' : 'Resume profile',
              onTap: standing.updating
                  ? null
                  : restricted
                      ? () => context.push(AppRoutes.helpSupport)
                      : () =>
                          context.read<AccountStandingCubit>().resumeProfile(),
              enabled: !standing.updating,
              child: Container(
                constraints: const BoxConstraints(minWidth: 76),
                height: 38,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: restricted ? Colors.transparent : accent,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                  border: Border.all(color: accent),
                ),
                child: standing.updating
                    ? SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: restricted ? accent : AppColors.obsidianNight,
                        ),
                      )
                    : Text(
                        restricted ? 'Get help' : 'Resume',
                        style: AppTypography.captionMedium.copyWith(
                          color: restricted ? accent : AppColors.obsidianNight,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
