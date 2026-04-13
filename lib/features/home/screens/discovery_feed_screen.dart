// lib/features/home/screens/discovery_feed_screen.dart
// ============================================================
// NOOR — Discovery Feed
// The heart of the app. Horizontally paged NoorProfileCard carousel.
//
// Layout:
//   • PageView.builder with viewportFraction: 0.88 (adjacent card peek)
//   • Card scale: focused = 1.0, adjacent = 0.95 (AnimatedScale in card)
//   • Quick-filter bar above cards
//   • Dot indicator below cards
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/widgets/cards/noor_profile_card.dart';
import '../widgets/discovery_filter_bar.dart';
import '../widgets/interest_ceremony_overlay.dart';
import '../../../core/widgets/loaders/noor_shimmer.dart';
import 'profile_detail_screen.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late final PageController _pageCtrl;
  int    _currentPage     = 0;
  bool   _isLoadingMore   = false;
  final  Set<int> _sentInterests  = {};
  final  Set<int> _bookmarked     = {};

  final List<MockProfile> _profiles = List.of(kMockProfiles);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88, initialPage: 0);
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
        
        // Trigger pagination load when approaching the end
        if (page >= _profiles.length - 2 && !_isLoadingMore) {
          _fetchMoreProfiles();
        }
      }
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchMoreProfiles() async {
    setState(() => _isLoadingMore = true);
    
    // Simulate network latency for cursor pagination
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      setState(() {
        // Append another batch of profiles to simulate infinite feed
        _profiles.addAll(kMockProfiles);
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleSendInterest(int index) async {
    setState(() => _sentInterests.add(index));
    context.read<InterestsCubit>().sendInterest(_profiles[index]);
    HapticFeedback.mediumImpact();
    await showInterestCeremony(
      context,
      firstName: _profiles[index].firstName,
    );
  }

  void _handleBookmark(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_bookmarked.contains(index)) {
        _bookmarked.remove(index);
      } else {
        _bookmarked.add(index);
      }
    });
    // Brief gold flash feedback
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _bookmarked.contains(index)
                ? '${_profiles[index].firstName} saved'
                : '${_profiles[index].firstName} removed',
            style: AppTypography.body,
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior:        SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side:         const BorderSide(color: AppColors.cardBorder),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _openProfile(int index) {
    final p = _profiles[index];
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppDimensions.durationReveal,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: ProfileDetailScreen(
            profile:        p,
            heroTag:        'profile_card_$index',
            isInterestSent: _sentInterests.contains(index),
            onInterestSent: () => setState(() => _sentInterests.add(index)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Top app bar ───────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.space24,
            AppDimensions.space16,
            AppDimensions.space24,
            AppDimensions.space12,
          ),
          child: Row(
            children: [
              Text('نور', style: AppTypography.wordmark.copyWith(fontSize: 26)),
              const SizedBox(width: AppDimensions.space8),
              Text('NOOR', style: AppTypography.wordmark),
              const Spacer(),
              _NotificationButton(),
            ],
          ),
        ),

        // ── Filter bar ────────────────────────────────────
        const DiscoveryFilterBar(),
        const SizedBox(height: AppDimensions.space16),

        // ── Card carousel ─────────────────────────────────
        Expanded(
          child: PageView.builder(
            controller:   _pageCtrl,
            itemCount:    _profiles.length + (_isLoadingMore ? 1 : 0),
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemBuilder:  (context, index) {
              final focused  = index == _currentPage;
              
              if (index >= _profiles.length) {
                // Skeleton loading state for pagination
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space6,
                    vertical:   AppDimensions.space4,
                  ),
                  child: Transform.scale(
                    scale: focused ? 1.0 : 0.95,
                    child: const NoorProfileCardShimmer(),
                  ),
                );
              }

              final p = _profiles[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space6,
                  vertical:   AppDimensions.space4,
                ),
                child: Hero(
                  tag: 'profile_card_$index',
                  child: NoorProfileCard(
                    firstName:      p.firstName,
                    lastNameInitial: p.lastNameInitial,
                    age:            p.age,
                    cityName:       p.cityName,
                    sect:           p.sect,
                    deenLevel:      p.deenLevel,
                    photoUrl:       p.photoUrl,
                    photoCount:     p.photoCount,
                    isPhotoPrivate: p.isPhotoPrivate,
                    isVerified:     p.isVerified,
                    isFocused:      focused,
                    isInterestSent: _sentInterests.contains(index),
                    onTap:          () => _openProfile(index),
                    onSendInterest: _sentInterests.contains(index)
                        ? null
                        : () => _handleSendInterest(index),
                    onBookmark:     () => _handleBookmark(index),
                  ),
                ),
              );
            },
          ),
        ),

        // ── Dot indicator ─────────────────────────────────
        const SizedBox(height: AppDimensions.space16),
        _DotIndicator(
          count:   _profiles.length,
          current: _currentPage,
        ),
        const SizedBox(height: AppDimensions.space20),
      ],
    );
  }
}

// ── Notification button ───────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => HapticFeedback.selectionClick(),
      child: Container(
        width:  AppDimensions.minTouchTarget,
        height: AppDimensions.minTouchTarget,
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border:       Border.all(color: AppColors.cardBorder),
        ),
        child: const Icon(
          Icons.notifications_none_rounded,
          color: AppColors.slateMist,
          size:  AppDimensions.iconSizeLarge,
        ),
      ),
    );
  }
}

// ── Dot Indicator ─────────────────────────────────────────────

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    // Show at most 7 dots; use a sliding window
    const maxDots = 7;
    final start = (current - maxDots ~/ 2).clamp(0, (count - maxDots).clamp(0, count));
    final end   = (start + maxDots).clamp(0, count);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = start; i < end; i++)
          AnimatedContainer(
            duration: AppDimensions.durationTransition,
            margin:   const EdgeInsets.symmetric(horizontal: 3),
            width:    i == current ? 20 : 6,
            height:   6,
            decoration: BoxDecoration(
              color:        i == current
                  ? AppColors.champagneGold
                  : AppColors.slateMist.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
