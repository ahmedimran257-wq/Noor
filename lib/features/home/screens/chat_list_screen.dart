// lib/features/home/screens/chat_list_screen.dart
// ============================================================
// SILARAH — Chat List (Step 8 — Complete)
//
// Blueprint (Part 8, Conversations):
//   • Sorted by most recent message
//   • Unread → gold left border + heavier name weight + gold badge
//   • Avatar placeholder + name + last message preview + time
//   • Empty state with encouraging message
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/chat/chat_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_curves.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/buttons/silarah_pressable.dart';
import '../../../core/widgets/silarah_empty_state.dart';
import 'chat_screen.dart';
import 'paywall_gate_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  bool _isSearching = false;
  String _searchQuery = '';
  final Set<String> _revealedConversationIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshInbox());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshInbox();
    }
  }

  void _refreshInbox() {
    if (!mounted) return;
    unawaited(context.read<ChatCubit>().loadConversations(showLoading: false));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final query = _searchQuery.trim().toLowerCase();
        final conversations = state.sortedConversations.where((conversation) {
          if (query.isEmpty) return true;
          return conversation.matchName.toLowerCase().contains(query) ||
              conversation.matchLastInitial.toLowerCase().contains(query) ||
              conversation.lastMessagePreview.toLowerCase().contains(query);
        }).toList();

        return Column(
          children: [
            // ── Header ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.space24,
                AppDimensions.space16,
                AppDimensions.space24,
                AppDimensions.space16,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppDimensions.durationTransition,
                      switchInCurve: AppCurves.reveal,
                      switchOutCurve: AppCurves.transition,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.16),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: _isSearching
                          ? TextField(
                              key: const ValueKey('message_search'),
                              autofocus: true,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              style: AppTypography.body,
                              cursorColor: AppColors.champagneGold,
                              decoration: InputDecoration(
                                hintText: 'Search messages',
                                hintStyle: AppTypography.body.copyWith(
                                  color: AppColors.slateMist,
                                ),
                                isDense: true,
                                filled: true,
                                fillColor: AppColors.surfaceGlass,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.space12,
                                  vertical: AppDimensions.space12,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusButton),
                                  borderSide: const BorderSide(
                                      color: AppColors.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusButton),
                                  borderSide: const BorderSide(
                                      color: AppColors.goldBorder),
                                ),
                              ),
                            )
                          : const Align(
                              key: ValueKey('messages_title'),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Messages',
                                style: AppTypography.screenTitle,
                              ),
                            ),
                    ),
                  ),
                  if (_isSearching)
                    const SizedBox(width: AppDimensions.space8)
                  else
                    const Spacer(),
                  // Total unread badge on header
                  if (state.totalUnread > 0)
                    Container(
                      margin:
                          const EdgeInsets.only(right: AppDimensions.space12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.champagneGold,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusTiny),
                      ),
                      child: Text(
                        '${state.totalUnread} unread',
                        style: AppTypography.badge.copyWith(fontSize: 11),
                      ),
                    ),
                  SilarahPressable(
                    semanticLabel:
                        _isSearching ? 'Close search' : 'Search messages',
                    onTap: () {
                      setState(() {
                        if (_isSearching) _searchQuery = '';
                        _isSearching = !_isSearching;
                      });
                    },
                    child: AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      curve: AppCurves.transition,
                      width: AppDimensions.minTouchTarget,
                      height: AppDimensions.minTouchTarget,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusButton),
                        border: Border.all(
                          color: _isSearching
                              ? AppColors.goldBorder
                              : AppColors.cardBorder,
                        ),
                      ),
                      child: Icon(
                        _isSearching
                            ? Icons.close_rounded
                            : Icons.search_rounded,
                        color: AppColors.slateMist,
                        size: AppDimensions.iconSizeLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: conversations.isEmpty
                  ? const _ChatEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.space24,
                        vertical: AppDimensions.space4,
                      ),
                      itemCount: conversations.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppDimensions.space8),
                      itemBuilder: (_, i) {
                        final conv = conversations[i];
                        final shouldReveal =
                            _revealedConversationIds.add(conv.id);
                        return _ConversationEntrance(
                          key: ValueKey('conversation_${conv.id}'),
                          animate: shouldReveal,
                          delay: Duration(milliseconds: (i.clamp(0, 5)) * 45),
                          child: _ConversationTile(
                            conversation: conv,
                            onTap: () async {
                              final navigator = Navigator.of(context);
                              final chatCubit = context.read<ChatCubit>();
                              final access =
                                  await chatCubit.checkChatAccess(conv.id);
                              if (!context.mounted) return;
                              if (access.requiresSubscription) {
                                PaywallGateSheet.show(context);
                                return;
                              }
                              if (!access.allowed) {
                                final message = switch (access.reason) {
                                  ChatAccessReason.suspended =>
                                    'Messaging is temporarily restricted on this account.',
                                  ChatAccessReason.closed =>
                                    'This conversation has ended.',
                                  _ =>
                                    'We could not open this conversation. Please try again.',
                                };
                                ScaffoldMessenger.of(context)
                                  ..clearSnackBars()
                                  ..showSnackBar(SnackBar(
                                    content: Text(message),
                                    behavior: SnackBarBehavior.floating,
                                  ));
                                return;
                              }

                              chatCubit.markRead(conv.id);
                              navigator.push(
                                PageRouteBuilder(
                                  transitionDuration:
                                      AppDimensions.durationReveal,
                                  reverseTransitionDuration:
                                      AppDimensions.durationTransition,
                                  pageBuilder: (ctx, animation, _) =>
                                      FadeTransition(
                                    opacity: CurvedAnimation(
                                      parent: animation,
                                      curve: AppCurves.reveal,
                                    ),
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0.035, 0),
                                        end: Offset.zero,
                                      ).animate(CurvedAnimation(
                                        parent: animation,
                                        curve: AppCurves.reveal,
                                      )),
                                      child:
                                          ChatScreen(conversationId: conv.id),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
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

class _ConversationEntrance extends StatefulWidget {
  const _ConversationEntrance({
    super.key,
    required this.animate,
    required this.delay,
    required this.child,
  });

  final bool animate;
  final Duration delay;
  final Widget child;

  @override
  State<_ConversationEntrance> createState() => _ConversationEntranceState();
}

class _ConversationEntranceState extends State<_ConversationEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = !widget.animate;
    if (widget.animate) {
      Future<void>.delayed(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedSlide(
      offset: _visible || reduceMotion ? Offset.zero : const Offset(0, 0.08),
      duration: reduceMotion ? Duration.zero : AppDimensions.durationReveal,
      curve: AppCurves.reveal,
      child: AnimatedOpacity(
        opacity: _visible || reduceMotion ? 1 : 0,
        duration: reduceMotion ? Duration.zero : AppDimensions.durationReveal,
        curve: AppCurves.reveal,
        child: widget.child,
      ),
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
            color: AppColors.surfaceGlass,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Stack(
            children: [
              // Gold left accent bar — animates in/out for unread state
              AnimatedPositioned(
                duration: AppDimensions.durationTransition,
                top: 0,
                bottom: 0,
                left: 0,
                width: hasUnread ? 3.0 : 0.0,
                child: AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  color:
                      hasUnread ? AppColors.champagneGold : Colors.transparent,
                ),
              ),

              // Tile content
              Padding(
                padding: EdgeInsets.fromLTRB(
                  // Shift content right to clear the accent bar
                  hasUnread ? AppDimensions.space16 + 3 : AppDimensions.space16,
                  AppDimensions.space16,
                  AppDimensions.space16,
                  AppDimensions.space16,
                ),
                child: Row(
                  children: [
                    // Avatar
                    AnimatedContainer(
                      duration: AppDimensions.durationTransition,
                      width: 50,
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
                        size: 26,
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
                              fontWeight:
                                  hasUnread ? FontWeight.w500 : FontWeight.w400,
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
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppColors.champagneGold,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${conversation.unreadCount}',
                                style:
                                    AppTypography.badge.copyWith(fontSize: 11),
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
    return const SilarahEmptyState(
      visual: SilarahEmptyVisual.conversations,
      title: 'No conversations yet',
      subtitle:
          'Accept an interest or have yours accepted to begin a conversation.',
    );
  }
}
