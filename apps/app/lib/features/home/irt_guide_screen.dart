import 'package:flutter/material.dart';

import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class IrtGuideScreen extends StatelessWidget {
  const IrtGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final gradient = BrandTheme.of(context).accentGradient;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              for (final c in gradient.colors) c.withValues(alpha: 0.35),
            ],
          ),
        ),
        child: SafeArea(
          child: _GuidePager(
            pages: [
              (l10n.guideWelcomeTitle, l10n.guideWelcomeBody),
              (l10n.guideStep1Title, l10n.guideStep1Body),
              (l10n.guideStep2Title, l10n.guideStep2Body),
              (l10n.guideStep3Title, l10n.guideStep3Body),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuidePager extends StatefulWidget {
  const _GuidePager({required this.pages});

  final List<(String, String)> pages;

  @override
  State<_GuidePager> createState() => _GuidePagerState();
}

class _GuidePagerState extends State<_GuidePager> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int page) => _controller.animateToPage(
    page,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLast = _page == widget.pages.length - 1;
    return Column(
      children: [
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              for (final (title, body) in widget.pages)
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: _page == 0 ? null : () => _go(_page - 1),
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              for (var i = 0; i < widget.pages.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? scheme.primary : scheme.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              const Spacer(),
              if (isLast)
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(l10n.done),
                )
              else
                IconButton(
                  onPressed: () => _go(_page + 1),
                  icon: const Icon(Icons.arrow_forward),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
