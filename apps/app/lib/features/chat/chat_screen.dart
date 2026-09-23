import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_service.dart';
import '../../l10n/generated/app_localizations.dart';
import 'chat_models.dart';
import 'chat_state.dart';

extension on IrtStage {
  String label(AppLocalizations l10n) => switch (this) {
    IrtStage.recording => l10n.stageRecording,
    IrtStage.intensity => l10n.stageIntensity,
    IrtStage.rewriting => l10n.stageRewriting,
    IrtStage.summary => l10n.stageSummary,
    IrtStage.finalStage => l10n.stageFinal,
  };
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final locale = Localizations.localeOf(context).languageCode;
      unawaited(
        context.read<ChatState>().ensureStarted(
          language: locale == 'de' ? 'de' : 'en',
        ),
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    await context.read<ChatState>().send(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = context.watch<ChatState>();
    final canSend = !state.sending && !state.isDone && !state.starting;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chatTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: context.read<AuthService>().signOut,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(32),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              state.stage.label(l10n),
              style: theme.textTheme.labelMedium,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.safetyEvent != null)
              _Banner(
                text: '${l10n.safetyHelplineTitle}\n${l10n.safetyHelplineBody}',
                background: theme.colorScheme.errorContainer,
                actionLabel: l10n.safetyHelplineButton,
                onDismiss: state.dismissSafetyEvent,
              ),
            if (state.retryAfterSeconds != null)
              _Banner(
                text: '${l10n.budgetExceededTitle}\n${l10n.budgetExceededBody}',
                background: theme.colorScheme.tertiaryContainer,
                onDismiss: state.dismissError,
              ),
            if (state.errorMessage != null)
              _Banner(
                text: state.errorMessage!,
                background: theme.colorScheme.errorContainer,
                onDismiss: state.dismissError,
              ),
            Expanded(
              child: state.starting
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) =>
                          _Bubble(message: state.messages[i]),
                    ),
            ),
            if (state.sending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  l10n.chatThinking,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            Padding(
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
                      enabled: canSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: canSend
                        ? () async {
                            await _send();
                          }
                        : null,
                    child: Text(l10n.chatSend),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: message.isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Text(message.content),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.background,
    required this.onDismiss,
    this.actionLabel,
  });

  final String text;
  final Color background;
  final VoidCallback onDismiss;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: background,
      content: Text(text),
      actions: [
        TextButton(onPressed: onDismiss, child: Text(actionLabel ?? 'OK')),
      ],
    );
  }
}
