import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/formatting.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class ChatHistoryDrawer extends StatelessWidget {
  const ChatHistoryDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<ChatState>();
    final brand = BrandTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    for (final c in brand.accentGradient.colors)
                      c.withValues(alpha: 0.35),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.chatHistoryTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.chatHistoryBody,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.chatNewChat),
              onTap: () {
                state.startNewChat();
                Navigator.pop(context);
              },
            ),
            const Divider(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: state.loadChats,
                child: _ChatList(state: state),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatList extends StatelessWidget {
  const _ChatList({required this.state});

  final ChatState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (state.chats.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 48),
          Icon(
            state.chatsLoadFailed
                ? Icons.cloud_off_outlined
                : Icons.chat_bubble_outline,
            size: 48,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            state.chatsLoadFailed
                ? l10n.chatHistoryLoadFailed
                : l10n.chatHistoryEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return ListView.builder(
      itemCount: state.chats.length,
      itemBuilder: (_, i) => _ChatTile(chat: state.chats[i], state: state),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, required this.state});

  final ChatSummary chat;
  final ChatState state;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await confirmDialog(
      context,
      title: l10n.chatDeleteTitle,
      body: l10n.chatDeleteBody,
      confirmLabel: l10n.delete,
      cancelLabel: l10n.cancel,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    try {
      await state.deleteChat(chat.id);
      if (context.mounted) showAppSnackBar(context, l10n.chatDeleted);
    } on Exception catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.chatDeleteFailed, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final date = formatRelativeDay(chat.createdAt, l10n);
    final muted = chat.isDone ? scheme.onSurfaceVariant : null;
    final selected = state.chatId == chat.id;

    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.4),
      leading: chat.isDone
          ? Icon(Icons.check_circle, color: scheme.onSurfaceVariant)
          : const Icon(Icons.chat_bubble_outline),
      title: Text(
        chat.title ?? date,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontWeight: FontWeight.w500, color: muted),
      ),
      subtitle: Text(
        chat.title == null
            ? (chat.isDone ? l10n.chatFinishedLabel : '')
            : (chat.isDone ? '$date · ${l10n.chatFinishedLabel}' : date),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _delete(context),
      ),
      onTap: () {
        Navigator.pop(context);
        unawaited(state.openChat(chat.id));
      },
    );
  }
}
