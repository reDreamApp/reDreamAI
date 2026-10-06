import 'package:flutter/material.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/learn/article.dart';
import 'package:redream_app/features/learn/learn_screen.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({required this.article, super.key});

  final Article article;

  Future<void> _open(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final url = article.urlFor(Theme.of(context).brightness);
    final uri = url == null ? null : Uri.tryParse(url);
    var ok = false;
    if (uri != null) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Exception catch (_) {}
    }
    if (!ok && context.mounted) {
      showAppSnackBar(context, l10n.learnOpenFailed, error: true);
    }
  }

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
                  Text(article.excerpt, style: const TextStyle(height: 1.5)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: l10n.learnOpenArticle,
                  icon: Icons.open_in_new,
                  style: AppButtonStyle.gradient,
                  onPressed: () => _open(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
