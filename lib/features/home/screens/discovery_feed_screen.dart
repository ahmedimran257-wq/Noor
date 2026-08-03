// lib/features/home/screens/discovery_feed_screen.dart
// ============================================================
// SILARAH — Discovery Feed (Step 5 — Blueprint Complete)
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
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/services/bookmark_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/cards/silarah_profile_card.dart';
import '../../../core/widgets/loaders/silarah_shimmer.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../widgets/discovery_filter_bar.dart';
import '../widgets/interest_ceremony_overlay.dart';
import '../widgets/interest_note_sheet.dart';
import '../widgets/notification_bell_button.dart';
import 'paywall_gate_screen.dart';
import 'profile_detail_screen.dart';
import 'notifications_screen.dart';

class DiscoveryFeedScreen extends StatefulWidget {
  const DiscoveryFeedScreen({super.key, this.onOpenTab});

  final ValueChanged<int>? onOpenTab;

  @override
  State<DiscoveryFeedScreen> createState() => _DiscoveryFeedScreenState();
}

class _DiscoveryFeedScreenState extends State<DiscoveryFeedScreen>
    with AutomaticKeepAliveClientMixin {
  late final PageController _pageCtrl;
  int _currentPage = 0;
  final Set<String> _recordedViewIds = {};
  // Bookmarks now use profile IDs (String) for persistence
  Set<String> _bookmarked = {};
  final Set<String> _bookmarkWritesInFlight = <String>{};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController(viewportFraction: 0.88);

    // Trigger initial load after first frame so cubit is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoveryFeedCubit>().loadInitial();
      _loadBookmarks();
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    try {
      final ids = await BookmarkService.load();
      if (mounted) setState(() => _bookmarked = ids);
    } catch (_) {
      if (mounted) setState(() => _bookmarked = {});
    }
  }

  void _onPageChanged(int page) {
    _currentPage = page;
    // Trigger pagination when 2 cards from the end
    final feedState = context.read<DiscoveryFeedCubit>().state;
    final profiles = feedState.profiles;
    if (page >= 0 && page < profiles.length) {
      _recordVisibleProfileView(profiles[page].profile.id);
    }
    final total = feedState.profiles.length;
    if (page >= total - 2 && feedState.status == FeedStatus.loaded) {
      context.read<DiscoveryFeedCubit>().loadMore();
    }
  }

  Future<void> _handleSendInterest(int index, FeedProfile fp) async {
    if (!await context.read<InterestsCubit>().canStartInterest() || !mounted) {
      return;
    }
    // G2: Show note sheet before sending (consistent with profile detail)
    final note = await showInterestNoteSheet(
      context,
      firstName: fp.profile.firstName,
    );
    if (note == null || !mounted) return; // cancelled

    final sent = await context.read<InterestsCubit>().sendInterest(
          fp.profile,
          note: note.isNotEmpty ? note : null,
        );
    if (!mounted || !sent) return;
    HapticFeedback.mediumImpact();
    await showInterestCeremony(context, firstName: fp.profile.firstName);
    if (!mounted) return;
    await context.read<DiscoveryFeedCubit>().loadInitial(force: true);
  }

  Future<void> _handleBookmark(int index, FeedProfile fp) async {
    final id = fp.profile.id;
    if (_bookmarkWritesInFlight.contains(id)) return;
    _bookmarkWritesInFlight.add(id);
    HapticFeedback.selectionClick();
    final previous = Set<String>.from(_bookmarked);
    setState(() {
      if (_bookmarked.contains(id)) {
        _bookmarked.remove(id);
      } else {
        _bookmarked.add(id);
      }
    });

    final targetSaved = _bookmarked.contains(id);
    try {
      final saved = await BookmarkService.setSaved(id, targetSaved);
      if (mounted) setState(() => _bookmarked = saved);
    } catch (_) {
      if (mounted) setState(() => _bookmarked = previous);
      _bookmarkWritesInFlight.remove(id);
      return;
    }

    _bookmarkWritesInFlight.remove(id);

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _bookmarked.contains(id)
                ? l10n.discovery_bookmark_saved(fp.profile.firstName)
                : l10n.discovery_bookmark_removed(fp.profile.firstName),
            style: AppTypography.body.copyWith(
              color: AppColors.readableOn(AppColors.surfaceGlassHover),
            ),
          ),
          backgroundColor: AppColors.surfaceGlassHover,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
            side: BorderSide(color: AppColors.cardBorder),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
  }

  Future<void> _openProfile(int index, FeedProfile fp) async {
    final allowed = await _recordVisibleProfileView(fp.profile.id);
    if (!mounted) return;
    if (!allowed) {
      PaywallGateSheet.show(context);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailScreen(
          profile: fp.profile,
          heroTag: 'profile_card_$index',
        ),
      ),
    );
  }

  Future<bool> _recordVisibleProfileView(String profileUserId) async {
    if (_recordedViewIds.contains(profileUserId)) return true;
    final allowed = await context
        .read<DiscoveryFeedCubit>()
        .recordProfileView(profileUserId);
    if (allowed && mounted) {
      _recordedViewIds.add(profileUserId);
    }
    return allowed;
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final interests = context.watch<InterestsCubit>().state;
    return BlocConsumer<DiscoveryFeedCubit, DiscoveryFeedState>(
      listenWhen: (previous, current) =>
          previous.activeFilter != current.activeFilter,
      listener: (context, state) {
        _currentPage = 0;
        if (_pageCtrl.positions.length == 1) {
          _pageCtrl.jumpToPage(0);
        }
      },
      builder: (context, feedState) {
        return RefreshIndicator(
          color: AppColors.champagneGold,
          backgroundColor: AppColors.obsidianNight,
          onRefresh: () async {
            _recordedViewIds.clear();
            await context.read<DiscoveryFeedCubit>().loadInitial(force: true);
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
                      Text('سيلارا',
                          style: AppTypography.wordmark.copyWith(fontSize: 26)),
                      const SizedBox(width: AppDimensions.space8),
                      Text('SILARAH', style: AppTypography.wordmark),
                      const Spacer(),
                      // Free-tier counter badge
                      if ((feedState.status == FeedStatus.loaded ||
                              feedState.status == FeedStatus.refreshing ||
                              feedState.status == FeedStatus.loadingMore) &&
                          feedState.dailyLimit < 1000000)
                        _FreeTierCounter(remaining: feedState.remainingToday),
                      const SizedBox(width: AppDimensions.space12),
                      _NotificationButton(),
                    ],
                  ),
                ),
              ),

              // ── Filter bar ──────────────────────────────────
              const SliverToBoxAdapter(child: DiscoveryFilterBar()),
              const SliverToBoxAdapter(
                  child: SizedBox(height: AppDimensions.space16)),

              // ── Card carousel ────────────────────────────────
              SliverFillRemaining(
                hasScrollBody: true,
                child: _buildCarousel(feedState, interests),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCarousel(
    DiscoveryFeedState feedState,
    InterestsState interests,
  ) {
    // Full-screen skeleton on initial load
    if (feedState.status == FeedStatus.initial ||
        feedState.status == FeedStatus.loading) {
      return _InitialShimmer();
    }

    final isLimited =
        feedState.isFreeTierLimitReached && feedState.dailyLimit < 1000000;

    if (isLimited) {
      return _FreeTierLimitReached(
        onUpgrade: () => PaywallGateSheet.show(context),
      );
    }

    if (feedState.status == FeedStatus.empty) {
      return _EmptyFeed(
        hasActiveFilters: feedState.activeFilter.isActive,
        onRefresh: () =>
            context.read<DiscoveryFeedCubit>().loadInitial(force: true),
        onClearFilters: () => context.read<DiscoveryFeedCubit>().clearFilters(),
      );
    }

    if (feedState.status == FeedStatus.error) {
      return _DiscoveryError(
        message: feedState.errorMessage ??
            'Unable to load profiles. Please try again.',
        onRetry: () =>
            context.read<DiscoveryFeedCubit>().loadInitial(force: true),
      );
    }

    final profiles = feedState.profiles;
    final isLoadingMore = feedState.status == FeedStatus.loadingMore;

    final itemCount = profiles.length + (isLoadingMore ? 1 : 0);

    final carousel = PageView.builder(
      controller: _pageCtrl,
      itemCount: itemCount,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        // Skeleton card at the end while loading more
        if (index >= profiles.length) {
          return _scaledCard(
            index,
            _cardPadding(child: const SilarahProfileCardShimmer()),
          );
        }

        final fp = profiles[index];
        final p = fp.profile;
        final action = _profileAction(index, fp, interests);

        return _scaledCard(
          index,
          _cardPadding(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main card (with Hero for shared-element to detail)
                Hero(
                  tag: 'profile_card_$index',
                  child: SilarahProfileCard(
                    displayName: p.displayName,
                    age: p.age,
                    cityName: p.cityName,
                    sect: p.sect,
                    deenLevel: p.deenLevel,
                    profession: p.occupation,
                    photoUrl: p.photoUrl,
                    photoCount: p.photoCount,
                    isPhotoPrivate: p.isPhotoPrivate,
                    isVerified: p.isVerified,
                    lastActiveLabel: fp.lastActiveLabel,
                    isFocused: true, // Scale handled externally now
                    cardScale: 1,
                    isBookmarked: _bookmarked.contains(p.id),
                    interestActionLabel: action.label,
                    isInterestActionEnabled: action.onTap != null,
                    previousMatchLabel: p.previousMatchAt == null
                        ? null
                        : 'Previously matched on ${MaterialLocalizations.of(context).formatMediumDate(p.previousMatchAt!.toLocal())}',
                    onTap: () => _openProfile(index, fp),
                    onSendInterest: action.onTap,
                    onBookmark: () => _handleBookmark(index, fp),
                  ),
                ),

                // Wild-card label — "Someone you might connect with"
                if (fp.isWildCard)
                  Positioned(
                    top: -12,
                    left: AppDimensions.space12,
                    right: AppDimensions.space12,
                    child: Center(
                      child: _WildCardLabel(),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    return Stack(
      children: [
        carousel,
        if (feedState.status == FeedStatus.refreshing)
          Positioned(
            top: 0,
            left: AppDimensions.space40,
            right: AppDimensions.space40,
            child: LinearProgressIndicator(
              minHeight: 1.5,
              color: AppColors.champagneGold,
              backgroundColor: AppColors.transparent,
            ),
          ),
      ],
    );
  }

  _DiscoveryProfileAction _profileAction(
    int index,
    FeedProfile profile,
    InterestsState interests,
  ) {
    final interaction = interests.interactionWith(profile.profile.id);
    switch (interaction) {
      case ProfileInteractionState.pendingSent:
        return const _DiscoveryProfileAction(label: 'Interest Sent');
      case ProfileInteractionState.pendingReceived:
        return _DiscoveryProfileAction(
          label: 'Review Interest',
          onTap:
              widget.onOpenTab == null ? null : () => widget.onOpenTab?.call(1),
        );
      case ProfileInteractionState.matched:
        return _DiscoveryProfileAction(
          label: 'Open Chat',
          onTap:
              widget.onOpenTab == null ? null : () => widget.onOpenTab?.call(2),
        );
      case ProfileInteractionState.none:
        final cooldownDays = profile.profile.rematchCooldownDaysRemaining;
        if (cooldownDays != null) {
          return _DiscoveryProfileAction(
            label:
                'Rematch in $cooldownDays day${cooldownDays == 1 ? '' : 's'}',
          );
        }
        return _DiscoveryProfileAction(
          label: 'Send Interest',
          onTap: () => _handleSendInterest(index, profile),
        );
    }
  }

  Widget _scaledCard(int index, Widget child) {
    return AnimatedBuilder(
      animation: _pageCtrl,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final page = _pageCtrl.positions.length == 1
            ? (_pageCtrl.page ?? _currentPage.toDouble())
            : _currentPage.toDouble();
        final offset = (index - page).abs();
        final scale = (1.0 - (offset * 0.05)).clamp(0.95, 1.0);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }

  Widget _cardPadding({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space6,
        vertical: AppDimensions.space4,
      ),
      child: child,
    );
  }
}

class _DiscoveryProfileAction {
  const _DiscoveryProfileAction({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class _DiscoveryError extends StatelessWidget {
  const _DiscoveryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(message);
    return SilarahEmptyState(
      visual: SilarahEmptyVisual.connection,
      title: title,
      subtitle: message,
      ctaLabel: 'Try again',
      onCta: onRetry,
    );
  }

  String _titleFor(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('approved') ||
        lower.contains('visible') ||
        lower.contains('complete your profile') ||
        lower.contains('approved profile photo')) {
      return 'Profile not live yet';
    }
    if (lower.contains('sign in')) return 'Sign in required';
    return 'Connection paused';
  }
}

// ── Wild-card Label ───────────────────────────────────────────

class _WildCardLabel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space12,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
        border:
            Border.all(color: AppColors.champagneGold.withValues(alpha: 0.5)),
      ),
      child: Text(
        l10n.discovery_wildcard_label,
        style: AppTypography.caption.copyWith(
          color: AppColors.champagneGold,
          fontSize: 11,
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
    final l10n = AppLocalizations.of(context);
    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space10,
        vertical: AppDimensions.space4,
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
        l10n.discovery_remaining_profiles(remaining.toString()),
        style: AppTypography.caption.copyWith(
          color: remaining <= 3 ? AppColors.errorRed : AppColors.slateMist,
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
    return NotificationBellButton(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NotificationsScreen(),
          ),
        );
      },
    );
  }
}

// ── Initial Shimmer (3-card stack) ────────────────────────────

class _InitialShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.space6,
        vertical: AppDimensions.space4,
      ),
      child: SilarahProfileCardShimmer(),
    );
  }
}

// ── Empty Feed State ──────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({
    required this.hasActiveFilters,
    required this.onRefresh,
    required this.onClearFilters,
  });

  final bool hasActiveFilters;
  final VoidCallback onRefresh;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SilarahEmptyState(
      visual: SilarahEmptyVisual.discovery,
      title: l10n.discovery_empty_title,
      subtitle: l10n.discovery_empty_subtitle,
      ctaLabel: hasActiveFilters ? 'Clear Filters' : 'Refresh Profiles',
      onCta: hasActiveFilters ? onClearFilters : onRefresh,
    );
  }
}

// ── M9: Free-Tier Browse Limit ────────────────────────────────
class _FreeTierLimitReached extends StatelessWidget {
  const _FreeTierLimitReached({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.goldGlow,
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                Icons.lock_clock_rounded,
                color: AppColors.champagneGold,
                size: 44,
              ),
            ),
            const SizedBox(height: AppDimensions.space28),
            Text(
              l10n.discovery_limit_title,
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppDimensions.space12),
            Text(
              l10n.discovery_limit_subtitle,
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.space24),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24,
                  vertical: AppDimensions.space14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.champagneGold,
                  borderRadius:
                      BorderRadius.circular(AppDimensions.radiusButton),
                ),
                child: Text(l10n.discovery_limit_button,
                    style: AppTypography.button),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
