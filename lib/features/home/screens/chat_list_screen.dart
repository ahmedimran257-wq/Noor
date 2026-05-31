// lib/features/home/screens/chat_list_screen.dart
// ============================================================
// NOOR — Chat List (Step 8 — Complete)
//
// Blueprint (Part 8, Conversations):
//   • Sorted by most recent message
//   • Unread → gold left border + heavier name weight + gold badge
//   • Avatar placeholder + name + last message preview + time
//   • Empty state with encouraging message
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/auth/auth_cubit.dart';
import '../../../core/cubits/auth/auth_state.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/chat/chat_state.dart';
import '../../../core/cubits/subscription/subscription_cubit.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import 'chat_screen.dart';
import 'paywall_gate_screen.dart';


class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final conversations = state.sortedConversations;

        return Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24, AppDimensions.space16,
                AppDimensions.space24, AppDimensions.space16,
              ),
              child: Row(
                children: [
                  const Text('Messages', style: AppTypography.screenTitle),
                  const Spacer(),
                  // Total unread badge on header
                  if (state.totalUnread > 0)
                    Container(
                      margin: const EdgeInsets.only(right: AppDimensions.space12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space8, vertical: 3),
                      decoration: BoxDecoration(
                        color:        AppColors.champagneGold,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusTiny),
                      ),
                      child: Text(
                        '${state.totalUnread} unread',
                        style: AppTypography.badge.copyWith(fontSize: 11),
                      ),
                    ),
                  // Search icon — TD3: wrapped in GestureDetector
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          SnackBar(
                            content: const Text('Search coming soon',
                                style: AppTypography.body),
                            backgroundColor: AppColors.surfaceGlassHover,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusButton),
                              side: const BorderSide(
                                  color: AppColors.cardBorder),
                            ),
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
                        Icons.search_rounded,
                        color: AppColors.slateMist,
                        size:  AppDimensions.iconSizeLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ──────────────────────────────────────
            Expanded(
              child: conversations.isEmpty
                  ? const _ChatEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space24,
                        vertical:   AppDimensions.space4,
                      ),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.space8),
                      itemBuilder: (_, i) {
                        final conv = conversations[i];
                        return _ConversationTile(
                          conversation: conv,
                          onTap: () {
                            // ── Blueprint Part 14 / Part 8 ─────────────────
                            // "Non-subscriber men who try to open a chat see:
                            //  'Subscribe to unlock messaging.'"
                            // Gender read from AuthState (set in Step 12 from
                            // Supabase users table; mock default is 'male').
                            final authState = context.read<AuthCubit>().state;
                            final gender = authState is AuthAuthenticated
                                ? (authState.gender ?? 'male')
                                : 'male';
                            final subState =
                                context.read<SubscriptionCubit>().state;

                            if (!subState.canMessage(gender)) {
                              PaywallGateSheet.show(context);
                              return;
                            }

                            context.read<ChatCubit>().markRead(conv.id);
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                transitionDuration:
                                    AppDimensions.durationReveal,
                                pageBuilder: (ctx, animation, _) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child:
                                      ChatScreen(conversationId: conv.id),
                                ),
                              ),
                            );
                          },
                        );
                      },

                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Conversation tile ─────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });
  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    // ClipRRect + Stack solves the Flutter limitation where non-uniform border
    // widths (left=3, others=1) combined with borderRadius prevent children
    // from painting. The gold left accent is now a Positioned strip in a Stack.
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
        child: AnimatedContainer(
          duration: AppDimensions.durationTransition,
          decoration: BoxDecoration(
            color:  AppColors.surfaceGlass,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Stack(
            children: [
              // Gold left accent bar — animates in/out for unread state
              AnimatedPositioned(
                duration: AppDimensions.durationTransition,
                top:    0,
                bottom: 0,
                left:   0,
                width:  hasUnread ? 3.0 : 0.0,
                child: AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  color: hasUnread
                      ? AppColors.champagneGold
                      : Colors.transparent,
                ),
              ),

              // Tile content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  // Shift content right to clear the accent bar
                  hasUnread
                      ? AppDimensions.space16 + 3
                      : AppDimensions.space16,
                  AppDimensions.space16,
                  AppDimensions.space16,
                  AppDimensions.space16,
                ),
                child: Row(
                  children: [
                    // Avatar
                    AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      width:  50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceGlassHover,
                        border: Border.all(
                          color: hasUnread
                              ? AppColors.champagneGold
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppColors.slateMist,
                        size:  26,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),

                    // Name + message preview
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${conversation.matchName} ${conversation.matchLastInitial}.',
                            style: hasUnread
                                ? AppTypography.bodyMedium
                                : AppTypography.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.space4),
                          Text(
                            conversation.lastMessagePreview,
                            style: AppTypography.caption.copyWith(
                              fontWeight: hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                              color: hasUnread
                                  ? AppColors.pearlWhite.withValues(alpha: 0.7)
                                  : AppColors.slateMist,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space8),

                    // Time + unread count badge
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          conversation.lastMessageTime,
                          style: AppTypography.caption.copyWith(
                            color: hasUnread
                                ? AppColors.champagneGold
                                : AppColors.slateMist,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.space6),
                        if (hasUnread)
                          Container(
                            width:  22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.champagneGold,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${conversation.unreadCount}',
                                style: AppTypography.badge.copyWith(
                                    fontSize: 11),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 22),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

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
                color:  AppColors.surfaceGlass,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.goldBorder),
                boxShadow: const [
                  BoxShadow(
                    color:       AppColors.goldGlow,
                    blurRadius:  24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppColors.champagneGold,
                size:  44,
              ),
            ),
            const SizedBox(height: AppDimensions.space28),
            Text(
              'No conversations yet',
              style: AppTypography.screenTitle.copyWith(fontSize: 22),
            ),
            const SizedBox(height: AppDimensions.space12),
            const Text(
              'Accept an interest or have yours\naccepted to begin a conversation.',
              style: AppTypography.bodyMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

