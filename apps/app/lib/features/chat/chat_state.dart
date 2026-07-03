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
  bool _hasStreamingDraft = false;
  int _localSeq = 0;

  /// Bumped whenever the visible session is rebound ([startChat], [loadChat]
  /// of a different chat, [deleteChat] of the active chat). An in-flight
  /// [send] captures the value and stops applying stream events once it goes
  /// stale, so a reply streaming for one chat can never leak into another
  /// chat's message list or stage. A same-chat reload (pull-to-refresh) is
  /// not a rebind and does not bump the epoch.
  int _sessionEpoch = 0;

  List<ChatSummary> _chats = const [];
  bool _chatsLoading = false;
  String? _chatsError;
  bool _loadingChat = false;

  int? get chatId => _chatId;
  IrtStage get stage => _stage;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get sending => _sending;

  /// True while a send is in flight but no streamed draft bubble is showing
  /// yet — the window in which the UI shows the "thinking" indicator. Once
  /// deltas flow, the growing draft bubble itself is the feedback.
  bool get awaitingReply => _sending && !_hasStreamingDraft;
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
      _sessionEpoch++;
      // Rebinding the session: no send is in flight for the NEW session,
      // so the composer re-enables (a dying stale stream must not touch it).
      _sending = false;
      _hasStreamingDraft = false;
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
      if (id != _chatId) {
        // Rebinding to a DIFFERENT chat: in-flight sends for the old session
        // stop applying (epoch guard) and no send is in flight for the new
        // session, so the composer re-enables. A same-chat reload
        // (pull-to-refresh) is not a rebind — a still-running stream keeps
        // applying; send() dedupes against the refetched turn by message id.
        _sessionEpoch++;
        _sending = false;
        _hasStreamingDraft = false;
      }
      _chatId = id;
      _messages
        ..clear()
        ..addAll(fetched);
      if (fetched.isEmpty && welcomeMessage != null) {
        _messages.add(
          _localMessage(role: 'assistant', content: welcomeMessage),
        );
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
      _hasSubmittedIntensity =
          _stage == IrtStage.intensity &&
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
      _sessionEpoch++;
      // Rebinding the session: no send is in flight for the new session.
      _sending = false;
      _hasStreamingDraft = false;
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
    _hasStreamingDraft = false;
    _safetyEvent = null;
    _retryAfterSeconds = null;
    _errorMessage = null;
    notifyListeners();

    // The bubble currently holding the user's text: the optimistic local one
    // until the backend's persisted user_message frame replaces it.
    var userMessage = local;
    // Local assistant bubble whose content grows with each delta; replaced
    // by the persisted ai_message on done, dropped on safety/error. Content
    // accumulates in [draftContent]; [draftIndex] tracks the bubble's slot
    // in _messages so applying a delta is O(1) instead of an indexOf scan.
    ChatMessage? draft;
    var draftIndex = -1;
    final draftContent = StringBuffer();
    // Whether a terminal frame (done / safety / error) was seen.
    var terminal = false;
    // The session this send belongs to. Once the user rebinds the visible
    // session mid-stream (drawer tap, new chat, delete), every event below
    // would mutate ANOTHER chat's messages/stage — so we stop applying them.
    final epoch = _sessionEpoch;
    bool stale() => _sessionEpoch != epoch;

    // True when [draftIndex] still points at the draft bubble — a same-chat
    // reload may have rebuilt _messages underneath a running stream.
    bool draftInPlace() =>
        draft != null &&
        draftIndex >= 0 &&
        draftIndex < _messages.length &&
        identical(_messages[draftIndex], draft);

    void removeDraft() {
      final current = draft;
      if (current == null) return;
      if (draftInPlace()) {
        _messages.removeAt(draftIndex);
      } else {
        _messages.remove(current); // identity-based; no-op after a reload
      }
      draft = null;
      draftIndex = -1;
      _hasStreamingDraft = false;
    }

    try {
      final events = _service.sendMessageStream(chatId: id, content: content);
      await for (final event in events) {
        if (stale()) {
          // The server already persisted its side; reloading the chat shows
          // the turn. One exception: a safety event MUST still surface
          // (ADR 0005 — the helpline is about the user, not a specific chat).
          if (event is SafetyEventEvent) {
            _safetyEvent = event.safetyEvent;
            notifyListeners();
          }
          break; // leaves the await-for, cancelling the subscription
        }
        switch (event) {
          case UserMessageEvent(:final message):
            if (_messages.any((m) => m.id == message.id)) {
              // A same-chat reload already fetched the persisted message —
              // drop the optimistic bubble instead of adding a duplicate.
              final index = _messages.indexOf(userMessage);
              if (index != -1) {
                _messages.removeAt(index);
                if (index < draftIndex) draftIndex--;
              }
            } else {
              _replace(userMessage, message);
            }
            userMessage = message;
          case ContentDeltaEvent(:final delta):
            draftContent.write(delta);
            final current = draft;
            final grown = current == null
                ? _localMessage(
                    role: 'assistant',
                    content: draftContent.toString(),
                  )
                : ChatMessage(
                    id: current.id,
                    role: current.role,
                    content: draftContent.toString(),
                    stage: current.stage,
                    createdAt: current.createdAt,
                  );
            if (draftInPlace()) {
              _messages[draftIndex] = grown;
            } else {
              // First delta, or a same-chat reload rebuilt the list — the
              // buffer holds the full reply so far, so re-adding loses
              // nothing.
              _messages.add(grown);
              draftIndex = _messages.length - 1;
            }
            draft = grown;
            _hasStreamingDraft = true;
          case DoneEvent(:final aiMessage, :final stage, :final isDone):
            removeDraft();
            // A same-chat reload may have already fetched the finalized
            // turn — don't add the persisted ai message twice.
            if (!_messages.any((m) => m.id == aiMessage.id)) {
              _messages.add(aiMessage);
            }
            _stage = stage;
            _isDone = isDone;
            if (_stage != IrtStage.intensity) _hasSubmittedIntensity = false;
            terminal = true;
          case SafetyEventEvent(:final safetyEvent):
            // Mandatory helpline handling (ADR 0005): surface the event; no
            // AI turn happened and the stage does NOT advance.
            removeDraft();
            _safetyEvent = safetyEvent;
            terminal = true;
          case ErrorEvent(:final message):
            // The backend rolled back the user message — mark the bubble
            // failed so the existing retry flow can resend it.
            removeDraft();
            _failedMessageId = userMessage.id;
            _errorMessage = message;
            terminal = true;
        }
        notifyListeners();
      }
      if (!terminal && !stale()) {
        // Stream ended without done/safety/error (connection dropped). The
        // server may nevertheless have finished and persisted the turn —
        // reconcile against the backend before declaring the send failed,
        // so a retry can't duplicate a server-persisted turn.
        var reconciled = false;
        try {
          final fetched = await _service.listMessages(id);
          if (!stale() && _turnPersisted(fetched, content)) {
            _messages
              ..clear()
              ..addAll(fetched);
            draft = null;
            draftIndex = -1;
            _hasStreamingDraft = false;
            _stage = _stageFromMessages(fetched);
            if (_stage != IrtStage.intensity) _hasSubmittedIntensity = false;
            _failedMessageId = null;
            _errorMessage = null;
            reconciled = true;
          }
        } on Exception {
          // Reconcile fetch failed — fall back to the failed/retry path.
        }
        if (!reconciled && !stale()) {
          // The turn is absent server-side (rolled back): treat like a
          // mid-stream error so the retry flow can resend.
          removeDraft();
          _failedMessageId = userMessage.id;
          _errorMessage = 'stream interrupted';
        }
      }
    } on ApiException catch (e) {
      if (stale()) {
        // The failure belongs to a session that is no longer on screen —
        // touching _messages / _failedMessageId / the 409 is-done state
        // would corrupt the WRONG chat. But session-INDEPENDENT feedback
        // still surfaces: the token budget is per-user, so its banner is
        // global (ADR 0008), and other failures still deserve an error
        // banner. The 409 "chat is finished" case is purely session-scoped
        // and stays skipped.
        if (e.isRateLimited) {
          _retryAfterSeconds = e.retryAfterSeconds;
        } else if (e.statusCode != 409) {
          _errorMessage = e.message;
        }
      } else {
        removeDraft();
        if (e.statusCode == 409) {
          // The chat finished on the backend (stale local state) — drop the
          // optimistic message and show the finished, read-only view.
          _messages.remove(userMessage);
          _isDone = true;
          _resumedDone = true;
          _stage = IrtStage.finalStage;
        } else if (e.isRateLimited) {
          _failedMessageId = userMessage.id;
          _retryAfterSeconds = e.retryAfterSeconds;
        } else {
          _failedMessageId = userMessage.id;
          _errorMessage = e.message;
        }
      }
    } on Exception catch (e) {
      // Transport failure mid-stream: keep the user's bubble and let the
      // existing retry flow resend it (the backend rolls back on failure).
      if (!stale()) {
        removeDraft();
        _failedMessageId = userMessage.id;
        _errorMessage = e.toString();
      }
    } finally {
      if (!stale()) {
        // A stale send belongs to a replaced session — its end must not
        // clear the flags of a send that may be running for the CURRENT
        // session (the rebind already reset them).
        _sending = false;
        _hasStreamingDraft = false;
      }
      notifyListeners();
    }
  }

  /// True when [fetched] shows the server completed the turn for [content]:
  /// the last user message matches the sent content and at least one
  /// assistant message follows it.
  bool _turnPersisted(List<ChatMessage> fetched, String content) {
    for (var i = fetched.length - 1; i >= 0; i--) {
      if (!fetched[i].isUser) continue;
      return fetched[i].content == content &&
          fetched.skip(i + 1).any((m) => !m.isUser);
    }
    return false;
  }

  /// Replaces [from] with [to] in place (appends when [from] is gone).
  void _replace(ChatMessage from, ChatMessage to) {
    final index = _messages.indexOf(from);
    if (index == -1) {
      _messages.add(to);
    } else {
      _messages[index] = to;
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
    // Capture the session before awaiting: when the user rebinds mid-send
    // (drawer tap / new chat / delete), the abandoned send must not mark
    // the NEW session's intensity as submitted.
    final epoch = _sessionEpoch;
    await send(value.toString());
    if (_failedMessageId == null && _sessionEpoch == epoch) {
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
