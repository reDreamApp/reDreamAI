import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/brand_logo.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/home/irt_guide_screen.dart';
import 'package:redream_app/features/home/progress_models.dart';
import 'package:redream_app/features/home/progress_state.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/journal/practice_chooser.dart';
import 'package:redream_app/features/learn/learn_screen.dart';
import 'package:redream_app/features/shell/shell_tabs.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _weeklyTarget = 7;

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const BrandLogo(height: 110),
          const SizedBox(height: 12),
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
          const SizedBox(height: 8),
          Text(
            l10n.homeMission,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: brand.muted),
          ),
          const SizedBox(height: 20),
          AppCard(
            highlight: true,
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.homeStartTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.homeStartBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: brand.muted,
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: l10n.homeBeginSession,
                  style: AppButtonStyle.gradient,
                  onPressed: () => tabs.select(ShellTab.session),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const _ProgressCard(weeklyTarget: _weeklyTarget),
          const SizedBox(height: 16),
          _PromoCard(
            image: 'assets/images/practice.png',
            title: l10n.homePracticeTitle,
            body: l10n.homePracticeBody,
            buttonLabel: l10n.homePracticeButton,
            icon: Icons.track_changes,
            onPressed: () {
              final focus = context.read<JournalState>().focusDream;
              if (focus != null && focus.canPractice) {
                unawaited(showPracticeChooser(context, focus));
              } else {
                tabs.select(ShellTab.journal);
              }
            },
          ),
          const SizedBox(height: 16),
          _PromoCard(
            image: 'assets/images/guide.png',
            title: l10n.homeGuideTitle,
            body: l10n.homeGuideBody,
            buttonLabel: l10n.homeGuideButton,
            icon: Icons.auto_stories_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const IrtGuideScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _PromoCard(
            title: l10n.homeLearnTitle,
            body: l10n.homeLearnBody,
            buttonLabel: l10n.homeLearnButton,
            icon: Icons.school_outlined,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const LearnScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.weeklyTarget});

  final int weeklyTarget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    final progress = context.watch<ProgressState>();
    final journal = context.watch<JournalState>();
    final chats = context.watch<ChatState>().chats;
    final stats = progress.stats;
    final tabs = context.read<ShellTabs>();

    final weekly = journal.practicesThisWeek.clamp(0, weeklyTarget);
    final nightmares = journal.nightmares;
    final transformed = nightmares.where((d) => d.hasRewrite).length;
    final sessions = chats.where((c) => c.isDone).length;
    final focus = journal.focusDream;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.bar_chart_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeProgressTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      l10n.homeProgressSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: brand.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => tabs.select(ShellTab.journal),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                ),
                child: Text(l10n.homeViewJournal, textAlign: TextAlign.center),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.homeWeeklyProgress,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _Pill('${(weekly / weeklyTarget * 100).round()}%'),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: weekly / weeklyTarget,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.homeSessionsThisWeek(weekly, weeklyTarget),
              style: theme.textTheme.bodySmall?.copyWith(color: brand.muted),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.homeJournalStatus,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.homeJournalStatusBody(nightmares.length, transformed),
              style: theme.textTheme.bodyMedium?.copyWith(color: brand.muted),
            ),
            if (focus != null)
              Text(
                l10n.homeFocusDream(focus.title),
                style: theme.textTheme.bodyMedium?.copyWith(color: brand.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (stats?.averageIntensity case final avg?)
              Text(
                l10n.homeAvgIntensity(avg.toStringAsFixed(1)),
                style: theme.textTheme.bodyMedium?.copyWith(color: brand.muted),
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

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
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
                        color: mood == selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: mood == selected
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        _icons[mood],
                        color: mood == selected
                            ? theme.colorScheme.primary
                            : brand.muted,
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

class _PromoCard extends StatelessWidget {
  const _PromoCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.icon,
    required this.onPressed,
    this.image,
  });

  final String? image;
  final String title;
  final String body;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brand = BrandTheme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (image != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(image!, height: 160, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              IconTile(icon: icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(color: brand.muted),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: buttonLabel,
            style: AppButtonStyle.outlined,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
