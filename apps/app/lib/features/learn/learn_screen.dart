import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/features/learn/article.dart';
import 'package:redream_app/features/learn/article_screen.dart';
import 'package:redream_app/features/learn/articles_service.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, this.service});

  /// Replaces the website client in tests.
  final ArticlesService? service;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  late final ArticlesService _service = widget.service ?? ArticlesService();
  late Future<List<Article>> _future;
  String? _language;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = context.watch<AppSettings>().language;
    if (language != _language) {
      _language = language;
      _future = _service.fetch(language: language);
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
          final articles = [Article.ownStudy(l10n), ...?snap.data];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final article in articles)
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
}
