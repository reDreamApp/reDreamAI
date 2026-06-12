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
  SafetyEvent? _safetyEvent;
  int? _retryAfterSeconds;
  String? _errorMessage;
  bool _startFailed = false;
  bool _hasSubmittedIntensity = false;
  String? _failedMessageId;
  int _localSeq = 0;

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
      _failedMessageId = local.id;
      if (e.isRateLimited) {
        _retryAfterSeconds = e.retryAfterSeconds;
      } else {
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
}
