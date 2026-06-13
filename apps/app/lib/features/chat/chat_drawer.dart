import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/language/language_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'chat_models.dart';
import 'chat_state.dart';

/// Chat-history drawer, ported from legacy chat_page.dart `openDrawer`:
/// gradient header, prominent "new chat" button, newest-first chat list
/// (finished sessions greyed with a check icon, view-only), delete via
/// trailing icon or long-press with confirmation, pull-to-refresh.
class ChatHistoryDrawer extends StatefulWidget {
  const ChatHistoryDrawer({super.key});

  @override
  State<ChatHistoryDrawer> createState() => _ChatHistoryDrawerState();
}

class _ChatHistoryDrawerState extends State<ChatHistoryDrawer> {
  @override
  void initState() {
    super.initState();
    // The drawer is (re)built each time it opens — refresh the list then.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ChatState>().loadChats());
    });
  }

  Future<void> _startNewChat() async {
    final state = context.read<ChatState>();
    final language = context.read<LanguageProvider>().selectedLanguage;
    final welcome = AppLocalizations.of(context)!.chatWelcomeMessage;
    Navigator.of(context).pop();
    await state.startChat(language: language, welcomeMessage: welcome);
  }

  Future<void> _openChat(ChatSummary chat) async {
    final state = context.read<ChatState>();
    final welcome = AppLocalizations.of(context)!.chatWelcomeMessage;
    Navigator.of(context).pop();
    await state.loadChat(chat.id, welcomeMessage: welcome);
  }

  Future<void> _confirmDelete(ChatSummary chat) async {
    final l10n = AppLocalizations.of(context)!;
    final state = context.read<ChatState>();
    final language = context.read<LanguageProvider>().selectedLanguage;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatDeleteTitle),
        content: Text(l10n.chatDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.chatDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.chatDeleteConfirm,
              style: TextStyle(color: Theme.of(dialogContext).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await state.deleteChat(chat.id);
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? l10n.chatDeleted : l10n.chatDeleteFailed)),
    );
    // Deleting the active chat clears the session — start a fresh one so
    // the chat screen never sits on a dead conversation.
    if (ok && state.chatId == null) {
      await state.startChat(
        language: language,
        welcomeMessage: l10n.chatWelcomeMessage,
      );
    }
  }

  String _formatChatDate(AppLocalizations l10n, DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(local.year, local.month, local.day))
        .inDays;
    if (days <= 0) return l10n.chatDateToday;
    if (days == 1) return l10n.chatDateYesterday;
    if (days < 7) return l10n.chatDaysAgo(days);
    return DateFormat.yMMMd(l10n.localeName).format(local);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = context.watch<ChatState>();
    final gradient = BrandColors.brandGradient();
    final headerColors =
        gradient.colors.map((c) => c.withValues(alpha: 0.5)).toList();
    final doneColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final doneTileColor = isDark ? Colors.grey.shade900 : Colors.grey.shade300;

    return Drawer(
      child: RefreshIndicator(
        onRefresh: () => context.read<ChatState>().loadChats(),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            DrawerHeader(
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerColors,
                    begin: gradient.begin,
                    end: gradient.end,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                  child: Column(
                    children: [
                      Text(
                        l10n.chatHistoryTitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.chatHistoryDescription,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: FilledButton.icon(
                onPressed: _startNewChat,
                icon: const Icon(Icons.add),
                label: Text(l10n.chatNewChat),
              ),
            ),
            const Divider(),
            if (state.chatsLoading && state.chats.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (!state.chatsLoading &&
                state.chatsError != null &&
                state.chats.isEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.chatHistoryError,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],
            for (final chat in state.chats)
              ListTile(
                leading: chat.isDone
                    ? Icon(Icons.check_circle, color: doneColor)
                    : null,
                tileColor: chat.isDone ? doneTileColor : null,
                title: Text(
                  chat.title ?? l10n.chatNewConversation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: chat.isDone ? doneColor : null,
                  ),
                ),
                subtitle: Text(
                  _formatChatDate(l10n, chat.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: chat.isDone
                        ? doneColor
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: l10n.chatDeleteTitle,
                  onPressed: () => _confirmDelete(chat),
                ),
                onTap: () => _openChat(chat),
                onLongPress: () => _confirmDelete(chat),
              ),
          ],
        ),
      ),
    );
  }
}
