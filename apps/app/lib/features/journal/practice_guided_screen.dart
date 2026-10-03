import 'package:flutter/material.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/features/journal/dream.dart';
import 'package:redream_app/features/journal/practice_helpers.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class PracticeGuidedScreen extends StatefulWidget {
  const PracticeGuidedScreen({required this.dream, super.key});

  final Dream dream;

  @override
  State<PracticeGuidedScreen> createState() => _PracticeGuidedScreenState();
}

class _PracticeGuidedScreenState extends State<PracticeGuidedScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _saving = false;

  static const _count = 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _go(int delta) => _controller.animateToPage(
    (_index + delta).clamp(0, _count - 1),
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  Future<void> _done() async {
    setState(() => _saving = true);
    await completePractice(context, widget.dream);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dream = widget.dream;
    final pages = [
      (l10n.practiceWelcomeTitle, l10n.practiceWelcomeBody),
      (l10n.practiceStep1Title, l10n.practiceStep1Body),
      (dream.title, dream.rewrittenDream ?? ''),
      (l10n.practiceStep2Title, l10n.practiceStep2Body),
      (dream.title, dream.rewrittenDream ?? ''),
      (l10n.practiceStep3Title, l10n.practiceStep3Body),
    ];
    final last = _index == _count - 1;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.practiceReadingTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _count,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _Page(
                  title: pages[i].$1,
                  body: pages[i].$2,
                  isDream: i == 2 || i == 4,
                ),
              ),
            ),
            PageDots(count: _count, index: _index),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _index == 0 ? null : () => _go(-1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const Spacer(),
                  if (last)
                    SizedBox(
                      width: 160,
                      child: AppButton(
                        label: l10n.done,
                        busy: _saving,
                        onPressed: _done,
                      ),
                    )
                  else
                    IconButton(
                      onPressed: () => _go(1),
                      icon: const Icon(Icons.arrow_forward),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body, required this.isDream});

  final String title;
  final String body;
  final bool isDream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          if (!isDream) ...[
            Icon(
              Icons.self_improvement_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            textAlign: isDream ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
