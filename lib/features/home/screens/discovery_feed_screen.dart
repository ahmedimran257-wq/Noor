// lib/features/home/screens/discovery_feed_screen.dart
// ============================================================
// NOOR — Discovery Feed (Step 5 — Blueprint Complete)
//
// Blueprint requirements (Part 8):
//   • Horizontal paged carousel — one card at a time
//   • viewportFraction 0.88 → adjacent cards peek at 0.95 scale
//   • Cursor-based pagination via DiscoveryFeedCubit
//   • Skeleton loaders on initial load AND page-load-more
//   • Filter bar (horizontal scrollable chips)
//   • Every 10th card: "Someone you might connect with" label
//   • Free-tier counter: "12 profiles remaining today"
//   • Dot indicator (max 7, sliding window)
//   • Interest ceremony → cubit + overlay
//   • Bookmark toggle with persistence via BookmarkService
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/discovery/discovery_feed_state.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cards/noor_profile_card.dart';
import '../../../core/widgets/loaders/noor_shimmer.dart';
import '../widgets/discovery_filter_bar.dart';
import '../widgets/interest_ceremony_overlay.dart';
import 'profile_detail_screen.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late final PageController _pageCtrl;
  int         _currentPage = 0;
  final Set<int>    _sentInterests = {};
  // Bookmarks now use profile IDs (String) for persistence
  Set<String> _bookmarked = {};

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);
    _pageCtrl.addListener(_onScroll);

    // Trigger initial load after first frame so cubit is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoveryFeedCubit>().loadInitial();
      _loadBookmarks();
    });
  }

  @override
  void dispose() {
    _pageCtrl.removeListener(_onScroll);
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    final ids = await BookmarkService.load();
    if (mounted) setState(() => _bookmarked = ids);
  }

  void _onScroll() {
    final page = _pageCtrl.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
      context.read<DiscoveryFeedCubit>().recordProfileView();
    }

    // Trigger pagination when 2 cards from the end
    final feedState = context.read<DiscoveryFeedCubit>().state;
    final total = feedState.profiles.length;
    if (page >= total - 2 && feedState.status == FeedStatus.loaded) {
      context.read<DiscoveryFeedCubit>().loadMore();
    }
  }

  Future<void> _handleSendInterest(int index, FeedProfile fp) async {
    setState(() => _sentInterests.add(index));
    context.read<InterestsCubit>().sendInterest(fp.profile);
    HapticFeedback.mediumImpact();
    await showInterestCeremony(context, firstName: fp.profile.firstName);
  }

  void _handleBookmark(int index, FeedProfile fp) {
    HapticFeedback.selectionClick();
    final id = fp.profile.id;
    setState(() {
      if (_bookmarked.contains(id)) {
        _bookmarked.remove(id);
      } else {
        _bookmarked.add(id);
      }
    });
    // Persist updated bookmark set
    BookmarkService.save(Set<String>.from(_bookmarked));

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _bookmarked.contains(id)
                ? '${fp.profile.firstName} saved'
                : '${fp.profile.firstName} removed',
            style: AppTypography.body,
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  void _openProfile(int index, FeedProfile fp) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppDimensions.durationReveal,
        pageBuilder: (context, animation, _) => FadeTransition(
          opacity: animation,
          child: ProfileDetailScreen(
            profile:        fp.profile,
            heroTag:        'profile_card_$index',
            isInterestSent: _sentInterests.contains(index),
            onInterestSent: () => setState(() => _sentInterests.add(index)),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryFeedCubit, DiscoveryFeedState>(
      builder: (context, feedState) {
        return Column(
          children: [
            // ── Top app bar ─────────────────────────────────
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
                  // Free-tier counter badge
                  if (feedState.status == FeedStatus.loaded ||
                      feedState.status == FeedStatus.loadingMore)
                    _FreeTierCounter(remaining: feedState.remainingToday),
                  const SizedBox(width: AppDimensions.space12),
                  _NotificationButton(),
                ],
              ),
            ),

            // ── Filter bar ──────────────────────────────────
            const DiscoveryFilterBar(),
            const SizedBox(height: AppDimensions.space16),

            // ── Card carousel ────────────────────────────────
            Expanded(child: _buildCarousel(feedState)),

            // ── Dot indicator ────────────────────────────────
            const SizedBox(height: AppDimensions.space16),
            if (feedState.status != FeedStatus.initial &&
                feedState.status != FeedStatus.loading)
              _DotIndicator(
                count:   feedState.profiles.length,
                current: _currentPage,
              ),
            const SizedBox(height: AppDimensions.space20),
          ],
        );
      },
    );
  }

  Widget _buildCarousel(DiscoveryFeedState feedState) {
    // Full-screen skeleton on initial load
    if (feedState.status == FeedStatus.initial ||
        feedState.status == FeedStatus.loading) {
      return _InitialShimmer();
    }

    if (feedState.status == FeedStatus.empty) {
      return const _EmptyFeed();
    }

    final profiles     = feedState.profiles;
    final isLoadingMore = feedState.status == FeedStatus.loadingMore;
    final itemCount    = profiles.length + (isLoadingMore ? 1 : 0);

    return PageView.builder(
      controller:   _pageCtrl,
      itemCount:    itemCount,
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemBuilder:  (context, index) {
        final focused = index == _currentPage;

        // Skeleton card at the end while loading more
        if (index >= profiles.length) {
          return _cardPadding(
            child: Transform.scale(
              scale: focused ? 1.0 : 0.95,
              child: const NoorProfileCardShimmer(),
            ),
          );
        }

        final fp = profiles[index];
        final p  = fp.profile;


        return _cardPadding(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main card (with Hero for shared-element to detail)
              Hero(
                tag: 'profile_card_$index',
                child: NoorProfileCard(
                  firstName:       p.firstName,
                  lastNameInitial: p.lastNameInitial,
                  age:             p.age,
                  cityName:        p.cityName,
                  sect:            p.sect,
                  deenLevel:       p.deenLevel,
                  profession:      p.occupation,
                  photoUrl:        p.photoUrl,
                  photoCount:      p.photoCount,
                  isPhotoPrivate:  p.isPhotoPrivate,
                  isVerified:      p.isVerified,
                  isFocused:       focused,
                  isInterestSent:  _sentInterests.contains(index),
                  onTap:           () => _openProfile(index, fp),
                  onSendInterest:  _sentInterests.contains(index)
                      ? null
                      : () => _handleSendInterest(index, fp),
                  onBookmark:      () => _handleBookmark(index, fp),
                ),
              ),

              // Wild-card label — "Someone you might connect with"
              if (fp.isWildCard)
                Positioned(
                  top:   -12,
                  left:  AppDimensions.space12,
                  right: AppDimensions.space12,
                  child: Center(
                    child: _WildCardLabel(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cardPadding({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space6,
        vertical:   AppDimensions.space4,
      ),
      child: child,
    );
  }
}

// ── Wild-card Label ───────────────────────────────────────────

class _WildCardLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        AppColors.champagneGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
            color: AppColors.champagneGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Someone you might connect with',
        style: AppTypography.caption.copyWith(
          color:        AppColors.champagneGold,
          fontSize:     11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Free-Tier Counter Badge ───────────────────────────────────

class _FreeTierCounter extends StatelessWidget {
  const _FreeTierCounter({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: remaining <= 3
            ? AppColors.errorRed.withValues(alpha: 0.15)
            : AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border: Border.all(
          color: remaining <= 3 ? AppColors.errorRed : AppColors.cardBorder,
        ),
      ),
      child: Text(
        '$remaining profiles remaining',
        style: AppTypography.caption.copyWith(
          color:    remaining <= 3 ? AppColors.errorRed : AppColors.slateMist,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Notification Button ───────────────────────────────────────

class _NotificationButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/notifications');
      },
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

// ── Initial Shimmer (3-card stack) ────────────────────────────

class _InitialShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: PageController(viewportFraction: 0.88),
      children: const [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.space6,
            vertical:   AppDimensions.space4,
          ),
          child: NoorProfileCardShimmer(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.space6,
            vertical:   AppDimensions.space4,
          ),
          child: NoorProfileCardShimmer(),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppDimensions.space6,
            vertical:   AppDimensions.space4,
          ),
          child: NoorProfileCardShimmer(),
        ),
      ],
    );
  }
}

// ── Empty Feed State ──────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.space24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder, width: 2),
              ),
              child: const Icon(
                Icons.explore_outlined,
                color: AppColors.champagneGold,
                size:  48,
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            Text(
              'You\'ve seen everyone nearby',
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              'Try expanding your search filters\nor check back tomorrow.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
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
    const maxDots = 7;
    final start =
        (current - maxDots ~/ 2).clamp(0, (count - maxDots).clamp(0, count));
    final end = (start + maxDots).clamp(0, count);

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
              color: i == current
                  ? AppColors.champagneGold
                  : AppColors.slateMist.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
