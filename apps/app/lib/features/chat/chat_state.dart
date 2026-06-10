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

  int? get chatId => _chatId;
  IrtStage get stage => _stage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;
  bool get isDone => _isDone;
  SafetyEvent? get safetyEvent => _safetyEvent;
  int? get retryAfterSeconds => _retryAfterSeconds;
  String? get errorMessage => _errorMessage;

  Future<void> startChat({required String language}) async {
    final res = await _service.start(language: language);
    _chatId = res.chatId;
    _stage = res.currentStage;
    _messages.clear();
    _isDone = false;
    _safetyEvent = null;
    _retryAfterSeconds = null;
    _errorMessage = null;
    notifyListeners();
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
    _sending = true;
    _safetyEvent = null;
    _retryAfterSeconds = null;
    _errorMessage = null;
    notifyListeners();
    try {
      final turn = await _service.sendMessage(chatId: id, content: content);
      _messages.add(turn.userMessage);
      if (turn.aiMessage != null) _messages.add(turn.aiMessage!);
      _stage = turn.stage;
      _isDone = turn.isDone;
      _safetyEvent = turn.safetyEvent;
    } on ApiException catch (e) {
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
}
