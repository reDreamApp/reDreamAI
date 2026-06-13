import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../home/widgets/gradient_card.dart';
import 'progress_state.dart';

/// Backend wire values for the daily mood check-in. The backend maps these
/// exact English strings to scores — do NOT localize the wire value, only
/// the visible label.
class _MoodOption {
  const _MoodOption(this.wireValue, this.icon);

  final String wireValue;
  final IconData icon;
}

const List<_MoodOption> _moodOptions = [
  _MoodOption('Very Dissatisfied', Icons.sentiment_very_dissatisfied_rounded),
  _MoodOption('Dissatisfied', Icons.sentiment_dissatisfied_rounded),
  _MoodOption('Neutral', Icons.sentiment_neutral_rounded),
  _MoodOption('Satisfied', Icons.sentiment_satisfied_rounded),
  _MoodOption('Very Satisfied', Icons.sentiment_very_satisfied_rounded),
];

IconData _moodIcon(String wireValue) {
  for (final option in _moodOptions) {
    if (option.wireValue == wireValue) return option.icon;
  }
  return Icons.sentiment_neutral_rounded;
}

String _moodLabel(String wireValue, AppLocalizations l10n) {
  switch (wireValue) {
    case 'Very Dissatisfied':
      return l10n.moodVeryDissatisfied;
    case 'Dissatisfied':
      return l10n.moodDissatisfied;
    case 'Neutral':
      return l10n.moodNeutral;
    case 'Satisfied':
      return l10n.moodSatisfied;
    case 'Very Satisfied':
      return l10n.moodVerySatisfied;
    default:
      return l10n.moodNotSet;
  }
}

/// "Your Progress" card: rehearsal streak, stats and the daily mood check-in.
/// Ported from the legacy home_page.dart progress/mood section.
class ProgressSection extends StatefulWidget {
  const ProgressSection({super.key});

  @override
  State<ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<ProgressSection> {
  bool _showEmotionPicker = false;
  bool _saveFailed = false;

  Future<void> _onEmotionSelected(String wireValue) async {
    final state = context.read<ProgressState>();
    setState(() {
      _showEmotionPicker = false;
      _saveFailed = false;
    });
    final ok = await state.submitEmotion(wireValue);
    if (!mounted) return;
    setState(() => _saveFailed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final state = context.watch<ProgressState>();
    final stats = state.stats;
    final hasStats = stats != null;
    final initialLoading = state.isLoading && !hasStats;
    final todayMood = state.todayMood;
    final showPicker = (!state.hasCheckedInToday || _showEmotionPicker) &&
        !initialLoading &&
        !state.submittingMood;

    return GradientCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.trending_up_rounded,
                size: 28,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 12),
              Text(
                l10n.progressTitle,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (initialLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
            )
          else if (!hasStats && state.error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.progressLoadError,
                style: TextStyle(color: colorScheme.error, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          else ...[
            _StreakTile(streak: hasStats ? stats.rehearsalStreak : 0),
            const SizedBox(height: 8),
            _StatTile(
              icon: Icons.speed_rounded,
              title: l10n.progressIntensityTitle,
              subtitle: l10n.progressIntensitySubtitle,
              valueText: stats?.averageIntensity != null
                  ? stats!.averageIntensity!.toStringAsFixed(1)
                  : '-',
            ),
            const SizedBox(height: 8),
            _StatTile(
              icon: Icons.menu_book_rounded,
              title: l10n.progressDreamsLoggedTitle,
              subtitle: l10n.progressDreamsLoggedSubtitle,
              valueText: '${stats?.dreamsLogged ?? 0}',
            ),
            const SizedBox(height: 8),
            _StatTile(
              icon: Icons.auto_fix_high_rounded,
              title: l10n.progressNightmaresTreatedTitle,
              subtitle: l10n.progressNightmaresTreatedSubtitle,
              valueText: '${stats?.nightmaresTreated ?? 0}',
            ),
          ],
          if (todayMood != null) ...[
            const SizedBox(height: 8),
            _MoodTile(
              title: l10n.moodTitle,
              subtitle: stats?.averageMood != null
                  ? l10n.moodSubtitleWithAvg(
                      _moodLabel(todayMood, l10n),
                      stats!.averageMood!.toStringAsFixed(1),
                    )
                  : _moodLabel(todayMood, l10n),
              icon: _moodIcon(todayMood),
              onTap: () => setState(() => _showEmotionPicker = true),
            ),
            if (!showPicker && !state.submittingMood) ...[
              const SizedBox(height: 8),
              Text(
                l10n.moodThanks,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
          if (state.submittingMood) ...[
            const SizedBox(height: 12),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
          if (showPicker) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 20,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.moodQuestion,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _EmotionSelector(onEmotionSelected: _onEmotionSelected),
                ],
              ),
            ),
          ],
          if (_saveFailed) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                l10n.moodSaveError,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StreakTile extends StatelessWidget {
  const _StreakTile({required this.streak});

  final int streak;

  bool get hasRehearsedToday => streak > 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline, width: 1.25),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: hasRehearsedToday
                  ? const Color(0xFFFFE0B2).withValues(alpha: 0.8)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              color: hasRehearsedToday
                  ? const Color(0xFFFF6F00)
                  : colorScheme.onSurface.withValues(alpha: 0.3),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.progressStreakTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.progressStreakSubtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$streak',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outline, width: 1.25),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valueText,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outline, width: 1.25),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.navigate_next_rounded,
                size: 20,
                color: colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmotionSelector extends StatelessWidget {
  const _EmotionSelector({required this.onEmotionSelected});

  final ValueChanged<String> onEmotionSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8;
        const double maxItemSize = 50;
        const double horizontalPadding = 6;
        final double contentWidth =
            constraints.maxWidth - (horizontalPadding * 2);
        // Always compute exactly 5 items across using inner content width.
        double computedSize =
            (contentWidth - (spacing * (_moodOptions.length - 1))) /
                _moodOptions.length;
        if (computedSize > maxItemSize) computedSize = maxItemSize;
        // Snap to physical pixels to prevent fractional overflow.
        final double dpr = MediaQuery.of(context).devicePixelRatio;
        final double itemSize = (computedSize * dpr).floor() / dpr;
        final double iconSize = itemSize * 0.56;

        final items = <Widget>[];
        for (int i = 0; i < _moodOptions.length; i++) {
          final option = _moodOptions[i];
          items.add(
            GestureDetector(
              onTap: () => onEmotionSelected(option.wireValue),
              child: SizedBox(
                width: itemSize,
                height: itemSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        colorScheme.primaryContainer.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outline.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      option.icon,
                      size: iconSize,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          );
          if (i < _moodOptions.length - 1) {
            items.add(const SizedBox(width: spacing));
          }
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: items),
        );
      },
    );
  }
}
