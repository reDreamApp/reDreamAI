import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import 'draft_models.dart';
import 'draft_repository.dart';
import 'dream_editor_page.dart';

/// Record tab: a list of local-only dream drafts plus a prominent "New dream"
/// entry point. Drafts are text-only (no audio) and live on-device until the
/// user saves them to their collection.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final IDraftRepository _repository = SharedPrefsDraftRepository();

  List<DreamDraft> _drafts = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final drafts = await _repository.list();
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _loading = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({DreamDraft? draft}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DreamEditorPage(repository: _repository, draft: draft),
      ),
    );
    await _load();
  }

  Future<void> _confirmDelete(DreamDraft draft) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.recordDeleteTitle),
        content: Text(l10n.recordDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.recordDeleteCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.recordDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await _repository.delete(draft.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = context.watch<ThemeProvider>().isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.recordTitle),
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: Text(l10n.recordNewDream),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandColors.backgroundGradient(isDark),
        ),
        child: SafeArea(child: _buildBody(l10n)),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return _CenteredMessage(
        icon: Icons.error_outline,
        title: l10n.recordLoadError,
        action: TextButton(onPressed: _load, child: Text(l10n.chatRetry)),
      );
    }
    if (_drafts.isEmpty) {
      return _CenteredMessage(
        icon: Icons.nights_stay_outlined,
        title: l10n.recordEmptyTitle,
        body: l10n.recordEmptyBody,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _drafts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _DraftCard(
          draft: _drafts[i],
          onTap: () => _openEditor(draft: _drafts[i]),
          onDelete: () => _confirmDelete(_drafts[i]),
        ),
      ),
    );
  }
}

class _DraftCard extends StatelessWidget {
  const _DraftCard({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  final DreamDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = draft.title.trim().isEmpty
        ? l10n.recordUntitled
        : draft.title.trim();
    final snippet = draft.originalDream.trim();
    final dateLabel = l10n.recordUpdatedAt(
      DateFormat.yMMMd(
        Localizations.localeOf(context).toString(),
      ).add_jm().format(draft.updatedAt.toLocal()),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (draft.isNightmare)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (snippet.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      dateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.recordDeleteTooltip,
                color: theme.colorScheme.error,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
