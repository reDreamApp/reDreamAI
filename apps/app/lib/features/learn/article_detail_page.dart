import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../home/widgets/gradient_card.dart';
import 'educational_article.dart';
import 'widgets/category_indicators.dart';

/// Article detail, ported from the legacy screens/learn/article_detail_page.dart.
/// Shows excerpt + tags and opens the full post (theme-matched URL) externally.
class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({super.key, required this.article});

  final EducationalArticle article;

  Future<void> _openArticle(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final url = article.urlForBrightness(Theme.of(context).brightness);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.learnOpenLinkError),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tags = article.tags;

    return Scaffold(
      appBar: AppBar(title: Text(article.title)),
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandColors.backgroundGradient(isDark),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (tags.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags
                        .map((tag) => CategoryTag(style: tagStyleFor(tag)))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              GradientCard(
                padding: const EdgeInsets.all(24),
                opacity: isDark ? 0.55 : 0.35,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.subtitle.isNotEmpty) ...[
                      Text(
                        article.subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                              color: colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openArticle(context),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(l10n.learnOpenArticle),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
