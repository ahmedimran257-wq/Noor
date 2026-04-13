// lib/features/home/home_screen.dart
// ============================================================
// NOOR — Home Screen Shell
// IndexedStack with 4 tabs + NoorBottomNav.
// Preserves scroll state across tab switches.
// ============================================================

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'screens/discovery_feed_screen.dart';
import 'screens/interests_screen.dart';
import 'screens/chat_list_screen.dart';
import 'screens/my_profile_screen.dart';
import 'widgets/noor_bottom_nav.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;

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
      bottomNavigationBar: NoorBottomNav(
        currentIndex:  _currentTab,
        onTabSelected: (index) => setState(() => _currentTab = index),
      ),
    );
  }
}
