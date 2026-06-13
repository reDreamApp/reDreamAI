import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class ChatState extends ChangeNotifier {
  ChatState(this._service);

  final IChatService _service;

  int? _chatId;
  IrtStage _stage = IrtStage.recording;
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  bool _isDone = false;
  bool _resumedDone = false;
  SafetyEvent? _safetyEvent;
  int? _retryAfterSeconds;
  String? _errorMessage;
  bool _startFailed = false;
  bool _hasSubmittedIntensity = false;
  String? _failedMessageId;
  int _localSeq = 0;

  List<ChatSummary> _chats = const [];
  bool _chatsLoading = false;
  String? _chatsError;
  bool _loadingChat = false;

  int? get chatId => _chatId;
  IrtStage get stage => _stage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get isDone => _isDone;
  SafetyEvent? get safetyEvent => _safetyEvent;
  int? get retryAfterSeconds => _retryAfterSeconds;
  String? get errorMessage => _errorMessage;

  /// True when the last [startChat] call failed; the UI offers a retry.
  bool get startFailed => _startFailed;

  /// True once a rating was successfully submitted in the current
  /// intensity stage; resets on a new chat or when the stage moves on.
  bool get hasSubmittedIntensity => _hasSubmittedIntensity;

  /// Local id of the message whose send failed, if any.
  String? get failedMessageId => _failedMessageId;

  /// True when the current chat was already finished when it was loaded
  /// (resumed from history) — the UI shows it read-only, without the
  /// "start new session" call to action.
  bool get resumedDone => _resumedDone;

  /// The user's chats, newest first (drawer contents).
  List<ChatSummary> get chats => List.unmodifiable(_chats);
  bool get chatsLoading => _chatsLoading;
  String? get chatsError => _chatsError;

  /// True while [loadChat] is fetching a chat's messages.
  bool get loadingChat => _loadingChat;

  /// Starts a new chat session, resetting all local state.
  ///
  /// [welcomeMessage] is a localized, display-only greeting shown as the
  /// first assistant bubble. It is never sent to the backend — chat history
  /// is owned by the backend (ADR 0002); this mirrors the legacy client.
  Future<void> startChat({
    required String language,
    required String welcomeMessage,
  }) async {
    _startFailed = false;
    _errorMessage = null;
    try {
      final res = await _service.start(language: language);
      _chatId = res.chatId;
      _stage = res.currentStage;
      _messages
        ..clear()
        ..add(_localMessage(role: 'assistant', content: welcomeMessage));
      _isDone = false;
      _resumedDone = false;
      _hasSubmittedIntensity = false;
      _safetyEvent = null;
      _retryAfterSeconds = null;
      _failedMessageId = null;
    } on ApiException catch (e) {
      _startFailed = true;
      _errorMessage = e.message;
    } on Exception catch (e) {
      _startFailed = true;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// First-open flow: resume the most recent chat when it is still open,
  /// otherwise start a fresh one. Chat history lives on the backend — this
  /// refetches `/chats` + `/chats/{id}/messages` instead of reconstructing
  /// anything locally.
  Future<void> resumeOrStart({
    required String language,
    required String welcomeMessage,
  }) async {
    try {
      _chats = _sortedNewestFirst(await _service.listChats());
      _chatsError = null;
      notifyListeners();
    } on Exception {
      // Fall through — startChat below surfaces the failure (retry banner).
      _chats = const [];
    }
    final latest = _chats.isEmpty ? null : _chats.first;
    if (latest != null && !latest.isDone) {
      final loaded = await loadChat(latest.id, welcomeMessage: welcomeMessage);
      if (loaded) return;
    }
    await startChat(language: language, welcomeMessage: welcomeMessage);
  }

  /// Refreshes the chat list shown in the history drawer.
  Future<void> loadChats() async {
    _chatsLoading = true;
    _chatsError = null;
    notifyListeners();
    try {
      _chats = _sortedNewestFirst(await _service.listChats());
    } on ApiException catch (e) {
      _chatsError = e.message;
    } on Exception catch (e) {
      _chatsError = e.toString();
    } finally {
      _chatsLoading = false;
      notifyListeners();
    }
  }

  /// Loads an existing chat from the backend (drawer tap / resume / refresh).
  ///
  /// [welcomeMessage] is only inserted when the chat has no messages yet
  /// (brand-new session that was started but never written to).
  /// Returns false (and sets [errorMessage]) when loading failed.
  Future<bool> loadChat(int id, {String? welcomeMessage}) async {
    _loadingChat = true;
    _errorMessage = null;
    _startFailed = false;
    notifyListeners();
    try {
      final fetched = await _service.listMessages(id);
      ChatSummary? summary;
      for (final c in _chats) {
        if (c.id == id) summary = c;
      }
      _chatId = id;
      _messages
        ..clear()
        ..addAll(fetched);
      if (fetched.isEmpty && welcomeMessage != null) {
        _messages.add(_localMessage(role: 'assistant', content: welcomeMessage));
      }
      _isDone = summary?.isDone ?? false;
      _resumedDone = _isDone;
      if (_isDone) {
        _stage = IrtStage.finalStage;
      } else if (summary != null) {
        _stage = summary.currentStage;
      } else {
        _stage = _stageFromMessages(fetched);
      }
      _hasSubmittedIntensity = _stage == IrtStage.intensity &&
          _isIntensityRating(_lastUserContent(fetched));
      _safetyEvent = null;
      _retryAfterSeconds = null;
      _failedMessageId = null;
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      return false;
    } on Exception catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _loadingChat = false;
      notifyListeners();
    }
  }

  /// Pull-to-refresh: reloads the current chat's messages (and the chat
  /// list, so done/title state stays accurate) from the backend.
  Future<void> refreshCurrentChat({String? welcomeMessage}) async {
    final id = _chatId;
    if (id == null) return;
    try {
      _chats = _sortedNewestFirst(await _service.listChats());
    } on Exception {
      // Keep the stale list; loadChat below reports the real error.
    }
    await loadChat(id, welcomeMessage: welcomeMessage);
  }

  /// Deletes a chat on the backend and locally. When the active chat is
  /// deleted, the local session is cleared (callers start a fresh one).
  Future<bool> deleteChat(int id) async {
    try {
      await _service.deleteChat(id);
    } on Exception {
      return false;
    }
    _chats = _chats.where((c) => c.id != id).toList();
    if (_chatId == id) {
      _chatId = null;
      _messages.clear();
      _stage = IrtStage.recording;
      _isDone = false;
      _resumedDone = false;
      _hasSubmittedIntensity = false;
      _safetyEvent = null;
      _retryAfterSeconds = null;
      _failedMessageId = null;
    }
    notifyListeners();
    return true;
  }

  void dismissSafetyEvent() {
    _safetyEvent = null;
    notifyListeners();
  }

  void dismissError() {
    _errorMessage = null;
    _retryAfterSeconds = null;
    notifyListeners();
  }

  Future<void> send(String content) async {
    final id = _chatId;
    if (id == null) {
      _errorMessage = 'no_chat';
      notifyListeners();
      return;
    }
    if (content.trim().isEmpty) return;
    // Optimistically show the user's message so a failed send never
    // discards what they typed.
    final local = _localMessage(role: 'user', content: content);
    _messages.add(local);
    _failedMessageId = null;
    _sending = true;
    _safetyEvent = null;
    _retryAfterSeconds = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final turn = await _service.sendMessage(chatId: id, content: content);
      _messages
        ..remove(local)
        ..add(turn.userMessage);
      if (turn.aiMessage != null) _messages.add(turn.aiMessage!);
      _stage = turn.stage;
      _isDone = turn.isDone;
      _safetyEvent = turn.safetyEvent;
      if (_stage != IrtStage.intensity) _hasSubmittedIntensity = false;
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // The chat finished on the backend (stale local state) — drop the
        // optimistic message and show the finished, read-only view.
        _messages.remove(local);
        _isDone = true;
        _resumedDone = true;
        _stage = IrtStage.finalStage;
      } else if (e.isRateLimited) {
        _failedMessageId = local.id;
        _retryAfterSeconds = e.retryAfterSeconds;
      } else {
        _failedMessageId = local.id;
        _errorMessage = e.message;
      }
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  /// Re-sends the message whose send previously failed.
  Future<void> retryFailedSend() async {
    final failedId = _failedMessageId;
    if (failedId == null || _sending) return;
    final index = _messages.indexWhere((m) => m.id == failedId);
    if (index == -1) {
      _failedMessageId = null;
      return;
    }
    final content = _messages.removeAt(index).content;
    _failedMessageId = null;
    await send(content);
  }

  /// Submits the intensity rating; the integer travels as a normal chat
  /// message (wire contract). The slider stays available until a submit
  /// actually succeeds.
  Future<void> submitIntensity(int value) async {
    await send(value.toString());
    if (_failedMessageId == null) {
      _hasSubmittedIntensity = true;
      notifyListeners();
    }
  }

  ChatMessage _localMessage({required String role, required String content}) =>
      ChatMessage(
        id: 'local-${_localSeq++}',
        role: role,
        content: content,
        stage: null,
        createdAt: DateTime.now(),
      );

  List<ChatSummary> _sortedNewestFirst(List<ChatSummary> list) =>
      [...list]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  IrtStage _stageFromMessages(List<ChatMessage> fetched) {
    for (final m in fetched.reversed) {
      final s = m.stage;
      if (s != null) return stageFromString(s);
    }
    return IrtStage.recording;
  }

  String _lastUserContent(List<ChatMessage> fetched) {
    for (final m in fetched.reversed) {
      if (m.isUser) return m.content;
    }
    return '';
  }

  bool _isIntensityRating(String text) {
    final value = int.tryParse(text.trim());
    return value != null && value >= 0 && value <= 10;
  }
}
