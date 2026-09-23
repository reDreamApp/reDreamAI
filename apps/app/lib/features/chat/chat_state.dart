import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'chat_models.dart';
import 'chat_service.dart';

class ChatState extends ChangeNotifier {
  ChatState(this._service);

  final ChatService _service;

  final List<ChatMessage> _messages = [];
  int? _chatId;
  IrtStage _stage = IrtStage.recording;
  bool _starting = true;
  bool _sending = false;
  bool _isDone = false;
  SafetyEvent? _safetyEvent;
  int? _retryAfterSeconds;
  String? _errorMessage;

  int? get chatId => _chatId;
  IrtStage get stage => _stage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get starting => _starting;
  bool get sending => _sending;
  bool get isDone => _isDone;
  SafetyEvent? get safetyEvent => _safetyEvent;
  int? get retryAfterSeconds => _retryAfterSeconds;
  String? get errorMessage => _errorMessage;

  /// Opens a chat once per state object; later calls are no-ops.
  Future<void> ensureStarted({required String language}) async {
    if (_chatId != null) return;
    _starting = true;
    _clearAlerts();
    notifyListeners();
    try {
      final res = await _service.start(language: language);
      _chatId = res.chatId;
      _stage = res.currentStage;
      _messages.clear();
      _isDone = false;
    } on ApiException catch (e) {
      _recordFailure(e);
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  Future<void> send(String content) async {
    final id = _chatId;
    if (id == null || _sending || content.trim().isEmpty) return;
    _sending = true;
    _clearAlerts();
    notifyListeners();
    try {
      final turn = await _service.sendMessage(chatId: id, content: content);
      _messages.add(turn.userMessage);
      if (turn.aiMessage != null) _messages.add(turn.aiMessage!);
      _stage = turn.stage;
      _isDone = turn.isDone;
      _safetyEvent = turn.safetyEvent;
    } on ApiException catch (e) {
      _recordFailure(e);
    } finally {
      _sending = false;
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

  void _clearAlerts() {
    _safetyEvent = null;
    _errorMessage = null;
    _retryAfterSeconds = null;
  }

  void _recordFailure(ApiException e) {
    if (e.isRateLimited) {
      _retryAfterSeconds = e.retryAfterSeconds ?? 0;
    } else {
      _errorMessage = e.message;
    }
  }
}
