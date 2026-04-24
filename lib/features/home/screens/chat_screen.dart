// lib/features/home/screens/chat_screen.dart
// ============================================================
// NOOR — Individual Chat Screen (Item 25 — Persistent Openers)
//
// Blueprint (Part 8, Conversations):
//   • Sent messages: gold-tinted bubble, right side
//   • Received messages: surface color, left side
//   • Timestamps hidden by default → tap to reveal
//   • First message: 3 suggested openers in italic Playfair
//   • Text-only input (no photos/voice per Phase 1)
//   • Status icons: queued (clock) / sent (✓) / delivered (✓✓)
//
// Item 25:
//   _showSuggestedOpeners: true until first message sent.
//   Persists dismissal per conversationId in SharedPreferences.
//   Key: 'openers_dismissed_$conversationId'
//   Animates out with SizeTransition (300ms collapse).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/cubits/chat/chat_cubit.dart';
import '../../../core/cubits/chat/chat_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';

// ── Blueprint: Islamic suggested openers ─────────────────────

const _kSuggestedOpeners = [
  'Assalamu Alaikum! I came across your profile and was genuinely impressed. May I introduce myself?',
  'Bismillah. Your profile caught my attention. I would love to learn more about you.',
  'Assalamu Alaikum. I believe we share similar values. Would you be open to getting to know each other?',
  'Assalamu Alaikum! Your dedication to deen resonated with me. May Allah bless this conversation with goodness.',
];

// ─────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputCtrl   = TextEditingController();
  final ScrollController       _scrollCtrl = ScrollController();
  bool _canSend = false;

  // Item 25: openers visibility + animation
  bool _showSuggestedOpeners  = true;
  late final AnimationController _openersAnim;
  late final Animation<double>   _openersSize;

  @override
  void initState() {
    super.initState();
    _openersAnim = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 300),
      value:    1.0, // starts fully visible
    );
    _openersSize = CurvedAnimation(
      parent: _openersAnim,
      curve:  Curves.easeInOut,
    );
    _inputCtrl.addListener(() {
      final can = _inputCtrl.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatCubit>().markRead(widget.conversationId);
      _scrollToBottom();
      _loadOpenersDismissed();
    });
  }

  Future<void> _loadOpenersDismissed() async {
    final prefs     = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(
        'openers_dismissed_${widget.conversationId}') ?? false;
    if (!mounted) return;
    if (dismissed) {
      setState(() => _showSuggestedOpeners = false);
      _openersAnim.value = 0.0;
    }
  }

  Future<void> _dismissOpeners() async {
    if (!_showSuggestedOpeners) return;
    await _openersAnim.reverse();
    if (!mounted) return;
    setState(() => _showSuggestedOpeners = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        'openers_dismissed_${widget.conversationId}', true);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _openersAnim.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animated) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: AppDimensions.durationTransition,
            curve:    Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    setState(() => _canSend = false);
    HapticFeedback.selectionClick();
    // Item 25: dismiss openers on first send
    _dismissOpeners();
    await context.read<ChatCubit>().sendMessage(widget.conversationId, text);
    _scrollToBottom(animated: true);
  }

  void _useOpener(String text) {
    _inputCtrl.text = text;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    setState(() => _canSend = true);
    // Item 25: dismiss openers when a suggestion is tapped
    _dismissOpeners();
  }

  // ── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (prev, curr) {
        final prevConv = prev.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;
        final currConv = curr.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;
        return prevConv?.messages.length != currConv?.messages.length;
      },
      listener: (_, __) => _scrollToBottom(animated: true),
      builder: (context, state) {
        final conv = state.conversations
            .where((c) => c.id == widget.conversationId)
            .firstOrNull;

        if (conv == null) {
          return const Scaffold(
            backgroundColor: AppColors.obsidianNight,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final hasMessages = conv.messages.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.obsidianNight,
          appBar: _ChatAppBar(
            name:  conv.matchName,
            initial: conv.matchLastInitial,
          ),
          body: Column(
            children: [
              // ── Messages ─────────────────────────────────
              Expanded(
                child: hasMessages
                    ? ListView.builder(
                        controller:  _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.space16,
                          vertical:   AppDimensions.space12,
                        ),
                        itemCount: conv.messages.length,
                        itemBuilder: (_, i) {
                          final msg  = conv.messages[i];
                          final prev = i > 0 ? conv.messages[i - 1] : null;
                          final sameAsPrev =
                              prev != null && prev.isMe == msg.isMe;
                          return _MessageBubble(
                            message:    msg,
                            sameAsPrev: sameAsPrev,
                            onTap: () => context.read<ChatCubit>()
                                .toggleTimestamp(
                                    widget.conversationId, msg.id),
                          );
                        },
                      )
                    : _SuggestedOpenersArea(
                        showOpeners: _showSuggestedOpeners,
                        sizeAnim:    _openersSize,
                        onSelect:    _useOpener,
                      ),
              ),

              // ── Input bar ────────────────────────────────
              _InputBar(
                controller: _inputCtrl,
                canSend:    _canSend,
                onSend:     _sendMessage,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Suggested Openers Area (Item 25) ─────────────────────────

class _SuggestedOpenersArea extends StatelessWidget {
  const _SuggestedOpenersArea({
    required this.showOpeners,
    required this.sizeAnim,
    required this.onSelect,
  });
  final bool                showOpeners;
  final Animation<double>   sizeAnim;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Begin with Bismillah', style: AppTypography.tagline),
        const SizedBox(height: AppDimensions.space20),

        // Collapses via SizeTransition when dismissed (Item 25)
        SizeTransition(
          sizeFactor:    sizeAnim,
          axisAlignment: -1,
          child: SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection:  Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.space24),
              itemCount:        _kSuggestedOpeners.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppDimensions.space12),
              itemBuilder: (_, i) => _OpenerCard(
                text:     _kSuggestedOpeners[i],
                onSelect: () => onSelect(_kSuggestedOpeners[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── AppBar ────────────────────────────────────────────────────

class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.name, required this.initial});
  final String name;
  final String initial;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height:     64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:  AppColors.surfaceGlass,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.pearlWhite,
                  size:  AppDimensions.iconSizeMedium),
            ),
          ),

          // Avatar
          Container(
            width:  40,
            height: 40,
            decoration: BoxDecoration(
              shape:  BoxShape.circle,
              color:  AppColors.surfaceGlassHover,
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: const Icon(Icons.person_outline_rounded,
                color: AppColors.slateMist, size: 22),
          ),
          const SizedBox(width: AppDimensions.space12),

          // Name
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name $initial.',
                  style: AppTypography.bodyMedium,
                  maxLines: 1,
                ),
                Text('Matched · Messaging unlocked',
                    style: AppTypography.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),

          // More options
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              width:  40,
              height: 40,
              decoration: BoxDecoration(
                color:  AppColors.surfaceGlass,
                shape:  BoxShape.circle,
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: const Icon(Icons.more_vert_rounded,
                  color: AppColors.slateMist,
                  size:  AppDimensions.iconSizeMedium),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Opener Card ───────────────────────────────────────────────

class _OpenerCard extends StatelessWidget {
  const _OpenerCard({required this.text, required this.onSelect});
  final String       text;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect();
      },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppDimensions.space14),
        decoration: BoxDecoration(
          color:        AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border:       Border.all(color: AppColors.goldBorder),
        ),
        child: Text(
          text,
          style: AppTypography.bio.copyWith(fontSize: 13),
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.sameAsPrev,
    required this.onTap,
  });
  final ChatMessage message;
  final bool        sameAsPrev;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;

    final radius = BorderRadius.only(
      topLeft:     Radius.circular(isMe ? AppDimensions.radiusButton : 6),
      topRight:    Radius.circular(isMe ? 6 : AppDimensions.radiusButton),
      bottomLeft:  const Radius.circular(AppDimensions.radiusButton),
      bottomRight: const Radius.circular(AppDimensions.radiusButton),
    );

    return Padding(
      padding: EdgeInsets.only(
        top:    sameAsPrev ? AppDimensions.space4 : AppDimensions.space12,
        bottom: AppDimensions.space2,
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bubble
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space14,
                      vertical:   AppDimensions.space10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppColors.champagneGold.withValues(alpha: 0.15)
                          : AppColors.surfaceGlassHover,
                      borderRadius: radius,
                      border: Border.all(
                        color: isMe
                            ? AppColors.goldBorder
                            : AppColors.cardBorder,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      message.text,
                      style: AppTypography.chatMessage,
                    ),
                  ),
                ),

                // Status icon (sent messages only)
                if (isMe) ...[
                  const SizedBox(width: AppDimensions.space4),
                  _StatusIcon(status: message.status),
                ],
              ],
            ),
          ),

          // Timestamp — hidden by default, revealed on tap
          AnimatedSize(
            duration: AppDimensions.durationTransition,
            child: message.isTimestampVisible
                ? Padding(
                    padding: const EdgeInsets.only(
                      top:  AppDimensions.space4,
                      left: AppDimensions.space4,
                      right: AppDimensions.space4,
                    ),
                    child: Text(
                      _formatTime(message.sentAt),
                      style: AppTypography.chatTimestamp,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '$h:$m';
    if (diff.inDays == 1) return 'Yesterday $h:$m';
    return '${dt.day}/${dt.month} $h:$m';
  }
}

// ── Message status icon ───────────────────────────────────────

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});
  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case MessageStatus.queued:
        return const Icon(Icons.access_time_rounded,
            color: AppColors.slateMist, size: 12);
      case MessageStatus.sent:
        return const Icon(Icons.check_rounded,
            color: AppColors.slateMist, size: 12);
      case MessageStatus.delivered:
        return const Icon(Icons.done_all_rounded,
            color: AppColors.slateMist, size: 12);
      case MessageStatus.read:
        return const Icon(Icons.done_all_rounded,
            color: AppColors.champagneGold, size: 12);
    }
  }
}

// ── Input bar ─────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.canSend,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool                  canSend;
  final VoidCallback          onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16,
        AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder),
        ),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color:        AppColors.surfaceGlass,
                borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                border:       Border.all(color: AppColors.cardBorder),
              ),
              child: TextField(
                controller:  controller,
                maxLines:    null,
                style:       AppTypography.chatMessage,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText:       'Type a message…',
                  hintStyle:      AppTypography.inputLabel,
                  border:         InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.space14,
                    vertical:   AppDimensions.space10,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.space10),

          // Send button
          GestureDetector(
            onTap: canSend ? onSend : null,
            child: AnimatedContainer(
              duration: AppDimensions.durationTransition,
              width:  48,
              height: 48,
              decoration: BoxDecoration(
                color: canSend
                    ? AppColors.champagneGold
                    : AppColors.surfaceGlassHover,
                shape: BoxShape.circle,
                border: Border.all(
                  color: canSend
                      ? AppColors.champagneGold
                      : AppColors.cardBorder,
                ),
              ),
              child: Icon(
                Icons.send_rounded,
                color: canSend
                    ? AppColors.obsidianNight
                    : AppColors.slateMist,
                size: AppDimensions.iconSizeMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
