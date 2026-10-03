import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/utils/formatting.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, super.key});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = BrandTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    final failed = message.status == MessageStatus.failed;
    final text = message.id == ChatState.welcomeId && message.content.isEmpty
        ? l10n.chatWelcome
        : message.content;
    final textColor = isUser ? brand.onUserBubble : scheme.onSurface;

    final bubble = GestureDetector(
      onLongPress: () => _showActions(context),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          color: isUser ? brand.userBubble : brand.assistantBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border: failed ? Border.all(color: scheme.error, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(fontSize: 15, height: 1.4, color: textColor),
            ),
            const SizedBox(height: 6),
            Text(
              failed ? l10n.chatNotDelivered : formatTime(message.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: failed ? scheme.error : textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[const _AssistantAvatar(), const SizedBox(width: 8)],
          Flexible(child: bubble),
          if (isUser) ...[const SizedBox(width: 8), const _UserAvatar()],
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<ChatState>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(l10n.chatCopy),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: message.content));
                if (!sheet.mounted) return;
                Navigator.pop(sheet);
                if (context.mounted) showAppSnackBar(context, l10n.chatCopied);
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.chatReport),
              onTap: () {
                Navigator.pop(sheet);
                if (message.isLocal || state.chatId == null) {
                  showAppSnackBar(context, l10n.chatReportNotReady);
                  return;
                }
                unawaited(
                  showDialog<void>(
                    context: context,
                    builder: (_) =>
                        _ReportDialog(message: message, state: state),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Image.asset(
        dark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();

  @override
  Widget build(BuildContext context) {
    final brand = BrandTheme.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: brand.inverseSurface,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.person_outline,
        size: 20,
        color: brand.onInverseSurface,
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.message, required this.state});

  final ChatMessage message;
  final ChatState state;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason _reason = ReportReason.other;
  final _details = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _label(ReportReason r, AppLocalizations l10n) => switch (r) {
    ReportReason.childSafety => l10n.reasonChildSafety,
    ReportReason.selfHarm => l10n.reasonSelfHarm,
    ReportReason.sexual => l10n.reasonSexual,
    ReportReason.hate => l10n.reasonHate,
    ReportReason.violence => l10n.reasonViolence,
    ReportReason.harassment => l10n.reasonHarassment,
    ReportReason.deceptive => l10n.reasonDeceptive,
    ReportReason.other => l10n.reasonOther,
  };

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await widget.state.report(
        widget.message,
        reason: _reason,
        details: _details.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnackBar(context, l10n.chatReportThanks);
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnackBar(
        context,
        l10n.chatReportFailed(describeError(e, l10n)),
        error: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.chatReportTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<ReportReason>(
            initialValue: _reason,
            decoration: InputDecoration(labelText: l10n.chatReportReason),
            items: [
              for (final r in ReportReason.values)
                DropdownMenuItem(value: r, child: Text(_label(r, l10n))),
            ],
            onChanged: _busy ? null : (r) => setState(() => _reason = r!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 3,
            enabled: !_busy,
            decoration: InputDecoration(labelText: l10n.chatReportDetails),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.submit),
        ),
      ],
    );
  }
}
