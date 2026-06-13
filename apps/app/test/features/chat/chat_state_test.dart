import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/core/api/api_exception.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_service.dart';
import 'package:redream_app/features/chat/chat_state.dart';

ChatSummary _chat(
  int id, {
  bool isDone = false,
  IrtStage stage = IrtStage.recording,
  String? title,
  DateTime? updatedAt,
}) =>
    ChatSummary(
      id: id,
      language: 'en',
      currentStage: stage,
      isDone: isDone,
      isNightmare: null,
      title: title,
      createdAt: DateTime.utc(2026, 1, id),
      updatedAt: updatedAt ?? DateTime.utc(2026, 1, id),
    );

class _FakeChatService implements IChatService {
  bool failStart = false;
  bool failSend = false;
  ApiException sendError = ApiException(500, 'boom');
  IrtStage nextStage = IrtStage.recording;
  bool nextIsDone = false;
  SafetyEvent? nextSafetyEvent;
  int _id = 0;

  List<ChatSummary> chatList = [];
  bool failListChats = false;
  Map<int, List<ChatMessage>> messagesByChat = {};
  bool failListMessages = false;
  bool failDelete = false;
  final List<int> deletedIds = [];
  int listChatsCalls = 0;
  int listMessagesCalls = 0;

  @override
  Future<ChatStart> start({required String language}) async {
    if (failStart) throw ApiException(500, 'start failed');
    return ChatStart(chatId: 1, language: language, currentStage: IrtStage.recording);
  }

  @override
  Future<List<ChatSummary>> listChats() async {
    listChatsCalls++;
    if (failListChats) throw ApiException(500, 'list failed');
    return chatList;
  }

  @override
  Future<List<ChatMessage>> listMessages(int chatId) async {
    listMessagesCalls++;
    if (failListMessages) throw ApiException(500, 'messages failed');
    return messagesByChat[chatId] ?? [];
  }

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

  @override
  Future<void> deleteChat(int chatId) async {
    if (failDelete) throw ApiException(500, 'delete failed');
    deletedIds.add(chatId);
  }

  ChatMessage _msg(String role, String content, {String? stage}) => ChatMessage(
        id: 'srv-${_id++}',
        role: role,
        content: content,
        stage: stage,
        createdAt: DateTime.utc(2026),
      );

  ChatMessage serverMessage(String role, String content, {String? stage}) =>
      _msg(role, content, stage: stage);
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
      expect(state.resumedDone, isFalse);
      expect(state.hasSubmittedIntensity, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.failedMessageId, isNull);
      expect(state.messages, hasLength(1));
    });
  });

  group('resumeOrStart', () {
    Future<void> resume() =>
        state.resumeOrStart(language: 'en', welcomeMessage: 'Welcome!');

    test('resumes the most recent chat when it is not done', () async {
      service.chatList = [
        _chat(7, updatedAt: DateTime.utc(2026, 5)),
        _chat(3, isDone: true, updatedAt: DateTime.utc(2026, 4)),
      ];
      service.messagesByChat[7] = [
        service.serverMessage('user', 'my dream', stage: 'recording'),
        service.serverMessage('assistant', 'tell me more', stage: 'recording'),
      ];
      await resume();
      expect(state.chatId, 7);
      expect(state.isDone, isFalse);
      expect(state.messages, hasLength(2));
      // No local welcome bubble for resumed chats with history.
      expect(state.messages.first.content, 'my dream');
    });

    test('sorts chats newest first before picking', () async {
      service.chatList = [
        _chat(2, isDone: true, updatedAt: DateTime.utc(2026, 5, 2)),
        _chat(9, updatedAt: DateTime.utc(2026, 5)),
      ];
      await resume();
      // Newest chat (id 2) is done -> start fresh instead of resuming id 9.
      expect(state.chatId, 1);
      expect(state.messages.single.content, 'Welcome!');
    });

    test('starts fresh when there are no chats', () async {
      await resume();
      expect(state.chatId, 1);
      expect(state.messages.single.content, 'Welcome!');
    });

    test('falls back to startChat (and its error path) when listing fails', () async {
      service
        ..failListChats = true
        ..failStart = true;
      await resume();
      expect(state.startFailed, isTrue);
      expect(state.errorMessage, isNotNull);
    });
  });

  group('loadChat', () {
    test('loads messages and stage from the chat summary', () async {
      service.chatList = [_chat(5, stage: IrtStage.rewriting)];
      await state.loadChats();
      service.messagesByChat[5] = [
        service.serverMessage('user', 'dream', stage: 'recording'),
        service.serverMessage('assistant', 'rewrite it', stage: 'rewriting'),
      ];
      final ok = await state.loadChat(5);
      expect(ok, isTrue);
      expect(state.chatId, 5);
      expect(state.stage, IrtStage.rewriting);
      expect(state.isDone, isFalse);
      expect(state.resumedDone, isFalse);
      expect(state.messages, hasLength(2));
    });

    test('marks a done chat as resumed read-only with final stage', () async {
      service.chatList = [_chat(5, isDone: true, stage: IrtStage.summary)];
      await state.loadChats();
      service.messagesByChat[5] = [
        service.serverMessage('user', 'dream', stage: 'recording'),
      ];
      await state.loadChat(5);
      expect(state.isDone, isTrue);
      expect(state.resumedDone, isTrue);
      expect(state.stage, IrtStage.finalStage);
    });

    test('inserts welcome bubble only when the chat has no messages', () async {
      service.chatList = [_chat(5)];
      await state.loadChats();
      await state.loadChat(5, welcomeMessage: 'Welcome!');
      expect(state.messages.single.content, 'Welcome!');
    });

    test('restores hasSubmittedIntensity from history', () async {
      service.chatList = [_chat(5, stage: IrtStage.intensity)];
      await state.loadChats();
      service.messagesByChat[5] = [
        service.serverMessage('assistant', 'rate it', stage: 'intensity'),
        service.serverMessage('user', '7', stage: 'intensity'),
      ];
      await state.loadChat(5);
      expect(state.stage, IrtStage.intensity);
      expect(state.hasSubmittedIntensity, isTrue);
    });

    test('reports failure via errorMessage and return value', () async {
      service.failListMessages = true;
      final ok = await state.loadChat(5);
      expect(ok, isFalse);
      expect(state.errorMessage, 'messages failed');
    });
  });

  group('loadChats', () {
    test('sorts newest first', () async {
      service.chatList = [
        _chat(1, updatedAt: DateTime.utc(2026)),
        _chat(2, updatedAt: DateTime.utc(2026, 3)),
        _chat(3, updatedAt: DateTime.utc(2026, 2)),
      ];
      await state.loadChats();
      expect(state.chats.map((c) => c.id), [2, 3, 1]);
      expect(state.chatsError, isNull);
    });

    test('sets chatsError on failure', () async {
      service.failListChats = true;
      await state.loadChats();
      expect(state.chatsError, 'list failed');
      expect(state.chatsLoading, isFalse);
    });
  });

  group('deleteChat', () {
    test('removes the chat from the list', () async {
      service.chatList = [_chat(1), _chat(2)];
      await state.loadChats();
      final ok = await state.deleteChat(1);
      expect(ok, isTrue);
      expect(service.deletedIds, [1]);
      expect(state.chats.map((c) => c.id), [2]);
    });

    test('clears the active session when deleting the current chat', () async {
      await start();
      expect(state.chatId, 1);
      final ok = await state.deleteChat(1);
      expect(ok, isTrue);
      expect(state.chatId, isNull);
      expect(state.messages, isEmpty);
      expect(state.stage, IrtStage.recording);
    });

    test('returns false and keeps state on failure', () async {
      service.chatList = [_chat(1)];
      await state.loadChats();
      service.failDelete = true;
      final ok = await state.deleteChat(1);
      expect(ok, isFalse);
      expect(state.chats, hasLength(1));
    });
  });

  group('refreshCurrentChat', () {
    test('refetches messages and chat list for the current chat', () async {
      service.chatList = [_chat(4)];
      await state.loadChats();
      service.messagesByChat[4] = [
        service.serverMessage('user', 'hi', stage: 'recording'),
      ];
      await state.loadChat(4);
      expect(state.messages, hasLength(1));

      service.messagesByChat[4] = [
        service.serverMessage('user', 'hi', stage: 'recording'),
        service.serverMessage('assistant', 'hello', stage: 'recording'),
      ];
      await state.refreshCurrentChat();
      expect(state.messages, hasLength(2));
    });

    test('is a no-op without a current chat', () async {
      await state.refreshCurrentChat();
      expect(service.listMessagesCalls, 0);
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

    test('marks chat finished read-only on 409', () async {
      await start();
      service
        ..failSend = true
        ..sendError = ApiException(409, 'chat is already finished');
      await state.send('hello?');
      expect(state.isDone, isTrue);
      expect(state.resumedDone, isTrue);
      expect(state.stage, IrtStage.finalStage);
      expect(state.failedMessageId, isNull);
      // Optimistic bubble is dropped — only the welcome message remains.
      expect(state.messages, hasLength(1));
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

  group('models', () {
    test('ChatSummary parses backend ChatOut json', () {
      final summary = ChatSummary.fromJson(const {
        'id': 12,
        'language': 'de',
        'current_stage': 'rewriting',
        'is_done': false,
        'is_nightmare': true,
        'title': 'Falling',
        'created_at': '2026-05-01T10:00:00Z',
        'updated_at': '2026-05-02T11:30:00Z',
      });
      expect(summary.id, 12);
      expect(summary.language, 'de');
      expect(summary.currentStage, IrtStage.rewriting);
      expect(summary.isDone, isFalse);
      expect(summary.isNightmare, isTrue);
      expect(summary.title, 'Falling');
      expect(summary.updatedAt, DateTime.utc(2026, 5, 2, 11, 30));
    });
  });
}
