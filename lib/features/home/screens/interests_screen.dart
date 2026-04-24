// lib/features/home/screens/interests_screen.dart
// ============================================================
// NOOR — Interests Inbox (Step 7 — Complete)
//
// Blueprint (Part 8):
//   • Two tabs: Received / Sent
//   • Received: avatar, name, age, city, time sent
//     — Accept (gold) / Decline (outlined) buttons
//     — Accepted → "Message" CTA (chat unlocked)
//   • Sent: status pill (Pending / Accepted / Declined / Expired)
//     — Withdraw button for pending
//   • Mutual match modal: overlapping avatars + heart badge
//     + 48h reflection note + "Message Now" CTA
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
import 'chat_screen.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key});

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

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

  // ── Mutual match ceremony modal ───────────────────────────

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
                  color:        const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                  border:       Border.all(color: AppColors.goldBorder, width: 1.5),
                  boxShadow: [
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
                      'It\'s a Match!',
                      style: AppTypography.screenTitle.copyWith(
                          color: AppColors.champagneGold, fontSize: 26),
                    ),
                    const SizedBox(height: AppDimensions.space8),

                    Text(
                      'You and ${profile.firstName} can now message each other.',
                      style: AppTypography.bodyMuted,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.space16),

                    // 48-hour reflection note — blueprint requirement
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.space12),
                      decoration: BoxDecoration(
                        color:        AppColors.champagneGold.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        border:       Border.all(color: AppColors.goldBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: AppColors.champagneGold, size: 16),
                          const SizedBox(width: AppDimensions.space8),
                          Expanded(
                            child: Text(
                              'A 48-hour reflection period applies before full messaging unlocks.',
                              style: AppTypography.caption.copyWith(
                                  color: AppColors.champagneGold,
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.space28),

                    // Message Now CTA
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
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop();
                          // Open / create conversation and navigate
                          final convId = context
                              .read<ChatCubit>()
                              .openOrCreateConversation(
                                  profile.firstName, profile.lastNameInitial);
                          Navigator.of(context).push(
                            PageRouteBuilder(
                              transitionDuration: AppDimensions.durationReveal,
                              pageBuilder: (ctx, anim, _) => FadeTransition(
                                opacity: anim,
                                child: ChatScreen(conversationId: convId),
                              ),
                            ),
                          );
                        },
                        child: Text('Message ${profile.firstName}',
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

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InterestsCubit, InterestsState>(
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
                child: Text('Interests', style: AppTypography.screenTitle),
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
                          const Text('Received'),
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
                          const Text('Sent'),
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
                      ? const _EmptyState(
                          icon:    Icons.inbox_rounded,
                          title:   'No interests yet',
                          message:
                              'When someone sends you an interest,\nit will appear here.',
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
                  state.sent.isEmpty
                      ? const _EmptyState(
                          icon:    Icons.send_rounded,
                          title:   'No sent interests',
                          message: 'Interests you send will appear here.',
                        )
                      : _SentList(
                          entries:    state.sent,
                          onWithdraw: (entry) {
                            context
                                .read<InterestsCubit>()
                                .withdrawInterest(entry.id);
                          },
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

// ── Avatar pair widget for match modal ───────────────────────

class _MatchAvatarPair extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 30,
            child: _Avatar(border: AppColors.champagneGold),
          ),
          Positioned(
            right: 30,
            child: _Avatar(border: AppColors.champagneGold),
          ),
          // Heart badge
          Container(
            padding: const EdgeInsets.all(AppDimensions.space8),
            decoration: BoxDecoration(
              color:  const Color(0xFF13131A),
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
                    _StatusPill(
                        label: '✓ Matched', color: AppColors.champagneGold),
                  if (isDeclined)
                    _StatusPill(label: 'Declined', color: AppColors.slateMist),
                ],
              ),
            ],
          ),

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
                    child: Text('Decline', style: AppTypography.bodyMuted),
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
                    child: Text('Accept', style: AppTypography.button),
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
                onPressed: () {
                  HapticFeedback.selectionClick();
                  final convId = context
                      .read<ChatCubit>()
                      .openOrCreateConversation(
                          p.firstName, p.lastNameInitial);
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: AppDimensions.durationReveal,
                      pageBuilder: (ctx, anim, _) => FadeTransition(
                        opacity: anim,
                        child: ChatScreen(conversationId: convId),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
    final p          = entry.profile;
    final status     = entry.effectiveStatus;
    final isPending  = status == InterestStatus.pending;
    final isAccepted = status == InterestStatus.accepted;
    final isExpired  = status == InterestStatus.expired;
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
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onWithdraw();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space10,
                      vertical:   AppDimensions.space4,
                    ),
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceGlassHover,
                      borderRadius:
                          BorderRadius.circular(AppDimensions.radiusTiny),
                      border:       Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      'Withdraw',
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ),
                )
              else if (isAccepted)
                _StatusPill(
                    label: '✓ Accepted', color: AppColors.champagneGold)
              else if (isExpired)
                _StatusPill(label: 'Expired', color: AppColors.slateMist)
              else if (isWithdrawn)
                _StatusPill(label: 'Withdrawn', color: AppColors.slateMist)
              else
                _StatusPill(label: 'Declined', color: AppColors.softCoral),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String   title;
  final String   message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width:  80,
              height: 80,
              decoration: BoxDecoration(
                color:        AppColors.surfaceGlass,
                shape:        BoxShape.circle,
                border:       Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(icon, color: AppColors.slateMist, size: 36),
            ),
            const SizedBox(height: AppDimensions.space20),
            Text(title, style: AppTypography.bodyMedium),
            const SizedBox(height: AppDimensions.space8),
            Text(message,
                style: AppTypography.bodyMuted,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
