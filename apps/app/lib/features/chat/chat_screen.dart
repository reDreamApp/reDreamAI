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
      final lang = Localizations.localeOf(context).languageCode == 'de' ? 'de' : 'en';
      try {
        await state.startChat(language: lang);
      } catch (_) {
        // surfaced via state.errorMessage on the next send
      }
    }
    if (mounted) setState(() => _starting = false);
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
            if (state.safetyEvent != null) _SafetyBanner(onDismiss: state.dismissSafetyEvent),
            if (state.retryAfterSeconds != null)
              _BudgetBanner(seconds: state.retryAfterSeconds!, onDismiss: state.dismissError),
            Expanded(
              child: _starting
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: state.messages.length,
                      itemBuilder: (_, i) => _Bubble(message: state.messages[i]),
                    ),
            ),
            if (state.sending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l10n.chatThinking, style: Theme.of(context).textTheme.bodySmall),
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
                      enabled: !state.sending && !state.isDone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: state.sending || state.isDone
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
    final isUser = message.isUser;
    final bg = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Text(message.content),
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner({required this.onDismiss});
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text('${l10n.safetyHelplineTitle}\n${l10n.safetyHelplineBody}'),
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
