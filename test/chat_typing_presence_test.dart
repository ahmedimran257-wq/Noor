import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silarah/core/cubits/chat/chat_cubit.dart';
import 'package:silarah/core/cubits/chat/chat_state.dart';
import 'package:silarah/features/home/screens/chat_screen.dart';

class _TestChatCubit extends ChatCubit {
  @override
  Future<ChatAccessDecision> checkChatAccess(String matchId) async {
    return const ChatAccessDecision(ChatAccessReason.allowed);
  }

  @override
  Future<void> loadConversations({
    bool showLoading = true,
    bool force = false,
  }) async {}

  @override
  Future<void> loadMessages(String conversationId,
      {bool older = false}) async {}

  @override
  Future<void> markRead(String conversationId) async {}

  void seed(ChatState next) => emit(next);
}

const _conversationId = '00000000-0000-0000-0000-000000000123';

const _conversation = Conversation(
  id: _conversationId,
  matchName: 'Amina',
  matchLastInitial: 'K',
  messages: [],
);

void main() {
  test('typing presence is transient state and scoped by conversation', () {
    const state = ChatState(
      conversations: [_conversation],
      typingConversationIds: {_conversationId},
    );

    expect(state.isUserTyping(_conversationId), isTrue);
    expect(
      state.isUserTyping('00000000-0000-0000-0000-000000000999'),
      isFalse,
    );
    expect(const ChatState().typingConversationIds, isEmpty);
  });

  testWidgets('live typing status appears and clears without stale UI',
      (tester) async {
    final cubit = _TestChatCubit();
    cubit.seed(const ChatState(conversations: [_conversation]));

    await tester.pumpWidget(
      BlocProvider<ChatCubit>.value(
        value: cubit,
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: ChatScreen(conversationId: _conversationId),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Amina K.'), findsOneWidget);
    expect(find.text('Private conversation'), findsOneWidget);

    cubit.seed(const ChatState(
      conversations: [_conversation],
      typingConversationIds: {_conversationId},
    ));
    expect(cubit.state.isUserTyping(_conversationId), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(cubit.state.isUserTyping(_conversationId), isTrue);
    expect(find.text('Amina is typing'), findsNWidgets(2));

    cubit.seed(const ChatState(conversations: [_conversation]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(find.text('Amina is typing'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await cubit.close();
  });
}
