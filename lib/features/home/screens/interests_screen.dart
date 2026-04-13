// lib/features/home/screens/interests_screen.dart
// ============================================================
// NOOR — Interests Inbox
// Two tabs: Received / Sent
// Each row represents an InterestEntry from InterestsCubit.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/interests/interests_cubit.dart';
import '../../../core/cubits/interests/interests_state.dart';
import '../../../core/mock/mock_profiles.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'dart:ui'; // For ImageFilter

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

  void _showMutualMatchModal(MockProfile profile) {
    showDialog(
      context: context,
      barrierColor: AppColors.obsidianNight.withValues(alpha: 0.8),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.space32),
              decoration: BoxDecoration(
                color:        AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
                border:       Border.all(color: AppColors.goldBorder),
                boxShadow: [
                  BoxShadow(
                    color:       AppColors.goldGlow,
                    blurRadius:  32,
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Overlapping Avatars Simulation
                  SizedBox(
                    height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: 40,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.surfaceGlassHover,
                            child: const Icon(Icons.person, color: AppColors.slateMist, size: 40),
                          ),
                        ),
                        Positioned(
                          right: 40,
                          child: CircleAvatar(
                            radius: 40,
                            backgroundColor: AppColors.surfaceGlassHover,
                            child: const Icon(Icons.person, color: AppColors.slateMist, size: 40),
                          ),
                        ),
                        // Heart badge in the middle
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.obsidianNight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.champagneGold, width: 2),
                          ),
                          child: const Icon(Icons.favorite, color: AppColors.champagneGold, size: 24),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppDimensions.space24),
                  
                  Text('Mutual Match!', style: AppTypography.screenTitle.copyWith(color: AppColors.champagneGold)),
                  const SizedBox(height: AppDimensions.space12),
                  
                  Text(
                    'You and ${profile.firstName} can now message each other. Remember the 48-hour reflection period.',
                    style: AppTypography.bodyMuted,
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppDimensions.space32),

                  SizedBox(
                    width: double.infinity,
                    height: AppDimensions.buttonHeight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.champagneGold,
                        foregroundColor: AppColors.obsidianNight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Continue', style: AppTypography.button),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InterestsCubit, InterestsState>(
      builder: (context, state) {
        // We only show pending or explicitly accepted/declined in received tab
        final pendingReceived = state.received.where((e) => e.status == InterestStatus.pending).toList();
        final respondedReceived = state.received.where((e) => e.status == InterestStatus.accepted || e.status == InterestStatus.declined).toList();
        final displayReceived = [...pendingReceived, ...respondedReceived];

        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                AppDimensions.space16,
                AppDimensions.space24,
                0,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('Interests', style: AppTypography.screenTitle),
              ),
            ),

            const SizedBox(height: AppDimensions.space16),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.surfaceGlass,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                  border:       Border.all(color: AppColors.cardBorder),
                ),
                child: TabBar(
                  controller:       _tabCtrl,
                  labelStyle:       AppTypography.bodyMedium.copyWith(fontSize: 14),
                  unselectedLabelStyle: AppTypography.bodyMuted.copyWith(fontSize: 14),
                  labelColor:       AppColors.champagneGold,
                  unselectedLabelColor: AppColors.slateMist,
                  indicatorSize:    TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color:        AppColors.champagneGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton - 2),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  dividerColor:     Colors.transparent,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Received'),
                          const SizedBox(width: AppDimensions.space6),
                          _CountBadge(count: pendingReceived.length),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Sent'),
                          const SizedBox(width: AppDimensions.space6),
                          _CountBadge(count: state.sent.where((e) => e.status == InterestStatus.pending).length),
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
                  // Received
                  displayReceived.isEmpty
                      ? const _EmptyState(
                          icon:    Icons.inbox_rounded,
                          title:   'No interests yet',
                          message: 'When someone sends you an interest,\nit will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space24,
                            vertical:   AppDimensions.space4,
                          ),
                          itemCount: displayReceived.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppDimensions.space12),
                          itemBuilder: (context, i) {
                            final entry = displayReceived[i];
                            return _ReceivedInterestTile(
                              entry: entry,
                              onAccept: () {
                                context.read<InterestsCubit>().acceptInterest(entry.id);
                                _showMutualMatchModal(entry.profile);
                              },
                              onDecline: () {
                                context.read<InterestsCubit>().declineInterest(entry.id);
                              },
                            );
                          },
                        ),

                  // Sent
                  state.sent.isEmpty
                      ? const _EmptyState(
                          icon:    Icons.send_rounded,
                          title:   'No sent interests',
                          message: 'Interests you send will appear here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space24,
                            vertical:   AppDimensions.space4,
                          ),
                          itemCount: state.sent.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppDimensions.space12),
                          itemBuilder: (context, i) {
                            final entry = state.sent[i];
                            return _SentInterestTile(
                              entry: entry,
                              onWithdraw: () {
                                context.read<InterestsCubit>().withdrawInterest(entry.id);
                              },
                            );
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

// ── Received Tile ─────────────────────────────────────────────

class _ReceivedInterestTile extends StatelessWidget {
  const _ReceivedInterestTile({
    required this.entry,
    required this.onAccept,
    required this.onDecline,
  });

  final InterestEntry  entry;
  final VoidCallback   onAccept;
  final VoidCallback   onDecline;

  @override
  Widget build(BuildContext context) {
    final p = entry.profile;
    final isAccepted = entry.status == InterestStatus.accepted;
    final isDeclined = entry.status == InterestStatus.declined;

    return Container(
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
          Row(
            children: [
              // Avatar placeholder
              Container(
                width:  52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:  AppColors.surfaceGlassHover,
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.slateMist,
                  size:  28,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p.firstName} ${p.lastNameInitial}.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: AppDimensions.space2),
                    Text(
                      '${p.age} · ${p.cityName}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              Text(entry.timeAgo, style: AppTypography.caption),
            ],
          ),

          if (!isAccepted && !isDeclined) ...[
            const SizedBox(height: AppDimensions.space12),
            Row(
              children: [
                // Decline
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side:         const BorderSide(color: AppColors.cardBorder),
                      foregroundColor: AppColors.slateMist,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                    ),
                    onPressed: onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppDimensions.space12),
                // Accept
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.champagneGold,
                      foregroundColor: AppColors.obsidianNight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                      ),
                    ),
                    onPressed: onAccept,
                    child: Text('Accept', style: AppTypography.button),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppDimensions.space10),
            AnimatedContainer(
              duration: AppDimensions.durationTransition,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space12,
                vertical:   AppDimensions.space6,
              ),
              decoration: BoxDecoration(
                color: isAccepted
                    ? AppColors.champagneGold.withValues(alpha: 0.12)
                    : AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusChip),
                border: Border.all(
                  color: isAccepted ? AppColors.goldBorder : AppColors.cardBorder,
                ),
              ),
              child: Text(
                isAccepted ? '✓ Accepted — you can now chat' : 'Declined',
                style: AppTypography.caption.copyWith(
                  color: isAccepted ? AppColors.champagneGold : AppColors.slateMist,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Sent Tile ─────────────────────────────────────────────────

class _SentInterestTile extends StatelessWidget {
  const _SentInterestTile({
    required this.entry,
    required this.onWithdraw,
  });
  
  final InterestEntry entry;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final p = entry.profile;
    final isWithdrawn = entry.status == InterestStatus.withdrawn;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width:  52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:  AppColors.surfaceGlassHover,
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.slateMist,
              size:  28,
            ),
          ),
          const SizedBox(width: AppDimensions.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${p.firstName} ${p.lastNameInitial}.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.space2),
                Text('${p.age} · ${p.cityName}', style: AppTypography.caption),
              ],
            ),
          ),
          Column(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
               Text(entry.timeAgo, style: AppTypography.caption),
               const SizedBox(height: AppDimensions.space4),
               
               if (!isWithdrawn)
                InkWell(
                  onTap: onWithdraw,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space8,
                      vertical:   AppDimensions.space4,
                    ),
                    decoration: BoxDecoration(
                      color:        AppColors.surfaceGlassHover,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
                      border:       Border.all(color: AppColors.cardBorder),
                    ),
                    child: Text(
                      'Withdraw',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.slateMist,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
               else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space8,
                    vertical:   AppDimensions.space4,
                  ),
                  decoration: BoxDecoration(
                    color:        AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
                    border:       Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    'Withdrawn',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.slateMist,
                      fontSize: 11,
                    ),
                  ),
                ),
             ],
          ),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────

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
            Text(message, style: AppTypography.bodyMuted, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Count Badge ───────────────────────────────────────────────

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
      child: Text(
        '$count',
        style: AppTypography.badge,
      ),
    );
  }
}
