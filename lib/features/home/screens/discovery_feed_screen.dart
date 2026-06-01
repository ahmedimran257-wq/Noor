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

import '../../../core/cubits/discovery/discovery_feed_cubit.dart';
import '../../../core/cubits/discovery/discovery_feed_state.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/onboarding/onboarding_cubit.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/models/onboarding_data.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cards/noor_profile_card.dart';
import '../../../core/widgets/loaders/noor_shimmer.dart';
import '../widgets/discovery_filter_bar.dart';
import '../widgets/interest_ceremony_overlay.dart';
import '../widgets/interest_note_sheet.dart';
import 'paywall_gate_screen.dart';
import 'profile_detail_screen.dart';
import 'notifications_screen.dart';
import '../../../features/home/home_screen.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key});

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen> {
  late final PageController _pageCtrl;
  int         _currentPage = 0;
  double      _pageOffset  = 0.0; // Continuous scroll offset for smooth scaling
  final Set<String> _sentInterests = {};
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
    final rawPage = _pageCtrl.page ?? 0.0;
    final page = rawPage.round();

    // Update continuous offset for smooth card scaling
    if (mounted) setState(() => _pageOffset = rawPage);

    if (page != _currentPage) {
      _currentPage = page;
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
    // G2: Show note sheet before sending (consistent with profile detail)
    final note = await showInterestNoteSheet(
      context,
      firstName: fp.profile.firstName,
    );
    if (note == null || !mounted) return; // cancelled

    setState(() => _sentInterests.add(fp.profile.id));
    context.read<InterestsCubit>().sendInterest(
      fp.profile,
      note: note.isNotEmpty ? note : null,
    );
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
            isInterestSent: _sentInterests.contains(fp.profile.id),
            onInterestSent: () => setState(() => _sentInterests.add(fp.profile.id)),
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
        return RefreshIndicator(
          color: AppColors.champagneGold,
          backgroundColor: AppColors.obsidianNight,
          onRefresh: () async {
            context.read<DiscoveryFeedCubit>().loadInitial();
            // Wait a bit for the cubit to emit new state
            await Future.delayed(const Duration(milliseconds: 800));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
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
                      const Text('NOOR', style: AppTypography.wordmark),
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
              ),

              // ── Filter bar ──────────────────────────────────
              const SliverToBoxAdapter(child: DiscoveryFilterBar()),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.space16)),

              // ── Card carousel ────────────────────────────────
              SliverFillRemaining(
                hasScrollBody: true,
                child: _buildCarousel(feedState),
              ),
            ],
          ),
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

    // G11 (D5): Profile completeness gate — ≤40% → nudge to complete
    final onbData = context.read<OnboardingCubit>().currentData;
    final completeness = _quickCompleteness(onbData);
    if (completeness <= 40) {
      return _IncompleteProfileGate(score: completeness);
    }

    final profiles     = feedState.profiles;
    final isLoadingMore = feedState.status == FeedStatus.loadingMore;

    // M9: Check free-tier browse limit for non-subscribers
    final subState = context.read<SubscriptionCubit>().state;
    final isLimited = feedState.isFreeTierLimitReached && !subState.isSubscribed;

    if (isLimited) {
      return _FreeTierLimitReached(
        onUpgrade: () => PaywallGateSheet.show(context),
      );
    }

    final itemCount    = profiles.length + (isLoadingMore ? 1 : 0);

    return PageView.builder(
      controller:   _pageCtrl,
      itemCount:    itemCount,
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemBuilder:  (context, index) {
        // Continuous scale: 1.0 at center, 0.95 at 1.0 page distance
        final double offset = (index - _pageOffset).abs();
        final double scale = (1.0 - (offset * 0.05)).clamp(0.95, 1.0);

        // Skeleton card at the end while loading more
        if (index >= profiles.length) {
          return _cardPadding(
            child: Transform.scale(
              scale: scale,
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
                  lastActiveLabel: fp.lastActiveLabel,
                  isFocused:       true, // Scale handled externally now
                  cardScale:       scale,
                  isInterestSent:  _sentInterests.contains(p.id),
                  onTap:           () => _openProfile(index, fp),
                  onSendInterest:  _sentInterests.contains(p.id)
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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationsScreen(),
          ),
        );
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
            const Text(
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

// ── M9: Free-Tier Browse Limit ────────────────────────────────
class _FreeTierLimitReached extends StatelessWidget {
  const _FreeTierLimitReached({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                color:  AppColors.champagneGold.withValues(alpha: 0.1),
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: const [
                  BoxShadow(
                    color:        AppColors.goldGlow,
                    blurRadius:   24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_clock_rounded,
                color: AppColors.champagneGold,
                size:  44,
              ),
            ),
            const SizedBox(height: AppDimensions.space28),
            Text(
              'Daily limit reached',
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppDimensions.space12),
            const Text(
              'You\'ve browsed 15 profiles today.\nUpgrade to unlock unlimited browsing.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24,
                  vertical:   AppDimensions.space14,
                ),
                decoration: BoxDecoration(
                  color:        AppColors.champagneGold,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: const Text('Upgrade Now', style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── G11 (D5): Profile Completeness Gate ───────────────────────

/// Lightweight completeness score (mirrors MyProfileScreen logic).
int _quickCompleteness(OnboardingData d) {
  int score = 0;
  if (d.photoLocalPaths != null && d.photoLocalPaths!.isNotEmpty) score += 25;
  if ((d.bio?.length ?? 0) >= 50) score += 15;
  if (d.sect != null && d.deenLevel != null) score += 15;
  if ((d.educationLabel != null || d.educationRank != null) &&
      (d.profession?.isNotEmpty ?? false)) {
    score += 10;
  }
  if (d.familyType != null) score += 10;
  if (d.preferredAgeMin != null && d.preferredAgeMax != null) score += 10;
  if (d.photoLocalPaths != null && d.photoLocalPaths!.length >= 2) score += 8;
  if (d.incomeBracketId != null) score += 4;
  if (d.languages != null && d.languages!.isNotEmpty) score += 3;
  return score.clamp(0, 100);
}

class _IncompleteProfileGate extends StatelessWidget {
  const _IncompleteProfileGate({required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular progress
            SizedBox(
              width: 100, height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 100, height: 100,
                    child: CircularProgressIndicator(
                      value:           score / 100,
                      strokeWidth:     5,
                      backgroundColor: AppColors.surfaceGlassHover,
                      valueColor:      const AlwaysStoppedAnimation(AppColors.champagneGold),
                    ),
                  ),
                  Text(
                    '$score%',
                    style: AppTypography.screenTitle.copyWith(
                      color:    AppColors.champagneGold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.space24),
            Text(
              'Complete Your Profile',
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space8),
            const Text(
              'Profiles above 40% get 3× more interests.\n'
              'Complete your profile to start browsing.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            SizedBox(
              width:  double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.obsidianNight, size: 18),
                label: const Text('Complete Profile', style: AppTypography.button),
                onPressed: () {
                  // Switch to Profile tab (index 3) via HomeScreen
                  final homeState = context.findAncestorStateOfType<HomeScreenState>();
                  homeState?.switchToTab(3);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
