import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/core/api/api_exception.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_service.dart';
import 'package:redream_app/features/chat/chat_state.dart';

class _FakeChatService implements IChatService {
  bool failStart = false;
  bool failSend = false;
  ApiException sendError = ApiException(500, 'boom');
  IrtStage nextStage = IrtStage.recording;
  bool nextIsDone = false;
  SafetyEvent? nextSafetyEvent;
  int _id = 0;

  @override
  Future<ChatStart> start({required String language}) async {
    if (failStart) throw ApiException(500, 'start failed');
    return ChatStart(chatId: 1, language: language, currentStage: IrtStage.recording);
  }

  @override
  Future<List<ChatMessage>> listMessages(int chatId) async => [];

  @override
  Future<ChatTurn> sendMessage({required int chatId, required String content}) async {
    if (failSend) throw sendError;
    return ChatTurn(
      userMessage: _msg('user', content),
      aiMessage: _msg('assistant', 'reply to $content'),
      stage: nextStage,
      isDone: nextIsDone,
      safetyEvent: nextSafetyEvent,
    );
  }

  ChatMessage _msg(String role, String content) => ChatMessage(
        id: 'srv-${_id++}',
        role: role,
        content: content,
        stage: null,
        createdAt: DateTime.utc(2026),
      );
}

void main() {
  late _FakeChatService service;
  late ChatState state;

  setUp(() {
    service = _FakeChatService();
    state = ChatState(service);
  });

  Future<void> start() =>
      state.startChat(language: 'en', welcomeMessage: 'Welcome!');

  group('startChat', () {
    test('inserts local welcome message on success', () async {
      await start();
      expect(state.chatId, 1);
      expect(state.startFailed, isFalse);
      expect(state.messages, hasLength(1));
      expect(state.messages.single.content, 'Welcome!');
      expect(state.messages.single.isUser, isFalse);
    });

    test('sets startFailed and errorMessage on failure', () async {
      service.failStart = true;
      await start();
      expect(state.startFailed, isTrue);
      expect(state.errorMessage, isNotNull);
      expect(state.messages, isEmpty);
    });

    test('resets done/intensity/error state', () async {
      await start();
      service.nextStage = IrtStage.intensity;
      await state.send('a nightmare');
      await state.submitIntensity(7);
      service
        ..nextIsDone = true
        ..nextStage = IrtStage.finalStage;
      await state.send('bye');
      expect(state.isDone, isTrue);

      await start();
      expect(state.isDone, isFalse);
      expect(state.hasSubmittedIntensity, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.failedMessageId, isNull);
      expect(state.messages, hasLength(1));
    });
  });

  group('send', () {
    test('keeps typed message as failed bubble on error', () async {
      await start();
      service.failSend = true;
      await state.send('my dream');
      expect(state.messages.last.content, 'my dream');
      expect(state.failedMessageId, state.messages.last.id);
      expect(state.errorMessage, 'boom');
    });

    test('sets retryAfterSeconds (not errorMessage) on 429', () async {
      await start();
      service
        ..failSend = true
        ..sendError = ApiException(429, 'limit', retryAfterSeconds: 30);
      await state.send('my dream');
      expect(state.retryAfterSeconds, 30);
      expect(state.errorMessage, isNull);
      expect(state.failedMessageId, isNotNull);
    });

    test('retryFailedSend resends the failed message', () async {
      await start();
      service.failSend = true;
      await state.send('my dream');
      service.failSend = false;
      await state.retryFailedSend();
      expect(state.failedMessageId, isNull);
      // welcome + server user message + ai reply
      expect(state.messages, hasLength(3));
      expect(state.messages[1].content, 'my dream');
      expect(state.messages[2].content, 'reply to my dream');
    });

    test('replaces optimistic message with server turn on success', () async {
      await start();
      await state.send('hello');
      expect(state.messages, hasLength(3));
      expect(state.messages[1].id, startsWith('srv-'));
    });
  });

  group('intensity', () {
    test('submitIntensity sends integer and marks submitted', () async {
      await start();
      service.nextStage = IrtStage.intensity;
      await state.send('a nightmare');
      expect(state.stage, IrtStage.intensity);
      expect(state.hasSubmittedIntensity, isFalse);

      await state.submitIntensity(7);
      expect(state.hasSubmittedIntensity, isTrue);
      expect(
        state.messages.where((m) => m.isUser && m.content == '7'),
        hasLength(1),
      );
    });

    test('failed submit keeps slider available', () async {
      await start();
      service.nextStage = IrtStage.intensity;
      await state.send('a nightmare');
      service.failSend = true;
      await state.submitIntensity(7);
      expect(state.hasSubmittedIntensity, isFalse);
    });

    test('flag resets when stage moves on', () async {
      await start();
      service.nextStage = IrtStage.intensity;
      await state.send('a nightmare');
      await state.submitIntensity(7);
      service.nextStage = IrtStage.rewriting;
      await state.send('ok');
      expect(state.hasSubmittedIntensity, isFalse);
    });
  });

  group('safety event', () {
    test('parses optional message field', () {
      final withMessage = SafetyEvent.fromJson(const {
        'risk': 'high',
        'categories': ['self_harm'],
        'confidence': 0.9,
        'message': 'Call 0800 111 0 111',
      });
      expect(withMessage.message, 'Call 0800 111 0 111');

      final withoutMessage = SafetyEvent.fromJson(const {
        'risk': 'high',
        'categories': ['self_harm'],
        'confidence': 0.9,
      });
      expect(withoutMessage.message, isNull);
    });

    test('is surfaced from a turn', () async {
      await start();
      service.nextSafetyEvent = SafetyEvent(
        risk: 'high',
        categories: const ['self_harm'],
        confidence: 0.9,
        message: 'helpline',
      );
      await state.send('dark thoughts');
      expect(state.safetyEvent?.message, 'helpline');
    });
  });
}
