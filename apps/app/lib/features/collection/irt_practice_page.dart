import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:provider/provider.dart';

import '../../core/language/language_provider.dart';
import '../../core/models/dream.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'collection_state.dart';

/// Calm full-screen IRT rehearsal flow (ported from legacy irt_practice.dart
/// IRTRehearsalGuidedPage): guided steps interleaved with the rewritten dream
/// text, finishing with "Done practicing" → recordPractice.
class IrtPracticePage extends StatefulWidget {
  const IrtPracticePage({super.key, required this.dreamId});

  final int dreamId;

  @override
  State<IrtPracticePage> createState() => _IrtPracticePageState();
}

class _IrtPracticePageState extends State<IrtPracticePage> {
  final _introKey = GlobalKey<IntroductionScreenState>();
  bool _isSaving = false;
  bool _isGeneratingAudio = false;

  Future<void> _handlePracticeComplete() async {
    if (_isSaving) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _isSaving = true);
    try {
      await context.read<DreamCollectionState>().recordPractice(
        widget.dreamId,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.practiceSaved),
          behavior: SnackBarBehavior.floating,
        ),
      );
      navigator.pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.practiceSaveFailed),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: l10n.chatRetry,
            textColor: Colors.white,
            onPressed: _handlePracticeComplete,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// The AI TTS backend is stubbed today — failures are expected and are
  /// surfaced as a calm "not available yet" notice rather than an error.
  Future<void> _generateAudio() async {
    if (_isGeneratingAudio) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final language = context.read<LanguageProvider>().selectedLanguage;
    setState(() => _isGeneratingAudio = true);
    try {
      await context.read<DreamCollectionState>().generateRehearsal(
        widget.dreamId,
        language: language,
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.practiceAudioUnavailable),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dream = context.watch<DreamCollectionState>().dreamById(
      widget.dreamId,
    );

    if (dream == null || dream.rewrittenDream == null) {
      // Dream gone or has no rewritten version — nothing to rehearse.
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final gradient = BrandColors.brandGradient();
    final gradientColors = gradient.colors
        .map((color) => color.withValues(alpha: 0.5))
        .toList(growable: false);

    const bodyStyle = TextStyle(fontSize: 19.0);
    const pageDecoration = PageDecoration(
      titleTextStyle: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w700),
      bodyTextStyle: bodyStyle,
      titlePadding: EdgeInsets.fromLTRB(16.0, 96.0, 16.0, 0.0),
      bodyPadding: EdgeInsets.fromLTRB(16.0, 48.0, 16.0, 16.0),
      pageColor: Colors.transparent,
      imagePadding: EdgeInsets.zero,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: IntroductionScreen(
                  key: _introKey,
                  globalBackgroundColor: Colors.transparent,
                  pages: [
                    PageViewModel(
                      title: l10n.practiceWelcomeTitle,
                      body: l10n.practiceWelcomeBody,
                      decoration: pageDecoration,
                    ),
                    PageViewModel(
                      title: l10n.practiceStep1Title,
                      body: l10n.practiceStep1Body,
                      decoration: pageDecoration,
                    ),
                    PageViewModel(
                      title: dream.title,
                      body: dream.rewrittenDream,
                      decoration: pageDecoration,
                    ),
                    PageViewModel(
                      title: l10n.practiceStep2Title,
                      body: l10n.practiceStep2Body,
                      decoration: pageDecoration,
                    ),
                    PageViewModel(
                      title: dream.title,
                      body: dream.rewrittenDream,
                      decoration: pageDecoration,
                    ),
                    PageViewModel(
                      title: l10n.practiceStep3Title,
                      body: l10n.practiceStep3Body,
                      decoration: pageDecoration,
                    ),
                  ],
                  showBackButton: true,
                  back: const Icon(Icons.arrow_back, size: 28),
                  next: const Icon(Icons.arrow_forward, size: 28),
                  done: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          l10n.practiceDoneButton,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                  onDone: _isSaving ? () {} : _handlePracticeComplete,
                  dotsDecorator: DotsDecorator(
                    size: const Size.square(10.0),
                    activeSize: const Size(22.0, 10.0),
                    activeShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    spacing: const EdgeInsets.all(3),
                  ),
                ),
              ),
              _PracticeFooter(
                dream: dream,
                isGeneratingAudio: _isGeneratingAudio,
                onGenerateAudio: _generateAudio,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Practice stats (total + last practiced) and audio rehearsal hint/action.
class _PracticeFooter extends StatelessWidget {
  const _PracticeFooter({
    required this.dream,
    required this.isGeneratingAudio,
    required this.onGenerateAudio,
  });

  final Dream dream;
  final bool isGeneratingAudio;
  final VoidCallback onGenerateAudio;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hasAudio =
        dream.rehearsalAudioUrl != null && dream.rehearsalAudioUrl!.isNotEmpty;
    final timestamps = dream.practiceTimestamps;

    var stats = l10n.practiceCount(timestamps.length);
    if (timestamps.isNotEmpty) {
      final last = timestamps.reduce((a, b) => a.isAfter(b) ? a : b);
      final date = DateFormat.yMMMd(l10n.localeName).format(last.toLocal());
      stats = '$stats · ${l10n.practiceLastPracticed(date)}';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.self_improvement,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stats,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasAudio)
            Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.practiceAudioAvailable,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: isGeneratingAudio ? null : onGenerateAudio,
                icon: isGeneratingAudio
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.graphic_eq_rounded, size: 18),
                label: Text(l10n.practiceGenerateAudio),
              ),
            ),
        ],
      ),
    );
  }
}
