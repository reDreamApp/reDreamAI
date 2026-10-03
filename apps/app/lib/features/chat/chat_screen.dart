import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/brand_logo.dart';
import 'package:redream_app/core/widgets/intensity_slider.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/chat/message_bubble.dart';
import 'package:redream_app/features/chat/stage_indicator.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  int _lastCount = 0;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ChatState>().load());
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    await context.read<ChatState>().send(text);
  }

  Future<void> _openJournal() async {
    try {
      await context.read<JournalState>().refresh();
    } on Exception catch (_) {}
    if (mounted) context.read<ShellTabs>().select(ShellTab.journal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandTheme.of(context);
    final state = context.watch<ChatState>();

    final count = state.messages.length + (state.sending ? 1 : 0);
    if (count != _lastCount) {
      _lastCount = count;
      _scrollToBottom();
    }

    return Stack(
      children: [
        Column(
          children: [
            _Header(brand: brand),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: StageIndicator(
                path: state.stagePath,
                current: state.stage,
              ),
            ),
            const Divider(),
            Expanded(
              child: GestureDetector(
                onTap: FocusScope.of(context).unfocus,
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: count,
                  itemBuilder: (_, i) => i < state.messages.length
                      ? MessageBubble(message: state.messages[i])
                      : const _ThinkingBubble(),
                ),
              ),
            ),
            if (state.safetyEvent != null)
              _Banner(
                title: l10n.safetyHelplineTitle,
                body: l10n.safetyHelplineBody,
                background: scheme.errorContainer,
                foreground: scheme.onErrorContainer,
                actionLabel: l10n.safetyHelplineButton,
                onAction: () => launchUrl(
                  Uri.parse(l10n.safetyHelplineUrl),
                  mode: LaunchMode.externalApplication,
                ),
                onDismiss: state.dismissSafetyEvent,
              ),
            if (state.retryAfterSeconds != null)
              _Banner(
                title: l10n.budgetExceededTitle,
                body: l10n.budgetExceededBody,
                background: scheme.tertiaryContainer,
                foreground: scheme.onTertiaryContainer,
                onDismiss: state.dismissError,
              ),
            if (state.error != null && state.retryAfterSeconds == null)
              _Banner(
                body: describeError(state.error!, l10n),
                background: scheme.errorContainer,
                foreground: scheme.onErrorContainer,
                onDismiss: state.dismissError,
              ),
            if (state.failedMessage != null && !state.sending)
              _Banner(
                title: l10n.chatNotDelivered,
                body: _truncate(state.failedMessage!.content),
                background: scheme.errorContainer,
                foreground: scheme.onErrorContainer,
                actionLabel: l10n.chatResend,
                onAction: state.resend,
              ),
            const Divider(),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _composer(context, state, l10n),
              ),
            ),
          ],
        ),
        if (state.loadingHistory)
          Positioned.fill(
            child: ColoredBox(
              color: scheme.surface.withValues(alpha: 0.85),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(l10n.chatLoading),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _composer(
    BuildContext context,
    ChatState state,
    AppLocalizations l10n,
  ) {
    if (state.isDone) {
      return AppCard(
        highlight: true,
        padding: EdgeInsets.zero,
        onTap: _openJournal,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  l10n.chatSessionDoneCta,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (state.awaitingIntensity) {
      return _IntensityComposer(
        enabled: state.canSend,
        onSubmit: (v) => state.send('$v'),
      );
    }
    final canSend = state.canSend && _input.text.trim().isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: _input,
            minLines: 1,
            maxLines: 6,
            enabled: state.canSend,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.chatInputHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
            ),
            onSubmitted: canSend ? (_) => _send() : null,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: IconButton.filled(
            onPressed: canSend ? _send : null,
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
              foregroundColor: scheme.onSurface,
              disabledBackgroundColor: scheme.surfaceContainerHighest,
              disabledForegroundColor: scheme.onSurfaceVariant,
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ],
    );
  }

  static String _truncate(String s) =>
      s.length > 50 ? '${s.substring(0, 50)}…' : s;
}

class _Header extends StatelessWidget {
  const _Header({required this.brand});

  final BrandTheme brand;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandLogo(height: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.chatAssistantName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            l10n.chatSessionSubtitle,
            style: TextStyle(fontSize: 15, color: brand.muted),
          ),
        ],
      ),
    );
  }
}

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble();

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brand = BrandTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(width: 44),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: brand.assistantBubble,
              borderRadius: BorderRadius.circular(18),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 5),
                    _dot(i, scheme.onSurfaceVariant),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int i, Color color) {
    final phase = ((_controller.value * 3) - i).clamp(0.0, 1.0);
    final alpha = 0.3 + 0.7 * (1 - (phase * 2 - 1).abs());
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _IntensityComposer extends StatefulWidget {
  const _IntensityComposer({required this.enabled, required this.onSubmit});

  final bool enabled;
  final ValueChanged<int> onSubmit;

  @override
  State<_IntensityComposer> createState() => _IntensityComposerState();
}

class _IntensityComposerState extends State<_IntensityComposer> {
  int _value = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppCard(
      child: Column(
        children: [
          IntensitySlider(
            value: _value,
            title: l10n.chatIntensityPrompt,
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: l10n.submit,
            icon: Icons.check,
            onPressed: widget.enabled ? () => widget.onSubmit(_value) : null,
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.body,
    required this.background,
    required this.foreground,
    this.title,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
  });

  final String? title;
  final String body;
  final Color background;
  final Color foreground;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                Text(body, style: TextStyle(color: foreground, fontSize: 13)),
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: foreground),
              child: Text(actionLabel!),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: Icon(Icons.close, size: 18, color: foreground),
            ),
        ],
      ),
    );
  }
}
