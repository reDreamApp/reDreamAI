import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/journal/dream.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/journal/practice_chooser.dart';
import 'package:redream_app/features/journal/practice_helpers.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class DreamDetailScreen extends StatefulWidget {
  const DreamDetailScreen({required this.dream, super.key});

  final Dream dream;

  @override
  State<DreamDetailScreen> createState() => _DreamDetailScreenState();
}

class _DreamDetailScreenState extends State<DreamDetailScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _openingChat = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openChatHistory(Dream dream) async {
    final l10n = AppLocalizations.of(context)!;
    final chatId = dream.chatId;
    if (chatId == null) {
      showAppSnackBar(context, l10n.detailNoChatHistory);
      return;
    }
    setState(() => _openingChat = true);
    final chat = context.read<ChatState>();
    final tabs = context.read<ShellTabs>();
    try {
      await chat.loadChats();
      await chat.openChat(chatId);
      if (!mounted) return;
      tabs.select(ShellTab.session);
      Navigator.popUntil(context, (r) => r.isFirst);
    } on Exception catch (e) {
      if (mounted) {
        showAppSnackBar(context, describeError(e, l10n), error: true);
      }
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    final dream =
        context.watch<JournalState>().byId(widget.dream.id) ?? widget.dream;
    final twoSided = dream.isNightmare && dream.hasRewrite;
    final pages = twoSided
        ? [
            (l10n.detailRewritten, dream.rewrittenDream!),
            (l10n.detailOriginal, dream.originalDream),
          ]
        : [(l10n.detailDream, dream.originalDream)];

    return Scaffold(
      appBar: AppBar(
        title: Text(dream.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: AppCard(
                  padding: EdgeInsets.zero,
                  highlight: _page == 0 && twoSided,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _controller,
                          itemCount: pages.length,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemBuilder: (_, i) => SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pages[i].$1,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  pages[i].$2,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (twoSided)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: PageDots(count: pages.length, index: _page),
                        ),
                    ],
                  ),
                ),
              ),
              if (twoSided) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.detailSwipeHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: brand.muted,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: l10n.detailChatHistory,
                      icon: Icons.chat_bubble_outline,
                      style: AppButtonStyle.outlined,
                      busy: _openingChat,
                      onPressed: dream.chatId == null
                          ? null
                          : () => _openChatHistory(dream),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: l10n.detailStartPractice,
                      icon: Icons.adjust_rounded,
                      onPressed: dream.canPractice
                          ? () => showPracticeChooser(context, dream)
                          : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
