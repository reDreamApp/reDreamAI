import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language/language_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/widgets/gradient_card.dart';
import 'article_detail_page.dart';
import 'educational_article.dart';
import 'learn_service.dart';
import 'widgets/category_indicators.dart';
import 'widgets/topic_legend.dart';

/// Learn tab: educational articles list with topic filtering, ported from
/// the legacy screens/learn/educational_page.dart.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final ILearnService _service = LearnService();

  String? _selectedTag;
  Future<List<EducationalArticle>>? _articlesFuture;
  String? _lastLanguage;

  List<Color> _gradientColors({required bool isDarkMode}) {
    final base = BrandColors.brandGradient().colors;
    final double alpha = isDarkMode ? 0.55 : 0.35;
    return base.map((color) => color.withValues(alpha: alpha)).toList();
  }

  List<String> _collectTags(List<EducationalArticle> articles) {
    final tagsByKey = <String, String>{};
    for (final article in articles) {
      for (final tag in article.tags) {
        tagsByKey.putIfAbsent(tag.toLowerCase(), () => tag);
      }
    }
    final tags = tagsByKey.values.toList();
    tags.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return tags;
  }

  bool _matchesTag(EducationalArticle article, String tag) {
    final target = tag.toLowerCase();
    return article.tags.any((item) => item.toLowerCase() == target);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Provider.of<LanguageProvider>(context).selectedLanguage;
    if (_articlesFuture == null || _lastLanguage != lang) {
      _lastLanguage = lang;
      _articlesFuture = _service.fetchArticles(lang);
    }
  }

  Future<void> _refreshArticles() async {
    final lang = Provider.of<LanguageProvider>(
      context,
      listen: false,
    ).selectedLanguage;
    setState(() {
      _lastLanguage = lang;
      _articlesFuture = _service.fetchArticles(lang);
    });
    final future = _articlesFuture;
    if (future != null) {
      // Errors are rendered by the FutureBuilder, not thrown to the indicator.
      await future.catchError((Object _) => <EducationalArticle>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final future = _articlesFuture;

    return Container(
      decoration: BoxDecoration(
        gradient: BrandColors.backgroundGradient(isDark),
      ),
      child: future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<EducationalArticle>>(
              future: future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.learnLoadError,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _refreshArticles,
                            child: Text(l10n.learnTryAgain),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final articles = snapshot.data ?? [];
                final tags = _collectTags(articles);
                final filteredArticles = _selectedTag == null
                    ? articles
                    : articles
                        .where((a) => _matchesTag(a, _selectedTag!))
                        .toList();
                final gradientColors = _gradientColors(isDarkMode: isDark);

                return RefreshIndicator(
                  onRefresh: _refreshArticles,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    itemCount: filteredArticles.isEmpty
                        ? 2
                        : filteredArticles.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return TopicLegend(
                          tags: tags,
                          selectedTag: _selectedTag,
                          onTagSelected: (tag) {
                            setState(() {
                              _selectedTag =
                                  tag == _selectedTag ? null : tag;
                            });
                          },
                          onClearFilter: () {
                            if (_selectedTag != null) {
                              setState(() => _selectedTag = null);
                            }
                          },
                        );
                      }
                      if (filteredArticles.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            l10n.learnNoArticles,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      final article = filteredArticles[index - 1];
                      return _ArticleCard(
                        article: article,
                        gradientColors: gradientColors,
                        borderColor: CardBorders.of(context),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.article,
    required this.gradientColors,
    required this.borderColor,
  });

  final EducationalArticle article;
  final List<Color> gradientColors;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor, width: 1.25),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            title: Text(
              article.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (article.subtitle.isNotEmpty)
                    Text(
                      article.subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  if (article.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: article.tags
                          .map((tag) => CategoryTag(style: tagStyleFor(tag)))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ArticleDetailPage(article: article),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
