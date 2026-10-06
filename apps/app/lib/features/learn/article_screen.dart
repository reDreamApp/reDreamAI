import 'package:flutter/material.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/features/learn/article.dart';
import 'package:redream_app/features/learn/learn_screen.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

/// One article: its picture, what it is about, and the way to the article
/// itself in the browser.
class ArticleScreen extends StatelessWidget {
  const ArticleScreen({required this.article, super.key, this.openUrl});

  final Article article;

  /// Replaces the browser in tests.
  final Future<bool> Function(Uri url)? openUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final background = learnBackground(context);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text(article.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            highlight: true,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (article.image case final image?)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: BrandTheme.of(context).heroGradient,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Image.asset(
                        image,
                        height: 190,
                        // The figures stand on the lower edge of the picture.
                        alignment: Alignment.bottomCenter,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        article.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (article.excerpt.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          article.excerpt,
                          style: const TextStyle(height: 1.5),
                        ),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        label: l10n.learnOpenArticle,
                        icon: Icons.open_in_new,
                        style: AppButtonStyle.gradient,
                        onPressed: () =>
                            openArticle(context, article, openUrl: openUrl),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
