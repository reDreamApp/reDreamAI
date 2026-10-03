import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/features/learn/article.dart';
import 'package:redream_app/features/learn/article_screen.dart';
import 'package:redream_app/features/learn/articles_service.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _service = ArticlesService();
  late Future<List<Article>> _future;
  String? _language;
  String? _selectedTag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context.watch<AppSettings>().language;
    if (language != _language) {
      _language = language;
      _future = _service.fetch(language: language);
      _selectedTag = null;
    }
  }

  Future<void> _reload() {
    setState(() => _future = _service.fetch(language: _language!));
    return _future.catchError((_) => <Article>[]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.learnTitle)),
      body: FutureBuilder<List<Article>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.learnLoadFailed),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _reload, child: Text(l10n.retry)),
                ],
              ),
            );
          }
          final articles = snap.data ?? const <Article>[];
          final tags = _collectTags(articles);
          final selected = _selectedTag?.toLowerCase();
          final visible = selected == null
              ? articles
              : articles
                    .where(
                      (a) => a.tags.any((t) => t.toLowerCase() == selected),
                    )
                    .toList();
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (tags.isNotEmpty) ...[
                  Text(
                    l10n.learnTopics,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_selectedTag case final tag?)
                    Text(
                      l10n.learnFilteringBy(tag),
                      style: theme.textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in tags)
                        FilterChip(
                          avatar: _Dot(color: tagColor(tag)),
                          label: Text(tag),
                          showCheckmark: false,
                          selected: tag.toLowerCase() == selected,
                          onSelected: (on) =>
                              setState(() => _selectedTag = on ? tag : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.learnEmpty, textAlign: TextAlign.center),
                  ),
                for (final article in visible)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ArticleScreen(article: article),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                article.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (article.excerpt.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  article.excerpt,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                              if (article.tags.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                TagRow(tags: article.tags),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  static List<String> _collectTags(List<Article> articles) {
    final seen = <String>{};
    final tags = [
      for (final a in articles)
        for (final t in a.tags)
          if (seen.add(t.toLowerCase())) t,
    ];
    return tags..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }
}

class TagRow extends StatelessWidget {
  const TagRow({required this.tags, super.key});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor(tag).withValues(alpha: dark ? 0.25 : 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: tagColor(tag).withValues(alpha: 0.5)),
            ),
            child: Text(
              tag,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
