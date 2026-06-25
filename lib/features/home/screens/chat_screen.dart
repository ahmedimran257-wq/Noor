// lib/features/home/screens/chat_screen.dart
// ============================================================
// MITHAQ — Individual Chat Screen
// Phase 2: Respectful Closure ("End Match") feature added.
//   • Three-dot menu → "End Match" option
//   • _EndMatchSheet: 5 pre-written Islamic closure messages
//   • Closed conversation shows banner + disables input
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
import '../../../core/widgets/animations/spring_keyboard_padding.dart';

/// G12: Profile-aware openers — include the match's name.
List<String> _buildOpeners(String name) => [
  'Assalamu Alaikum $name! I came across your profile and was genuinely impressed. May I introduce myself?',
  'Bismillah. Your profile caught my attention, $name. I would love to learn more about you.',
  'Assalamu Alaikum $name. I believe we share similar values. Would you be open to getting to know each other?',
  'Assalamu Alaikum $name! Your dedication to deen resonated with me. May Allah bless this conversation with goodness.',
];

// Pre-written Islamic closure messages
const _kClosureMessages = [
  'Assalamu Alaikum. After thoughtful reflection, I feel this may not be the right match for us. I sincerely wish you all the best and pray that Allah blesses you with a wonderful partner. JazakAllah khair.',
  'Assalamu Alaikum. I wanted to be honest and respectful with you. I do not think we are the right match, but I pray that Allah opens better doors for you. Wishing you all the best.',
  'Assalamu Alaikum. After sincere consideration, I feel we may not be compatible. I hope you find someone truly right for you. May Allah make it easy for you. JazakAllah khair for your time.',
  'Assalamu Alaikum. I have reflected on our conversations and feel it is best to close this match at this time. I have nothing but respect for you and I make dua that Allah blesses you with the best.',
  'Assalamu Alaikum. I wanted to be transparent with you rather than fade away. I do not see this progressing further, but I truly appreciate your time and wish you every happiness. May Allah bless you.',
];

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

  bool _showSuggestedOpeners  = true;
  late final AnimationController _openersAnim;
  late final Animation<double>   _openersSize;

  @override
  void initState() {
    super.initState();
    _openersAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300), value: 1.0,
    );
    _openersSize = CurvedAnimation(parent: _openersAnim, curve: Curves.easeInOut);
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
    final dismissed = prefs.getBool('openers_dismissed_${widget.conversationId}') ?? false;
    if (!mounted) return;
    if (dismissed) { setState(() => _showSuggestedOpeners = false); _openersAnim.value = 0.0; }
  }

  Future<void> _dismissOpeners() async {
    if (!_showSuggestedOpeners) return;
    await _openersAnim.reverse();
    if (!mounted) return;
    setState(() => _showSuggestedOpeners = false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('openers_dismissed_${widget.conversationId}', true);
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
            duration: AppDimensions.durationTransition, curve: Curves.easeOut,
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
    _dismissOpeners();
    await context.read<ChatCubit>().sendMessage(widget.conversationId, text);
    _scrollToBottom(animated: true);
  }

  void _useOpener(String text) {
    _inputCtrl.text = text;
    _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
    setState(() => _canSend = true);
    _dismissOpeners();
  }

  void _showEndMatchSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context:            context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EndMatchSheet(
        onConfirm: (message) {
          context.read<ChatCubit>().closeMatch(widget.conversationId, message);
          Navigator.pop(context);
          _scrollToBottom(animated: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatCubit, ChatState>(
      listenWhen: (prev, curr) {
        final prevConv = prev.conversations.where((c) => c.id == widget.conversationId).firstOrNull;
        final currConv = curr.conversations.where((c) => c.id == widget.conversationId).firstOrNull;
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
        final isClosed    = conv.isMatchClosed;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: AppColors.obsidianNight,
          appBar: _ChatAppBar(
            name:    conv.matchName,
            initial: conv.matchLastInitial,
            isClosed: isClosed,
            onEndMatch: () => _showEndMatchSheet(context),
          ),
          body: SpringKeyboardPadding(
            child: Column(
              children: [
                // Closed match banner
                if (isClosed) _ClosedBanner(name: conv.matchName),
  
                // Suspended banner
                if (state.isSuspended) _SuspendedBanner(suspendedUntil: state.messagingSuspendedUntil),
  
                // Messages
                Expanded(
                  child: hasMessages
                      ? ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.space16, vertical: AppDimensions.space12,
                          ),
                          itemCount:   conv.messages.length,
                          itemBuilder: (_, i) {
                            final msg      = conv.messages[i];
                            final prev     = i > 0 ? conv.messages[i - 1] : null;
                            final sameAsPrev = prev != null && prev.isMe == msg.isMe;
                            final locale   = Localizations.localeOf(context).languageCode;
                            return _MessageBubble(
                              message:    msg,
                              sameAsPrev: sameAsPrev,
                              onTap: () => context.read<ChatCubit>()
                                  .toggleTimestamp(widget.conversationId, msg.id),
                              onTranslate: () => context.read<ChatCubit>()
                                  .translateMessage(widget.conversationId, msg.id, locale),
                            );
                          },
                        )
                      : _SuggestedOpenersArea(
                          showOpeners: _showSuggestedOpeners,
                          sizeAnim:   _openersSize,
                          onSelect:   _useOpener,
                          matchName:  conv.matchName,
                        ),
                ),
  
                // Input bar (hidden when closed or suspended)
                if (state.isSuspended)
                  _SuspendedInputBar(suspendedUntil: state.messagingSuspendedUntil)
                else if (!isClosed)
                  _InputBar(controller: _inputCtrl, canSend: _canSend, onSend: _sendMessage)
                else
                  _ClosedInputBar(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Closed Banner ─────────────────────────────────────────────

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16, vertical: AppDimensions.space12,
      ),
      color: AppColors.softCoral.withValues(alpha: 0.1),
      child: Row(children: [
        const Icon(Icons.lock_outline_rounded, color: AppColors.softCoral, size: 16),
        const SizedBox(width: AppDimensions.space8),
        Expanded(child: Text(
          'This match has been respectfully closed.',
          style: AppTypography.caption.copyWith(color: AppColors.softCoral),
        )),
      ]),
    );
  }
}

// ── Closed Input Replacement ──────────────────────────────────

class _ClosedInputBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16, AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: const Center(child: Text(
        'This conversation is closed',
        style: AppTypography.caption,
      )),
    );
  }
}

// ── Suspended Banner ──────────────────────────────────────────

class _SuspendedBanner extends StatelessWidget {
  const _SuspendedBanner({required this.suspendedUntil});
  final DateTime? suspendedUntil;

  @override
  Widget build(BuildContext context) {
    final diff = suspendedUntil != null
        ? suspendedUntil!.difference(DateTime.now())
        : Duration.zero;
    final hours = diff.inHours.clamp(0, 24);
    final minutes = diff.inMinutes % 60;
    final remainingStr = hours > 0
        ? '$hours hour${hours == 1 ? '' : 's'}'
        : '$minutes minute${minutes == 1 ? '' : 's'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16, vertical: AppDimensions.space12,
      ),
      color: AppColors.softCoral.withValues(alpha: 0.1),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.softCoral, size: 16),
        const SizedBox(width: AppDimensions.space8),
        Expanded(child: Text(
          'Messaging suspended for violating community guidelines. Unlocks in $remainingStr.',
          style: AppTypography.caption.copyWith(color: AppColors.softCoral),
        )),
      ]),
    );
  }
}

// ── Suspended Input Replacement ──────────────────────────────

class _SuspendedInputBar extends StatelessWidget {
  const _SuspendedInputBar({required this.suspendedUntil});
  final DateTime? suspendedUntil;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16, AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: const Center(child: Text(
        'Messaging is temporarily suspended',
        style: AppTypography.caption,
      )),
    );
  }
}

// ── End Match Bottom Sheet ────────────────────────────────────

class _EndMatchSheet extends StatefulWidget {
  const _EndMatchSheet({required this.onConfirm});
  final ValueChanged<String> onConfirm;

  @override
  State<_EndMatchSheet> createState() => _EndMatchSheetState();
}

class _EndMatchSheetState extends State<_EndMatchSheet> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin:  const EdgeInsets.all(AppDimensions.space16),
      padding: const EdgeInsets.all(AppDimensions.space24),
      decoration: BoxDecoration(
        color:        AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        border:       Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: AppDimensions.space20),
          Text('End this match', style: AppTypography.bodyMedium.copyWith(color: AppColors.pearlWhite)),
          const SizedBox(height: AppDimensions.space6),
          const Text(
            'Choose a respectful message to close this conversation. The other person will be notified.',
            style: AppTypography.caption,
          ),
          const SizedBox(height: AppDimensions.space16),

          ..._kClosureMessages.asMap().entries.map((entry) {
            final i   = entry.key;
            final msg = entry.value;
            final sel = _selected == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppDimensions.space8),
              child: GestureDetector(
                onTap: () => setState(() => _selected = sel ? null : i),
                child: AnimatedContainer(
                  duration: AppDimensions.durationTransition,
                  padding: const EdgeInsets.all(AppDimensions.space12),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.champagneGold.withValues(alpha: 0.08) : AppColors.surfaceGlass,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
                    border: Border.all(
                      color: sel ? AppColors.champagneGold : AppColors.cardBorder,
                      width: sel ? AppDimensions.borderFocus : AppDimensions.borderThin,
                    ),
                  ),
                  child: Text(
                    msg,
                    style: AppTypography.caption.copyWith(
                      color: sel ? AppColors.pearlWhite : AppColors.slateMist,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          }),

          const SizedBox(height: AppDimensions.space16),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeight,
            child: ElevatedButton(
              onPressed: _selected != null
                  ? () => widget.onConfirm(_kClosureMessages[_selected!])
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.softCoral.withValues(alpha: 0.9),
                disabledBackgroundColor: AppColors.surfaceGlassHover,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton)),
                elevation: 0,
              ),
              child: Text(
                'Send & End Match',
                style: AppTypography.button.copyWith(
                  color: _selected != null ? AppColors.pearlWhite : AppColors.slateMist,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          SizedBox(
            width: double.infinity,
            height: AppDimensions.buttonHeightSmall,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side:  const BorderSide(color: AppColors.cardBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusButton)),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: AppTypography.button.copyWith(color: AppColors.slateMist)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Suggested Openers Area ────────────────────────────────────

class _SuggestedOpenersArea extends StatelessWidget {
  const _SuggestedOpenersArea({
    required this.showOpeners,
    required this.sizeAnim,
    required this.onSelect,
    required this.matchName,
  });
  final bool               showOpeners;
  final Animation<double>  sizeAnim;
  final ValueChanged<String> onSelect;
  final String             matchName;

  @override
  Widget build(BuildContext context) {
    final openers = _buildOpeners(matchName);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Begin with Bismillah', style: AppTypography.tagline),
        const SizedBox(height: AppDimensions.space20),
        SizeTransition(
          sizeFactor: sizeAnim, axisAlignment: -1,
          child: SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space24),
              itemCount: openers.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.space12),
              itemBuilder: (_, i) => _OpenerCard(
                text: openers[i], onSelect: () => onSelect(openers[i]),
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
  const _ChatAppBar({required this.name, required this.initial, required this.isClosed, required this.onEndMatch});
  final String name;
  final String initial;
  final bool   isClosed;
  final VoidCallback onEndMatch;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(AppDimensions.space8),
            width: 40, height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceGlass, shape: BoxShape.circle, border: Border.all(color: AppColors.cardBorder)),
            child: const Icon(Icons.arrow_back_rounded, color: AppColors.pearlWhite, size: AppDimensions.iconSizeMedium),
          ),
        ),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceGlassHover, border: Border.all(color: AppColors.goldBorder)),
          child: const Icon(Icons.person_outline_rounded, color: AppColors.slateMist, size: 22),
        ),
        const SizedBox(width: AppDimensions.space12),
        Expanded(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name $initial.', style: AppTypography.bodyMedium, maxLines: 1),
            Text(
              isClosed ? 'Match closed' : 'Matched · Messaging unlocked',
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: isClosed ? AppColors.softCoral : null,
              ),
            ),
          ],
        )),
        if (!isClosed)
          PopupMenuButton<String>(
            icon: Container(
              margin: const EdgeInsets.all(AppDimensions.space8),
              width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.surfaceGlass, shape: BoxShape.circle, border: Border.all(color: AppColors.cardBorder)),
              child: const Icon(Icons.more_vert_rounded, color: AppColors.slateMist, size: AppDimensions.iconSizeMedium),
            ),
            color: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'end',
                child: Row(children: [
                  const Icon(Icons.do_not_disturb_on_outlined, color: AppColors.softCoral, size: 18),
                  const SizedBox(width: AppDimensions.space8),
                  Text('End Match', style: AppTypography.body.copyWith(color: AppColors.softCoral)),
                ]),
              ),
            ],
            onSelected: (v) { if (v == 'end') onEndMatch(); },
          )
        else
          const SizedBox(width: 48),
      ]),
    );
  }
}

// ── Opener Card ───────────────────────────────────────────────

class _OpenerCard extends StatelessWidget {
  const _OpenerCard({required this.text, required this.onSelect});
  final String text;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onSelect(); },
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppDimensions.space14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Text(text, style: AppTypography.bio.copyWith(fontSize: 13), maxLines: 4, overflow: TextOverflow.ellipsis),
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
    this.onTranslate,
  });
  final ChatMessage message;
  final bool        sameAsPrev;
  final VoidCallback onTap;
  final VoidCallback? onTranslate;

  @override
  Widget build(BuildContext context) {
    final isMe   = message.isMe;
    final locale = Localizations.localeOf(context).languageCode;
    final hasTranslation = message.translations.containsKey(locale);

    final radius = BorderRadius.only(
      topLeft:     Radius.circular(isMe ? AppDimensions.radiusButton : 6),
      topRight:    Radius.circular(isMe ? 6 : AppDimensions.radiusButton),
      bottomLeft:  const Radius.circular(AppDimensions.radiusButton),
      bottomRight: const Radius.circular(AppDimensions.radiusButton),
    );

    return Padding(
      padding: EdgeInsets.only(top: sameAsPrev ? AppDimensions.space4 : AppDimensions.space12, bottom: AppDimensions.space2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // §3.2: Guardian message indicator
          if (message.sentByGuardian)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.supervisor_account_outlined,
                      color: AppColors.champagneGold.withValues(alpha: 0.7), size: 12),
                  const SizedBox(width: 3),
                  Text('Sent by Guardian',
                    style: AppTypography.chatTimestamp.copyWith(
                      color: AppColors.champagneGold.withValues(alpha: 0.7),
                      fontSize: 10,
                    )),
                ],
              ),
            ),
          GestureDetector(
            onTap: onTap,
            child: Row(
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space14, vertical: AppDimensions.space10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.champagneGold.withValues(alpha: 0.15) : AppColors.surfaceGlassHover,
                      borderRadius: radius,
                      border: Border.all(color: isMe ? AppColors.goldBorder : AppColors.cardBorder, width: 0.8),
                    ),
                    child: hasTranslation
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(message.text, style: AppTypography.chatMessage),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Divider(
                                  color: (isMe ? AppColors.goldBorder : AppColors.cardBorder).withValues(alpha: 0.5),
                                  height: 1,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.g_translate_rounded,
                                    color: AppColors.champagneGold.withValues(alpha: 0.8),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      message.translations[locale]!,
                                      style: AppTypography.chatMessage.copyWith(
                                        color: AppColors.pearlWhite.withValues(alpha: 0.9),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Text(message.text, style: AppTypography.chatMessage),
                  ),
                ),
                if (isMe) ...[ const SizedBox(width: AppDimensions.space4), _StatusIcon(status: message.status) ],
              ],
            ),
          ),
          if (!isMe && !hasTranslation && onTranslate != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 6),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTranslate!();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.translate,
                      color: AppColors.champagneGold,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Translate',
                      style: AppTypography.chatTimestamp.copyWith(
                        color: AppColors.champagneGold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          AnimatedSize(
            duration: AppDimensions.durationTransition,
            child: message.isTimestampVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.space4, left: AppDimensions.space4, right: AppDimensions.space4),
                    child: Text(_formatTime(message.sentAt), style: AppTypography.chatTimestamp),
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
    final now  = DateTime.now();
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
      case MessageStatus.queued:    return const Icon(Icons.access_time_rounded, color: AppColors.slateMist, size: 12);
      case MessageStatus.sent:      return const Icon(Icons.check_rounded, color: AppColors.slateMist, size: 12);
      case MessageStatus.delivered: return const Icon(Icons.done_all_rounded, color: AppColors.slateMist, size: 12);
      case MessageStatus.read:      return const Icon(Icons.done_all_rounded, color: AppColors.champagneGold, size: 12);
      case MessageStatus.failed:    return const Icon(Icons.error_outline_rounded, color: AppColors.softCoral, size: 12);
    }
  }
}

// ── Input bar ─────────────────────────────────────────────────
// Blueprint: "Minimalist field. No 'Send' button — only a Gold
// arrow icon that appears when typing starts."

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.canSend, required this.onSend});
  final TextEditingController controller;
  final bool                  canSend;
  final VoidCallback          onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppDimensions.space16, AppDimensions.space12,
        AppDimensions.space16,
        AppDimensions.space12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.obsidianNight,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass,
              borderRadius: BorderRadius.circular(AppDimensions.radiusButton),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TextField(
              controller: controller, maxLines: null,
              style: AppTypography.chatMessage,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                hintText: 'Type a message…', hintStyle: AppTypography.inputLabel,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: AppDimensions.space14, vertical: AppDimensions.space10),
              ),
            ),
          ),
        ),
        // Gold arrow — fades & scales in only when typing starts
        AnimatedScale(
          scale: canSend ? 1.0 : 0.0,
          duration: AppDimensions.durationTransition,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: canSend ? 1.0 : 0.0,
            duration: AppDimensions.durationTransition,
            child: Padding(
              padding: const EdgeInsets.only(left: AppDimensions.space10),
              child: GestureDetector(
                onTap: canSend ? onSend : null,
                child: const Icon(
                  Icons.arrow_upward_rounded,
                  color: AppColors.champagneGold,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
