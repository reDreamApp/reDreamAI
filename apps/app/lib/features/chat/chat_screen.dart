import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language/language_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../collection/collection_state.dart';
import '../shell/tab_navigator.dart';
import 'chat_models.dart';
import 'chat_state.dart';
import 'stage_progress.dart';

/// Chat tab body. Rendered inside MainScreen's Scaffold (IndexedStack) —
/// no own Scaffold/AppBar; the history drawer is mounted by MainScreen.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final state = context.read<ChatState>();
    if (state.chatId == null) {
      // Resume the most recent open chat; otherwise start fresh.
      await _resumeOrStart(state);
    }
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _resumeOrStart(ChatState state) async {
    final l10n = AppLocalizations.of(context)!;
    final language = context.read<LanguageProvider>().selectedLanguage;
    // Failures are surfaced via state.startFailed (error banner with retry).
    await state.resumeOrStart(
      language: language,
      welcomeMessage: l10n.chatWelcomeMessage,
    );
  }

  Future<void> _startChat(ChatState state) async {
    final l10n = AppLocalizations.of(context)!;
    final language = context.read<LanguageProvider>().selectedLanguage;
    await state.startChat(
      language: language,
      welcomeMessage: l10n.chatWelcomeMessage,
    );
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Widget _buildComposer(ChatState state, AppLocalizations l10n) {
    if (state.isDone) {
      return _FinishedPanel(
        readOnly: state.resumedDone,
        onStartNew: () => _startChat(state),
        intensityCard: state.resumedDone || state.intensitySubmitted
            ? null
            : _IntensityCard(
                key: ValueKey(state.chatId),
                enabled: !state.intensitySaving,
                onSubmit: state.submitIntensity,
              ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              decoration: InputDecoration(
                hintText: state.recording
                    ? l10n.chatMicRecording
                    : l10n.chatInputHint,
                border: const OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
              enabled: !state.sending,
            ),
          ),
          if (state.voiceInputAvailable) ...[
            const SizedBox(width: 4),
            _MicButton(state: state, onTranscript: _appendToInput),
          ],
          const SizedBox(width: 8),
          FilledButton(
            onPressed: state.sending || state.recording || state.transcribing
                ? null
                : () async {
                    final text = _input.text;
                    _input.clear();
                    await state.send(text);
                  },
            child: Text(l10n.chatSend),
          ),
        ],
      ),
    );
  }

  void _appendToInput(String transcript) {
    final existing = _input.text.trimRight();
    _input.text = existing.isEmpty ? transcript : '$existing $transcript';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ChatState>();

    return SafeArea(
      child: Column(
        children: [
          StageProgressBar(stage: state.stage),
          if (state.safetyEvent != null)
            _SafetyBanner(
              message: state.safetyEvent!.message,
              onDismiss: state.dismissSafetyEvent,
            ),
          if (state.retryAfterSeconds != null)
            _BudgetBanner(
              seconds: state.retryAfterSeconds!,
              onDismiss: state.dismissError,
            ),
          if (state.errorMessage != null && state.retryAfterSeconds == null)
            _ErrorBanner(
              body: state.startFailed
                  ? l10n.chatStartErrorBody
                  : l10n.chatErrorBody,
              retryLabel: state.startFailed ? l10n.chatRetry : null,
              onRetry: state.startFailed ? () => _resumeOrStart(state) : null,
              onDismiss: state.dismissError,
            ),
          if (state.micPermissionDenied)
            _ErrorBanner(
              body: l10n.chatMicPermissionDenied,
              onDismiss: state.dismissError,
            ),
          Expanded(
            child: _starting
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        context.read<ChatState>().refreshCurrentChat(
                          welcomeMessage: l10n.chatWelcomeMessage,
                        ),
                    child: AnimatedOpacity(
                      opacity: state.loadingChat ? 0.4 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount:
                            state.messages.length +
                            (state.awaitingReply ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == state.messages.length) {
                            return const _ThinkingBubble();
                          }
                          final message = state.messages[i];
                          final failed = message.id == state.failedMessageId;
                          return _Bubble(
                            message: message,
                            failed: failed,
                            onRetry: failed ? state.retryFailedSend : null,
                          );
                        },
                      ),
                    ),
                  ),
          ),
          _buildComposer(state, l10n),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.failed = false, this.onRetry});
  final ChatMessage message;
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isUser = message.isUser;
    final bg = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: failed
            ? Border.all(color: Theme.of(context).colorScheme.error)
            : null,
      ),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message.content),
          if (failed) ...[
            const SizedBox(height: 4),
            Text(
              l10n.chatMessageFailed,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: failed ? GestureDetector(onTap: onRetry, child: bubble) : bubble,
    );
  }
}

/// Animated "thinking" bubble shown in the list while a send is in flight
/// (legacy: WaitingForResponseBuilder / IsTypingIndicator).
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: const BorderRadius.all(Radius.circular(120)),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
          ),
          child: Text(
            l10n.chatThinking,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.onDismiss, this.message});

  /// Backend-localized helpline text; falls back to bundled copy when absent.
  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final body = message ?? l10n.safetyHelplineBody;
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text('${l10n.safetyHelplineTitle}\n$body'),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: Text(l10n.safetyHelplineButton),
        ),
      ],
    );
  }
}

class _BudgetBanner extends StatelessWidget {
  const _BudgetBanner({required this.seconds, required this.onDismiss});
  final int seconds;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
      content: Text('${l10n.budgetExceededTitle}\n${l10n.budgetExceededBody}'),
      actions: [
        TextButton(onPressed: onDismiss, child: const Text('OK')),
      ],
    );
  }
}

/// Mic toggle in the composer: idle → start recording; recording → stop,
/// transcribe, and hand the transcript to [onTranscript] (appended to the
/// input field — the user reviews and sends it like typed text).
class _MicButton extends StatelessWidget {
  const _MicButton({required this.state, required this.onTranscript});

  final ChatState state;
  final ValueChanged<String> onTranscript;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (state.transcribing) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (state.recording) {
      // Voice-message convention: recording runs until the user picks
      // discard (red ✕) or use (green ✓) — no single ambiguous stop button.
      final colorScheme = Theme.of(context).colorScheme;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filled(
            tooltip: l10n.chatMicCancel,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.error,
              foregroundColor: colorScheme.onError,
            ),
            icon: const Icon(Icons.close),
            onPressed: () => state.cancelRecording(),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            tooltip: l10n.chatMicStop,
            style: IconButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.check),
            onPressed: () async {
              final transcript = await state.stopRecording();
              if (transcript != null) onTranscript(transcript);
            },
          ),
        ],
      );
    }
    return IconButton(
      tooltip: l10n.chatMicRecord,
      icon: const Icon(Icons.mic),
      onPressed: state.sending ? null : () => state.startRecording(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.body,
    required this.onDismiss,
    this.retryLabel,
    this.onRetry,
  });

  final String body;
  final String? retryLabel;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text(body),
      actions: [
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(retryLabel!)),
        TextButton(onPressed: onDismiss, child: Text(l10n.chatErrorDismiss)),
      ],
    );
  }
}

/// 0-10 rating card shown on the finished panel. The routed chat no longer
/// elicits the rating, so the app collects it here and saves it onto the
/// dream created from this chat (`PUT /chats/{id}/intensity`).
class _IntensityCard extends StatefulWidget {
  const _IntensityCard({
    required this.enabled,
    required this.onSubmit,
    super.key,
  });
  final bool enabled;
  final Future<void> Function(int value) onSubmit;

  @override
  State<_IntensityCard> createState() => _IntensityCardState();
}

class _IntensityCardState extends State<_IntensityCard> {
  int _value = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.intensityTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Slider(
              value: _value.toDouble(),
              max: 10,
              divisions: 10,
              label: '$_value',
              onChanged: widget.enabled
                  ? (v) => setState(() => _value = v.round())
                  : null,
            ),
            FilledButton(
              onPressed: widget.enabled ? () => widget.onSubmit(_value) : null,
              child: Text(l10n.intensitySubmit),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom panel for a finished session. Live finish: intensity rating card
/// (until submitted) + "new dream" card + notice + new-session button.
/// Resumed finished chat: read-only notice only (legacy: finished sessions
/// can only be viewed).
class _FinishedPanel extends StatelessWidget {
  const _FinishedPanel({
    required this.readOnly,
    required this.onStartNew,
    this.intensityCard,
  });

  final bool readOnly;
  final VoidCallback onStartNew;

  /// Non-null while the just-finished session's dream still wants its
  /// 0-10 rating; null once submitted or on read-only resumes.
  final Widget? intensityCard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (readOnly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Text(
          l10n.chatFinishedReadOnly,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (intensityCard != null) ...[
            intensityCard!,
            const SizedBox(height: 8),
          ],
          const _NewDreamCard(),
          const SizedBox(height: 8),
          Text(
            l10n.chatFinishedNotice,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: onStartNew,
            child: Text(l10n.chatStartNewSession),
          ),
        ],
      ),
    );
  }
}

/// Legacy tertiary "Let's look at your new dream!" card: refreshes the
/// dream collection, then switches to the collection tab.
class _NewDreamCard extends StatelessWidget {
  const _NewDreamCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final collection = context.read<DreamCollectionState>();
          final tabs = context.read<TabNavigator>();
          await collection.refresh();
          tabs.goTo(AppTabs.collection);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          color: scheme.tertiary,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.favorite, size: 24, color: scheme.onTertiary),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.chatViewNewDream,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
