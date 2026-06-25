// lib/features/home/home_screen.dart
// ============================================================
// MITHAQ — Home Screen Shell
// IndexedStack with 4 tabs + MithaqBottomNav.
// Preserves scroll state across tab switches.
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/my_profile_screen.dart';
import 'widgets/mithaq_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab});
  final int? initialTab;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null) {
      _currentTab = widget.initialTab!;
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      _currentTab = widget.initialTab!;
    }
  }

  /// Allows child widgets (e.g. DiscoveryFeedScreen) to switch tabs programmatically.
  void switchToTab(int index) {
    if (index >= 0 && index < _screens.length) {
      setState(() => _currentTab = index);
    }
  }

  static const _screens = [
    DiscoveryFeedScreen(),
    InterestsScreen(),
    ChatListScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.obsidianNight,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentTab,
          children: _screens,
        ),
      ),
      bottomNavigationBar: MithaqBottomNav(
        currentIndex:  _currentTab,
        onTabSelected: (index) => setState(() => _currentTab = index),
      ),
    );
  }
}
