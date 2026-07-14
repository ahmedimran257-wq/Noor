// lib/features/home/home_screen.dart
// ============================================================
// SILARAH — Home Screen Shell
// IndexedStack with 4 tabs + SilarahBottomNav.
// Preserves scroll state across tab switches.
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/my_profile_screen.dart';
import 'widgets/silarah_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab});
  final int? initialTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  late final List<Widget?> _tabCache;
  static const _tabCount = 4;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _currentTab = widget.initialTab!;
    }
    _tabCache = List<Widget?>.filled(_tabCount, null);
    _ensureTabBuilt(_currentTab);
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
      _currentTab = index;
    });
  }

  void _selectTab(int index) {
    if (index == _currentTab) return;
    setState(() {
      _ensureTabBuilt(index);
      _currentTab = index;
    });
  }

  void _ensureTabBuilt(int index) {
    _tabCache[index] ??= switch (index) {
      0 => const DiscoveryFeedScreen(),
      1 => const InterestsScreen(),
      2 => const ChatListScreen(),
      _ => const MyProfileScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        bottom: false,
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
      bottomNavigationBar: SilarahBottomNav(
        currentIndex: _currentTab,
        onTabSelected: _selectTab,
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
