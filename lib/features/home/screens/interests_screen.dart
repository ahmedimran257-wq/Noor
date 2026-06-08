// lib/features/home/screens/interests_screen.dart
// ============================================================
// NOOR — Interests Inbox (Items 17, 18, 19, 21, 22, 26)
//
// Items implemented here:
//   17 — Daily limit counter banner in Sent tab header (male only)
//   18 — Expiry countdown on pending received cards
//   19 — Withdraw confirm dialog on Sent tab
//   21 — Match modal: remove 48h note, show "Bismillah" CTA
//   22 — All cooling period text removed
//   26 — NoorEmptyState on both tabs
// ============================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/noor_empty_state.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'chat_screen.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final TabController _tabCtrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ── Mutual match ceremony modal (Item 21 + 22) ───────────

  void _showMutualMatchModal(MockProfile profile) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      barrierColor: AppColors.obsidianNight.withValues(alpha: 0.85),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space24),
            child: Material(
              color:        Colors.transparent,
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.space32),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border:       Border.all(color: AppColors.goldBorder, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color:       AppColors.goldGlow,
                      blurRadius:  40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Overlapping avatars + heart centre badge
                    _MatchAvatarPair(),
                    const SizedBox(height: AppDimensions.space24),

                    // Gold title
                    Text(
                      'Mabrook!',
                      style: AppTypography.screenTitle.copyWith(
                          color: AppColors.champagneGold, fontSize: 28),
                    ),
                    const SizedBox(height: AppDimensions.space4),
                    Text(
                      'You have a mutual interest.',
                      style: AppTypography.screenTitle.copyWith(
                          color: AppColors.pearlWhite, fontSize: 18),
                    ),
                    const SizedBox(height: AppDimensions.space12),

                    // Bismillah subtitle (Item 21 — replaces 48h note)
                    Text(
                      'Say bismillah and begin a conversation.',
                      style: AppTypography.bodyMuted.copyWith(height: 1.6),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.space28),

                    // Message Now CTA — gold, full width
                    SizedBox(
                      width:  double.infinity,
                      height: AppDimensions.buttonHeight,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.champagneGold,
                          foregroundColor: AppColors.obsidianNight,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppDimensions.radiusButton),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final chatCubit = context.read<ChatCubit>();
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          final convId = await chatCubit.openOrCreateConversation(
                              profile.id, profile.firstName, profile.lastNameInitial);
                          if (convId.isNotEmpty) {
                            navigator.push(
                              PageRouteBuilder(
                                transitionDuration: AppDimensions.durationReveal,
                                pageBuilder: (ctx, anim, _) => FadeTransition(
                                  opacity: anim,
                                  child: ChatScreen(conversationId: convId),
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Message Now',
                            style: AppTypography.button),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space12),

                    // Maybe later
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Maybe later',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.slateMist),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Withdraw confirm dialog (Item 19) ─────────────────────

  void _showWithdrawDialog(InterestEntry entry) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Text('Withdraw interest?',
            style: AppTypography.bodyMedium.copyWith(
                color: AppColors.pearlWhite, fontSize: 17)),
        content: const Text(
          "They won't be notified.",
          style: AppTypography.bodyMuted,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTypography.caption.copyWith(
                    color: AppColors.slateMist)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<InterestsCubit>().withdrawInterest(entry.id);
            },
            child: Text('Withdraw',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.softCoral, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocConsumer<InterestsCubit, InterestsState>(
      listenWhen: (prev, curr) =>
          !prev.limitError && curr.limitError,
      listener: (context, state) {
        // Item 17: show SnackBar when daily limit is hit
        final isSubscribed = state.dailyLimit >= 20;
        final msg = isSubscribed
            ? 'Daily limit reached. Resets at midnight.'
            : 'Daily limit reached. Resets at midnight. '
              'Subscribe for 20 interests per day.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg, style: AppTypography.body),
            backgroundColor: AppColors.surfaceGlassHover,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        context.read<InterestsCubit>().clearLimitError();
      },
      builder: (context, state) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24, AppDimensions.space16,
                AppDimensions.space24, 0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(AppLocalizations.of(context).interests_title, style: AppTypography.screenTitle),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: TabBar(
                  controller:          _tabCtrl,
                  labelStyle:          AppTypography.bodyMedium.copyWith(fontSize: 14),
                  unselectedLabelStyle: AppTypography.bodyMuted.copyWith(fontSize: 14),
                  labelColor:          AppColors.champagneGold,
                  unselectedLabelColor: AppColors.slateMist,
                  indicatorSize:       TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color:        AppColors.champagneGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                        AppDimensions.radiusButton - 2),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(AppLocalizations.of(context).interests_tab_received),
                          if (state.pendingReceived.isNotEmpty) ...[
                            const SizedBox(width: AppDimensions.space6),
                            _CountBadge(count: state.pendingReceived.length),
                          ],
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(AppLocalizations.of(context).interests_tab_sent),
                          if (state.sent.any((e) =>
                              e.effectiveStatus == InterestStatus.accepted)) ...[
                            const SizedBox(width: AppDimensions.space6),
                            const _NewBadge(),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.space16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Received tab ──────────────────────────
                  state.displayReceived.isEmpty
                      ? const NoorEmptyState(
                          icon:     Icons.favorite_border_rounded,
                          title:    'No interests yet',
                          subtitle: 'When someone sends you an interest it appears here.',
                        )
                      : _ReceivedList(
                          entries:   state.displayReceived,
                          onAccept:  (entry) {
                            context
                                .read<InterestsCubit>()
                                .acceptInterest(entry.id);
                            _showMutualMatchModal(entry.profile);
                          },
                          onDecline: (entry) {
                            context
                                .read<InterestsCubit>()
                                .declineInterest(entry.id);
                          },
                        ),

                  // ── Sent tab ──────────────────────────────
                  Column(
                    children: [
                      // Item 17: daily counter banner (male users only)
                      // In production, check gender from AuthCubit.
                      _DailyLimitBanner(state: state),

                      Expanded(
                        child: state.sent.isEmpty
                            ? const NoorEmptyState(
                                icon:     Icons.send_outlined,
                                title:    "You haven't sent any interests",
                                subtitle: 'Browse profiles and send your first interest.',
                              )
                            : _SentList(
                                entries:    state.sent,
                                onWithdraw: (entry) =>
                                    _showWithdrawDialog(entry),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Daily Limit Banner (Item 17) ──────────────────────────────

class _DailyLimitBanner extends StatelessWidget {
  const _DailyLimitBanner({required this.state});
  final InterestsState state;

  @override
  Widget build(BuildContext context) {
    // Blueprint: Women send interests free — no limit, no banner.
    // We use 9999 as the "unlimited" sentinel for female users.
    if (state.dailyLimit >= 9999) return const SizedBox.shrink();

    final sent  = state.interestsSentToday;
    final limit = state.dailyLimit;
    final frac  = limit > 0 ? (sent / limit).clamp(0.0, 1.0) : 0.0;
    final atLimit = state.isDailyLimitReached;


    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space24, 0, AppDimensions.space24, AppDimensions.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                atLimit
                    ? Icons.block_rounded
                    : Icons.favorite_outline_rounded,
                size:  14,
                color: atLimit
                    ? AppColors.softCoral
                    : AppColors.champagneGold,
              ),
              const SizedBox(width: AppDimensions.space6),
              Text(
                '$sent of $limit interests sent today',
                style: AppTypography.caption.copyWith(
                  color: atLimit
                      ? AppColors.softCoral
                      : AppColors.champagneGold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space6),
          // Gold progress bar (3px height)
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value:            frac,
              minHeight:        3,
              backgroundColor:  AppColors.surfaceGlassHover,
              valueColor: AlwaysStoppedAnimation<Color>(
                atLimit
                    ? AppColors.softCoral
                    : AppColors.champagneGold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar pair widget for match modal ───────────────────────

class _MatchAvatarPair extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned(
            left: 30,
            child: _Avatar(border: AppColors.champagneGold),
          ),
          const Positioned(
            right: 30,
            child: _Avatar(border: AppColors.champagneGold),
          ),
          // Heart badge
          Container(
            padding: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color:  AppColors.surfaceElevated,
              shape:  BoxShape.circle,
              border: Border.all(color: AppColors.champagneGold, width: 2),
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: AppColors.champagneGold,
              size:  20,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.border});
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  60,
      height: 60,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  AppColors.surfaceGlassHover,
        border: Border.all(color: border, width: 2),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: AppColors.slateMist,
        size:  30,
      ),
    );
  }
}

// ── Received list ─────────────────────────────────────────────

class _ReceivedList extends StatelessWidget {
  const _ReceivedList({
    required this.entries,
    required this.onAccept,
    required this.onDecline,
  });
  final List<InterestEntry>          entries;
  final ValueChanged<InterestEntry>  onAccept;
  final ValueChanged<InterestEntry>  onDecline;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space24,
        vertical:   AppDimensions.space4,
      ),
      itemCount:      entries.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.space12),
      itemBuilder: (_, i) {
        final entry = entries[i];
        return _ReceivedTile(
          entry:     entry,
          onAccept:  () => onAccept(entry),
          onDecline: () => onDecline(entry),
        );
      },
    );
  }
}

class _ReceivedTile extends StatelessWidget {
  const _ReceivedTile({
    required this.entry,
    required this.onAccept,
    required this.onDecline,
  });
  final InterestEntry entry;
  final VoidCallback  onAccept;
  final VoidCallback  onDecline;

  @override
  Widget build(BuildContext context) {
    final p          = entry.profile;
    final status     = entry.effectiveStatus;
    final isAccepted = status == InterestStatus.accepted;
    final isDeclined = status == InterestStatus.declined;
    final isPending  = status == InterestStatus.pending;

    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isAccepted
              ? AppColors.goldBorder
              : isDeclined
                  ? AppColors.cardBorder.withValues(alpha: 0.5)
                  : AppColors.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: avatar + name/city + time
          Row(
            children: [
              _CircleAvatar(
                borderColor: isAccepted
                    ? AppColors.champagneGold
                    : AppColors.cardBorder,
                opacity: isDeclined ? 0.5 : 1.0,
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.firstName} ${p.lastNameInitial}.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: isDeclined
                            ? AppColors.slateMist
                            : AppColors.pearlWhite,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space2),
                    Text(
                      '${p.age} · ${p.cityName}',
                      style: AppTypography.caption,
                    ),
                    if (p.occupation != null)
                      Text(p.occupation!, style: AppTypography.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(entry.timeAgo, style: AppTypography.caption),
                  const SizedBox(height: AppDimensions.space4),
                  if (isAccepted)
                    const _StatusPill(
                        label: '✓ Matched', color: AppColors.champagneGold),
                  if (isDeclined)
                    const _StatusPill(label: 'Declined', color: AppColors.slateMist),
                ],
              ),
            ],
          ),

          // G3: Display sender's interest note
          if (entry.note != null && entry.note!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color:        AppColors.champagneGold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border:       Border.all(
                  color: AppColors.goldBorder.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.format_quote_rounded,
                      color: AppColors.champagneGold.withValues(alpha: 0.5),
                      size: 16),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: Text(
                      entry.note!,
                      style: AppTypography.caption.copyWith(
                        color:  AppColors.pearlWhite.withValues(alpha: 0.85),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Item 18: Expiry countdown — shown below buttons for pending interests
          if (isPending) _ExpiryRow(entry: entry),

          // Action buttons — pending only
          if (isPending) ...[
            const SizedBox(height: AppDimensions.space14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.cardBorder),
                      foregroundColor: AppColors.slateMist,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onDecline();
                    },
                    child: Text(AppLocalizations.of(context).interests_button_decline, style: AppTypography.bodyMuted),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.champagneGold,
                      foregroundColor: AppColors.obsidianNight,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onAccept();
                    },
                    child: Text(AppLocalizations.of(context).interests_button_accept, style: AppTypography.button),
                  ),
                ),
              ],
            ),
          ],

          // Message CTA — accepted only
          if (isAccepted) ...[
            const SizedBox(height: AppDimensions.space12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.champagneGold),
                  foregroundColor: AppColors.champagneGold,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusButton),
                  ),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text('Message ${p.firstName}',
                    style: AppTypography.buttonSecondary),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final chatCubit = context.read<ChatCubit>();
                  final navigator = Navigator.of(context);
                  final convId = await chatCubit.openOrCreateConversation(
                      p.id, p.firstName, p.lastNameInitial);
                  if (convId.isNotEmpty) {
                    navigator.push(
                      PageRouteBuilder(
                        transitionDuration: AppDimensions.durationReveal,
                        pageBuilder: (ctx, anim, _) => FadeTransition(
                          opacity: anim,
                          child: ChatScreen(conversationId: convId),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Item 18: Expiry countdown row ─────────────────────────────

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({required this.entry});
  final InterestEntry entry;

  @override
  Widget build(BuildContext context) {
    final hours = entry.hoursRemaining;
    if (hours == null || hours > 72) return const SizedBox.shrink();

    final isUrgent = hours < 24;
    final color    = isUrgent ? AppColors.softCoral : AppColors.expiryAmber;
    final icon     = isUrgent
        ? Icons.warning_amber_rounded
        : Icons.access_time_rounded;
    final text     = isUrgent
        ? 'Expires today'
        : 'Expires in ${entry.daysRemaining} day${entry.daysRemaining == 1 ? '' : 's'}';

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: AppDimensions.space4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color:      color,
              fontWeight: FontWeight.w600,
              fontSize:   11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sent list ─────────────────────────────────────────────────

class _SentList extends StatelessWidget {
  const _SentList({
    required this.entries,
    required this.onWithdraw,
  });
  final List<InterestEntry>         entries;
  final ValueChanged<InterestEntry> onWithdraw;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space24,
        vertical:   AppDimensions.space4,
      ),
      itemCount:      entries.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppDimensions.space12),
      itemBuilder: (_, i) {
        final entry = entries[i];
        return _SentTile(
          entry:      entry,
          onWithdraw: () => onWithdraw(entry),
        );
      },
    );
  }
}

class _SentTile extends StatelessWidget {
  const _SentTile({required this.entry, required this.onWithdraw});
  final InterestEntry entry;
  final VoidCallback  onWithdraw;

  @override
  Widget build(BuildContext context) {
    final p           = entry.profile;
    final status      = entry.effectiveStatus;
    final isPending   = status == InterestStatus.pending;
    final isAccepted  = status == InterestStatus.accepted;
    final isExpired   = status == InterestStatus.expired;
    final isWithdrawn = status == InterestStatus.withdrawn;

    return AnimatedContainer(
      duration: AppDimensions.durationTransition,
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border: Border.all(
          color: isAccepted
              ? AppColors.goldBorder
              : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          _CircleAvatar(
            borderColor: isAccepted
                ? AppColors.champagneGold
                : AppColors.cardBorder,
            opacity: (isWithdrawn || isExpired) ? 0.5 : 1.0,
          ),
          const SizedBox(width: AppDimensions.space12),

          // Name + info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.firstName} ${p.lastNameInitial}.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: (isWithdrawn || isExpired)
                        ? AppColors.slateMist
                        : AppColors.pearlWhite,
                  ),
                ),
                const SizedBox(height: AppDimensions.space2),
                Text('${p.age} · ${p.cityName}',
                    style: AppTypography.caption),
              ],
            ),
          ),

          // Right side: time + status pill / withdraw
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(entry.timeAgo, style: AppTypography.caption),
              const SizedBox(height: AppDimensions.space6),

              if (isPending)
                // Item 19: Withdraw text button (AppColors.softCoral)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onWithdraw();
                  },
                  child: Text(
                    'Withdraw',
                    style: AppTypography.caption.copyWith(
                      color:      AppColors.softCoral,
                      fontSize:   12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else if (isAccepted)
                const _StatusPill(
                    label: '✓ Accepted', color: AppColors.champagneGold)
              else if (isExpired)
                const _StatusPill(label: 'Expired', color: AppColors.slateMist)
              else if (isWithdrawn)
                const _StatusPill(label: 'Withdrawn', color: AppColors.slateMist)
              else
                const _StatusPill(label: 'Declined', color: AppColors.softCoral),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────

class _CircleAvatar extends StatelessWidget {
  const _CircleAvatar({
    required this.borderColor,
    this.opacity = 1.0,
  });
  final Color  borderColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width:  52,
        height: 52,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          color:  AppColors.surfaceGlassHover,
          border: Border.all(color: borderColor),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.slateMist,
          size:  28,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});
  final String label;
  final Color  color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical:   AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color:    color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        AppColors.champagneGold,
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
      ),
      child: Text('new',
          style: AppTypography.badge.copyWith(fontSize: 10)),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:        AppColors.champagneGold,
        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
      ),
      child: Text('$count', style: AppTypography.badge),
    );
  }
}
