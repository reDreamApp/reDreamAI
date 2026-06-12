import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import 'chat_models.dart';
import 'chat_state.dart';

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
      await _startChat(state);
    }
    if (mounted) setState(() => _starting = false);
  }

  Future<void> _startChat(ChatState state) async {
    final l10n = AppLocalizations.of(context)!;
    final lang =
        Localizations.localeOf(context).languageCode == 'de' ? 'de' : 'en';
    // Failures are surfaced via state.startFailed (error banner with retry).
    await state.startChat(language: lang, welcomeMessage: l10n.chatWelcomeMessage);
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _stageLabel(IrtStage stage, AppLocalizations l10n) {
    switch (stage) {
      case IrtStage.recording:
        return l10n.stageRecording;
      case IrtStage.intensity:
        return l10n.stageIntensity;
      case IrtStage.rewriting:
        return l10n.stageRewriting;
      case IrtStage.summary:
        return l10n.stageSummary;
      case IrtStage.finalStage:
        return l10n.stageFinal;
    }
  }

  Widget _buildComposer(ChatState state, AppLocalizations l10n) {
    if (state.isDone) {
      return _FinishedComposer(onStartNew: () => _startChat(state));
    }
    if (state.stage == IrtStage.intensity && !state.hasSubmittedIntensity) {
      return _IntensityComposer(
        key: ValueKey(state.chatId),
        enabled: !state.sending,
        onSubmit: state.submitIntensity,
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
                hintText: l10n.chatInputHint,
                border: const OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 4,
              enabled: !state.sending,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: state.sending
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ChatState>();
    final auth = context.read<IAuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: auth.signOut,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _stageLabel(state.stage, l10n),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.safetyEvent != null)
              _SafetyBanner(
                message: state.safetyEvent!.message,
                onDismiss: state.dismissSafetyEvent,
              ),
            if (state.retryAfterSeconds != null)
              _BudgetBanner(seconds: state.retryAfterSeconds!, onDismiss: state.dismissError),
            if (state.errorMessage != null && state.retryAfterSeconds == null)
              _ErrorBanner(
                body: state.startFailed ? l10n.chatStartErrorBody : l10n.chatErrorBody,
                retryLabel: state.startFailed ? l10n.chatRetry : null,
                onRetry: state.startFailed ? () => _startChat(state) : null,
                onDismiss: state.dismissError,
              ),
            Expanded(
              child: _starting
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) {
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
            if (state.sending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.chatThinking, style: Theme.of(context).textTheme.bodySmall),
              ),
            _buildComposer(state, l10n),
          ],
        ),
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
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({this.message, required this.onDismiss});

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
        TextButton(onPressed: onDismiss, child: Text(l10n.safetyHelplineButton)),
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

class _IntensityComposer extends StatefulWidget {
  const _IntensityComposer({required this.enabled, required this.onSubmit, super.key});
  final bool enabled;
  final Future<void> Function(int value) onSubmit;

  @override
  State<_IntensityComposer> createState() => _IntensityComposerState();
}

class _IntensityComposerState extends State<_IntensityComposer> {
  int _value = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Card(
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
                onPressed:
                    widget.enabled ? () => widget.onSubmit(_value) : null,
                child: Text(l10n.intensitySubmit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FinishedComposer extends StatelessWidget {
  const _FinishedComposer({required this.onStartNew});
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.chatFinishedNotice,
              style: Theme.of(context).textTheme.bodyMedium),
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
