import 'package:flutter/foundation.dart';

import 'package:redream_app/core/api/api_exception.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_service.dart';

/// One IRT conversation plus the list of past chats. The server chat is
/// created lazily on the first send so abandoned sessions leave no rows.
class ChatState extends ChangeNotifier {
  ChatState(this._service, {required String Function() language})
    : _language = language {
    _showWelcome();
  }

  static const welcomeId = 'welcome';

  final ChatService _service;
  final String Function() _language;

  List<ChatMessage> _messages = [];
  int? _chatId;
  IrtStage _stage = IrtStage.recording;
  bool? _isNightmare;
  bool _isDone = false;
  bool _hasSubmittedIntensity = false;
  bool _sending = false;
  bool _loadingHistory = false;
  List<ChatSummary> _chats = [];
  bool _chatsLoaded = false;
  Future<void>? _chatsLoading;
  bool _chatsLoadFailed = false;
  SafetyEvent? _safetyEvent;
  int? _retryAfterSeconds;
  Object? _error;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  int? get chatId => _chatId;
  IrtStage get stage => _stage;
  bool? get isNightmare => _isNightmare;
  bool get isDone => _isDone;
  bool get sending => _sending;
  bool get loadingHistory => _loadingHistory;
  List<ChatSummary> get chats => List.unmodifiable(_chats);
  bool get chatsLoaded => _chatsLoaded;
  bool get chatsLoadFailed => _chatsLoadFailed;
  SafetyEvent? get safetyEvent => _safetyEvent;
  int? get retryAfterSeconds => _retryAfterSeconds;
  Object? get error => _error;

  /// Stage path for the progress indicator; unknown ⇒ assume nightmare.
  List<IrtStage> get stagePath =>
      IrtStage.path(nightmare: _isNightmare ?? true);

  /// True while the intensity slider should replace the text composer.
  bool get awaitingIntensity =>
      !_isDone && _stage == IrtStage.intensity && !_hasSubmittedIntensity;

  ChatMessage? get failedMessage =>
      _messages.where((m) => m.status == MessageStatus.failed).lastOrNull;

  bool get canSend => !_sending && !_isDone && !_loadingHistory;

  Future<void> load() async {
    if (_chatsLoaded) return;
    await (_chatsLoading ??= loadChats());
  }

  Future<void> loadChats() async {
    try {
      _chats = await _service.listChats();
      _chatsLoadFailed = false;
    } on Exception catch (_) {
      _chatsLoadFailed = true;
    } finally {
      _chatsLoaded = true;
      _chatsLoading = null;
      notifyListeners();
    }
  }

  void startNewChat() {
    _chatId = null;
    _stage = IrtStage.recording;
    _isNightmare = null;
    _isDone = false;
    _hasSubmittedIntensity = false;
    _clearAlerts();
    _showWelcome();
    notifyListeners();
  }

  Future<void> openChat(int chatId) async {
    _loadingHistory = true;
    _clearAlerts();
    notifyListeners();
    try {
      final history = await _service.listMessages(chatId);
      final summary = _chats.where((c) => c.id == chatId).firstOrNull;
      _chatId = chatId;
      _messages = history;
      _isDone = summary?.isDone ?? false;
      _stage = _isDone
          ? IrtStage.finalStage
          : summary?.stage ?? IrtStage.fromWire(history.lastOrNull?.stage);
      _isNightmare = summary?.isNightmare ?? _inferNightmare(history);
      final lastUser = history.where((m) => m.isUser).lastOrNull;
      _hasSubmittedIntensity =
          _stage == IrtStage.intensity && _isIntensity(lastUser?.content);
    } on Exception catch (e) {
      _error = e;
    } finally {
      _loadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || !canSend) return;
    _sending = true;
    _clearAlerts();
    _messages = [
      ..._messages.where((m) => m.status != MessageStatus.failed),
      ChatMessage.local(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        role: 'user',
        content: content,
        status: MessageStatus.sending,
      ),
    ];
    notifyListeners();

    final sentIntensity = _stage == IrtStage.intensity && _isIntensity(content);
    try {
      final id = _chatId ??= (await _service.start(
        language: _language(),
      )).chatId;
      final turn = await _service.sendMessage(chatId: id, content: content);
      _messages = [
        ..._messages.where((m) => m.status != MessageStatus.sending),
        turn.userMessage,
        ?turn.aiMessage,
      ];
      _safetyEvent = turn.safetyEvent;
      if (turn.safetyEvent == null) {
        final previous = _stage;
        _stage = turn.stage;
        _isDone = turn.isDone;
        _isNightmare = _nightmareFromStage(turn.stage) ?? _isNightmare;
        _hasSubmittedIntensity =
            turn.stage == IrtStage.intensity &&
            (sentIntensity || _hasSubmittedIntensity);
        if (previous == IrtStage.recording || turn.isDone) await loadChats();
      }
    } on Exception catch (e) {
      _markLastFailed();
      if (e is ApiException && e.isRateLimited) {
        _retryAfterSeconds = e.retryAfterSeconds ?? 0;
      } else if (e is ApiException && e.isConflict) {
        _isDone = true;
        _error = e;
      } else {
        _error = e;
      }
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> resend() async {
    final failed = failedMessage;
    if (failed == null) return;
    await send(failed.content);
  }

  Future<void> deleteChat(int chatId) async {
    await _service.deleteChat(chatId);
    _chats = _chats.where((c) => c.id != chatId).toList();
    if (_chatId == chatId) startNewChat();
    notifyListeners();
  }

  Future<void> report(
    ChatMessage message, {
    required ReportReason reason,
    String? details,
  }) async {
    final id = _chatId;
    if (id == null || message.isLocal) {
      throw StateError('message not on server');
    }
    await _service.report(
      chatId: id,
      message: message,
      reason: reason,
      details: details,
    );
  }

  void dismissSafetyEvent() {
    _safetyEvent = null;
    notifyListeners();
  }

  void dismissError() {
    _error = null;
    _retryAfterSeconds = null;
    notifyListeners();
  }

  void resetForUser() {
    _chats = [];
    _chatsLoaded = false;
    _chatsLoadFailed = false;
    startNewChat();
  }

  void _showWelcome() {
    _messages = [
      ChatMessage.local(id: welcomeId, role: 'assistant', content: ''),
    ];
  }

  void _markLastFailed() {
    _messages = [
      for (final m in _messages)
        m.status == MessageStatus.sending
            ? m.copyWith(status: MessageStatus.failed)
            : m,
    ];
  }

  void _clearAlerts() {
    _safetyEvent = null;
    _error = null;
    _retryAfterSeconds = null;
  }

  static bool _isIntensity(String? text) {
    final v = int.tryParse((text ?? '').trim());
    return v != null && v >= 0 && v <= 10;
  }

  static bool? _nightmareFromStage(IrtStage stage) => switch (stage) {
    IrtStage.intensity || IrtStage.rewriting => true,
    _ => null,
  };

  static bool? _inferNightmare(List<ChatMessage> history) {
    final stages = history.map((m) => m.stage).toSet();
    if (stages.contains('intensity') || stages.contains('rewriting')) {
      return true;
    }
    if (stages.contains('summary')) return false;
    return null;
  }
}
