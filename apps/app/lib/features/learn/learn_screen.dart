import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/learn/article.dart';
import 'package:redream_app/features/learn/article_screen.dart';
import 'package:redream_app/features/learn/articles_service.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Learn section's page colour: the usual background with a wash of
/// the brand turquoise.
Color learnBackground(BuildContext context) {
  final theme = Theme.of(context);
  final dark = theme.brightness == Brightness.dark;
  return Color.alphaBlend(
    BrandColors.turquoise.withValues(alpha: dark ? 0.16 : 0.22),
    theme.scaffoldBackgroundColor,
  );
}

/// Opens the article in the browser; [openUrl] replaces the browser in tests.
Future<void> openArticle(
  BuildContext context,
  Article article, {
  Future<bool> Function(Uri url)? openUrl,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final url = article.urlFor(Theme.of(context).brightness);
  final uri = url == null ? null : Uri.tryParse(url);
  var ok = false;
  if (uri != null) {
    try {
      ok = await (openUrl ?? _inBrowser)(uri);
    } on Exception catch (_) {}
  }
  if (!ok && context.mounted) {
    showAppSnackBar(context, l10n.learnOpenFailed, error: true);
  }
}

Future<bool> _inBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// The articles. A card opens the article's page; the button under it
/// opens the article itself in the browser.
class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key, this.service, this.onBack, this.openUrl});

  /// Replaces the website client in tests.
  final ArticlesService? service;

  /// Puts a back arrow into the bar. As a tab, Learn returns to the tab the
  /// user came from with it.
  final VoidCallback? onBack;

  /// Replaces the browser in tests.
  final Future<bool> Function(Uri url)? openUrl;

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
    final background = learnBackground(context);
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        leading: widget.onBack == null
            ? null
            : BackButton(onPressed: widget.onBack),
        title: Text(l10n.learnTitle),
      ),
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
                        builder: (_) => ArticleScreen(
                          article: article,
                          openUrl: widget.openUrl,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.title,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
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
                        const SizedBox(height: 14),
                        AppButton(
                          label: l10n.learnOpenArticle,
                          icon: Icons.open_in_new,
                          style: AppButtonStyle.gradient,
                          onPressed: () => openArticle(
                            context,
                            article,
                            openUrl: widget.openUrl,
                          ),
                        ),
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
