import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/home/irt_guide_screen.dart';
import 'package:redream_app/features/home/progress_models.dart';
import 'package:redream_app/features/home/progress_state.dart';
import 'package:redream_app/features/journal/dream_detail_screen.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    await Future.wait([
      context.read<ProgressState>().refresh(),
      context.read<JournalState>().refresh(),
      context.read<ChatState>().loadChats(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    final tabs = context.read<ShellTabs>();

    return RefreshIndicator(
      onRefresh: () => _refresh(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ShaderMask(
            shaderCallback: brand.headlineGradient.createShader,
            child: Text(
              l10n.homeHeadline,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HeroCard(onBegin: () => tabs.select(ShellTab.session)),
          const SizedBox(height: 16),
          const _ProgressCard(),
          const SizedBox(height: 16),
          // The shortcuts, with their pictures from the first app version.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _PictureShortcut(
                  image: 'assets/images/home_rehearsal.webp',
                  label: l10n.homePracticeTitle,
                  onTap: () {
                    final focus = context.read<JournalState>().focusDream;
                    if (focus != null && focus.canPractice) {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DreamDetailScreen(dream: focus),
                          ),
                        ),
                      );
                    } else {
                      tabs.select(ShellTab.journal);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PictureShortcut(
                  image: 'assets/images/home_guide.webp',
                  label: l10n.homeGuideTitle,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const IrtGuideScreen(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PictureShortcut(
            image: 'assets/images/home_learn.webp',
            height: 132,
            label: l10n.homeLearnTitle,
            onTap: () => tabs.select(ShellTab.learn),
          ),
        ],
      ),
    );
  }
}

/// The page's one call to action: the illustration on the brand gradient,
/// one line of text and the button that opens a session.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onBegin});

  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(gradient: brand.heroGradient),
            child: Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Image.asset(
                'assets/images/home_dreaming.webp',
                height: 220,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.homeStartBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: brand.muted,
                  ),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: l10n.homeBeginSession,
                  style: AppButtonStyle.gradient,
                  onPressed: onBegin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final progress = context.watch<ProgressState>();
    final journal = context.watch<JournalState>();
    final chats = context.watch<ChatState>().chats;
    final stats = progress.stats;
    final sessions = chats.where((c) => c.isDone).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.homeProgressTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (progress.loading && stats == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (progress.error != null && stats == null)
            Text(
              l10n.errorLoadFailed,
              style: TextStyle(color: theme.colorScheme.error),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.trending_up_rounded,
                    iconColor: BrandColors.flame,
                    label: l10n.statStreak,
                    value: l10n.statDays(stats?.rehearsalStreak ?? 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: Icons.speed_rounded,
                    iconColor: theme.colorScheme.primary,
                    label: l10n.statIntensity,
                    value: stats?.averageIntensity?.toStringAsFixed(1) ?? '–',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.menu_book_outlined,
                    iconColor: BrandColors.violet,
                    label: l10n.statDreams,
                    value: '${stats?.dreamsLogged ?? journal.dreams.length}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    icon: Icons.check_circle_outline,
                    iconColor: BrandColors.deepTeal,
                    label: l10n.statSessions,
                    value: '$sessions',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _MoodPicker(stats: stats),
          ],
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: brand.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodPicker extends StatefulWidget {
  const _MoodPicker({required this.stats});

  final ProgressStats? stats;

  @override
  State<_MoodPicker> createState() => _MoodPickerState();
}

class _MoodPickerState extends State<_MoodPicker> {
  Mood? _pending;

  static const Map<Mood, IconData> _icons = {
    Mood.veryDissatisfied: Icons.sentiment_very_dissatisfied_rounded,
    Mood.dissatisfied: Icons.sentiment_dissatisfied_rounded,
    Mood.neutral: Icons.sentiment_neutral_rounded,
    Mood.satisfied: Icons.sentiment_satisfied_rounded,
    Mood.verySatisfied: Icons.sentiment_very_satisfied_rounded,
  };

  /// From low to high in the colours of the session progress, with the
  /// blue of the picture gradient between lilac and turquoise.
  static const Map<Mood, Color> colors = {
    Mood.veryDissatisfied: BrandColors.lilac,
    Mood.dissatisfied: BrandColors.periwinkle,
    Mood.neutral: BrandColors.turquoise,
    Mood.satisfied: BrandColors.green,
    Mood.verySatisfied: BrandColors.yellow,
  };

  String _label(Mood mood, AppLocalizations l10n) => switch (mood) {
    Mood.veryDissatisfied => l10n.moodVeryDissatisfied,
    Mood.dissatisfied => l10n.moodDissatisfied,
    Mood.neutral => l10n.moodNeutral,
    Mood.satisfied => l10n.moodSatisfied,
    Mood.verySatisfied => l10n.moodVerySatisfied,
  };

  Future<void> _select(Mood mood) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending = mood);
    try {
      await context.read<ProgressState>().setTodayMood(mood);
    } on Exception catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        isOffline(e) ? l10n.errorOffline : l10n.homeMoodSaveFailed,
        error: true,
      );
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    final selected = _pending ?? widget.stats?.todayMood;
    final average = widget.stats?.averageMood;
    final dark = theme.brightness == Brightness.dark;
    final tile = theme.colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selected == null ? l10n.homeMoodQuestion : l10n.homeMoodToday,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final mood in Mood.values) ...[
              Expanded(
                child: Tooltip(
                  message: _label(mood, l10n),
                  child: InkWell(
                    onTap: _pending == null ? () => _select(mood) : null,
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 48,
                      decoration: BoxDecoration(
                        // A wash of the mood's colour; the chosen one is
                        // stronger and framed.
                        color: Color.alphaBlend(
                          colors[mood]!.withValues(
                            alpha: mood == selected ? 0.42 : 0.2,
                          ),
                          tile,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mood == selected
                              ? colors[mood]!
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _icons[mood],
                        // The colour itself, pulled towards the text
                        // colour so a pale one stays readable.
                        color: Color.lerp(
                          colors[mood],
                          theme.colorScheme.onSurface,
                          mood == selected ? 0.6 : (dark ? 0.15 : 0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (mood != Mood.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
        if (selected != null || average != null) ...[
          const SizedBox(height: 8),
          Text(
            [
              if (selected != null) _label(selected, l10n),
              if (average != null)
                l10n.homeMoodAverage(average.toStringAsFixed(1)),
            ].join(' • '),
            style: theme.textTheme.bodySmall?.copyWith(color: brand.muted),
          ),
        ],
      ],
    );
  }
}

/// A shortcut as a small card: a picture on the brand gradient, as on the
/// cards of the first app version, and the title under it.
class _PictureShortcut extends StatelessWidget {
  const _PictureShortcut({
    required this.image,
    required this.label,
    required this.onTap,
    this.height = 116,
  });

  final String image;
  final String label;
  final VoidCallback onTap;

  /// Height of the picture.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: BrandTheme.of(context).heroGradient,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Image.asset(
                image,
                height: height,
                // The figures stand on the lower edge of the picture.
                alignment: Alignment.bottomCenter,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
