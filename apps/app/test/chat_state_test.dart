import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_service.dart';
import 'package:redream_app/features/chat/chat_state.dart';

import 'fake_api.dart';

(ChatState, FakeApi) _setup() {
  var msgId = 0;
  final api = FakeApi()
    ..on(
      'POST /api/v1/chats/start',
      (_, _) => {'chat_id': 7, 'language': 'en', 'current_stage': 'recording'},
    )
    ..on(
      'GET /api/v1/chats',
      (_, _) => [chatJson(7), chatJson(3, done: true, title: 'Old')],
    )
    ..on('POST /api/v1/chats/{id}/message', (_, body) {
      final content = body['content'] as String;
      final safety = content.contains('hurt myself');
      return {
        'chat_id': 7,
        'user_message': messageJson(
          'u${msgId++}',
          role: 'user',
          content: content,
        ),
        'ai_message': safety
            ? null
            : messageJson(
                'a${msgId++}',
                role: 'assistant',
                content: 'Tell me more.',
                stage: 'intensity',
              ),
        'stage': safety ? 'recording' : 'intensity',
        'is_done': false,
        'safety_event': safety
            ? {
                'risk': 'high',
                'categories': ['self_harm'],
                'confidence': 0.9,
              }
            : null,
      };
    })
    ..on(
      'GET /api/v1/chats/{id}/messages',
      (_, _) => [
        messageJson('m1', role: 'user', content: 'hi'),
        messageJson(
          'm2',
          role: 'assistant',
          content: 'hello',
          stage: 'rewriting',
        ),
      ],
    )
    ..on('DELETE /api/v1/chats/{id}', (_, _) => null);
  return (ChatState(ChatService(api.client()), language: () => 'en'), api);
}

void main() {
  test(
    'starts with a local welcome message and creates the chat lazily',
    () async {
      final (state, api) = _setup();
      expect(state.messages.single.id, ChatState.welcomeId);
      expect(state.chatId, isNull);

      await state.send('I had a bad dream');
      expect(state.chatId, 7);
      expect(api.calls.first, 'POST /api/v1/chats/start');
      expect(state.messages.map((m) => m.role), [
        'assistant',
        'user',
        'assistant',
      ]);
      expect(state.stage, IrtStage.intensity);
      expect(state.isNightmare, isTrue);
      expect(state.awaitingIntensity, isTrue);
    },
  );

  test('intensity reply is a plain number and clears the slider', () async {
    final (state, _) = _setup();
    await state.send('bad dream');
    await state.send('7');
    expect(state.awaitingIntensity, isFalse);
  });

  test('safety event pauses the turn without advancing the stage', () async {
    final (state, _) = _setup();
    await state.send('I want to hurt myself');
    expect(state.safetyEvent?.risk, 'high');
    expect(state.stage, IrtStage.recording);
    expect(state.messages.last.isUser, isTrue);
    state.dismissSafetyEvent();
    expect(state.safetyEvent, isNull);
  });

  test('offline send marks the message failed and resend recovers', () async {
    final (state, api) = _setup();
    await state.send('first');
    api.offline = true;
    await state.send('second');
    expect(state.failedMessage?.content, 'second');
    expect(state.error, isNotNull);

    api.offline = false;
    await state.resend();
    expect(state.failedMessage, isNull);
    expect(state.messages.where((m) => m.content == 'second').length, 1);
  });

  test(
    'rate limit surfaces retry-after and finished chats become read-only',
    () async {
      final (state, api) = _setup();
      await state.send('first');
      api.on(
        'POST /api/v1/chats/{id}/message',
        (_, _) =>
            throw FakeApiError(429, 'budget', headers: {'retry-after': '60'}),
      );
      await state.send('again');
      expect(state.retryAfterSeconds, 60);

      api.on(
        'POST /api/v1/chats/{id}/message',
        (_, _) => throw FakeApiError(409, 'chat is already finished'),
      );
      state.dismissError();
      await state.send('more');
      expect(state.isDone, isTrue);
      expect(state.canSend, isFalse);
    },
  );

  test('opens a past chat and derives stage and nightmare flag', () async {
    final (state, _) = _setup();
    await state.loadChats();
    expect(state.chats.length, 2);
    await state.openChat(3);
    expect(state.chatId, 3);
    expect(state.isDone, isTrue);
    expect(state.messages.length, 2);

    await state.openChat(7);
    expect(state.isDone, isFalse);
    expect(state.isNightmare, isTrue);
    expect(state.stage, IrtStage.recording);

    await state.deleteChat(7);
    expect(state.chatId, isNull);
    expect(state.chats.map((c) => c.id), [3]);
  });
}
