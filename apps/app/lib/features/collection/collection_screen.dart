import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/dream.dart';
import '../../l10n/generated/app_localizations.dart';
import '../shell/tab_navigator.dart';
import 'collection_state.dart';
import 'dream_details_page.dart';
import 'irt_practice_page.dart';
import 'widgets/gradient_card.dart';

/// Dream filter options (ported from legacy dream_collection.dart).
enum _DreamFilter { all, dreams, nightmares }

/// Dream collection tab: list of dream cards with filtering, pull-to-refresh
/// and navigation to details / IRT practice.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  _DreamFilter _filter = _DreamFilter.all;

  List<Dream> _sorted(List<Dream> dreams) {
    return List<Dream>.of(dreams)..sort((a, b) {
      // Current (practice) dream first — only transformed nightmares
      // qualify.
      final aCurrent = a.rewrittenDream != null && a.isCurrentDream;
      final bCurrent = b.rewrittenDream != null && b.isCurrentDream;
      if (aCurrent && !bCurrent) return -1;
      if (bCurrent && !aCurrent) return 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  List<Dream> _filtered(List<Dream> dreams) {
    switch (_filter) {
      case _DreamFilter.all:
        return dreams;
      case _DreamFilter.dreams:
        return dreams.where((d) => d.rewrittenDream == null).toList();
      case _DreamFilter.nightmares:
        return dreams.where((d) => d.rewrittenDream != null).toList();
    }
  }

  void _openDetails(Dream dream) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DreamDetailsPage(dreamId: dream.id),
      ),
    );
  }

  void _openPractice(Dream dream) {
    if (dream.rewrittenDream == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IrtPracticePage(dreamId: dream.id),
      ),
    );
  }

  Future<void> _setCurrent(Dream dream) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<DreamCollectionState>().setCurrentDream(dream.id);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dreamSetCurrentSuccess)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dreamActionFailed)));
    }
  }

  Future<void> _delete(Dream dream) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDeleteDreamDialog(context);
    if (confirmed != true || !mounted) return;
    try {
      await context.read<DreamCollectionState>().deleteDream(dream.id);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dreamDeleteFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final state = context.watch<DreamCollectionState>();

    final dreams = state.dreams;
    final filtered = _filtered(_sorted(dreams));

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 48),
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              l10n.collectionTitle,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              l10n.collectionSubtitle,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
          if (dreams.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFilterChip(l10n.collectionFilterAll, _DreamFilter.all),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    l10n.collectionFilterDreams,
                    _DreamFilter.dreams,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    l10n.collectionFilterNightmares,
                    _DreamFilter.nightmares,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.collectionShowingCount(filtered.length, dreams.length),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (state.isLoading && dreams.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null && dreams.isEmpty)
            _ErrorState(onRetry: state.refresh)
          else if (dreams.isEmpty)
            const _EmptyState()
          else ...[
            for (final dream in filtered)
              _DreamCard(
                key: ValueKey('dream-card-${dream.id}'),
                dream: dream,
                onViewDetails: () => _openDetails(dream),
                onPractice: () => _openPractice(dream),
                onSetCurrent: () => _setCurrent(dream),
                onDelete: () => _delete(dream),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _DreamFilter filter) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _filter == filter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _filter = filter);
      },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? colorScheme.primary
            : colorScheme.outline.withValues(alpha: 0.5),
        width: isSelected ? 1.5 : 1,
      ),
    );
  }
}

/// Localized delete confirmation, shared with the details page.
Future<bool?> showDeleteDreamDialog(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.dreamDeleteConfirmTitle),
      content: Text(l10n.dreamDeleteConfirmBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.dreamCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            l10n.dreamDeleteConfirm,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.collectionEmptyTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.collectionEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    context.read<TabNavigator>().goTo(AppTabs.chat),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(l10n.collectionEmptyGoToChat),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    context.read<TabNavigator>().goTo(AppTabs.record),
                icon: const Icon(Icons.edit_note_outlined),
                label: Text(l10n.collectionEmptyGoToRecord),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
          const SizedBox(height: 8),
          Text(
            l10n.collectionLoadError,
            style: TextStyle(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.collectionRetry),
          ),
        ],
      ),
    );
  }
}

/// One dream in the collection list (ported from legacy DreamCard).
class _DreamCard extends StatelessWidget {
  const _DreamCard({
    super.key,
    required this.dream,
    required this.onViewDetails,
    required this.onPractice,
    required this.onSetCurrent,
    required this.onDelete,
  });

  final Dream dream;
  final VoidCallback onViewDetails;
  final VoidCallback onPractice;
  final VoidCallback onSetCurrent;
  final VoidCallback onDelete;

  bool get isTransformedNightmare => dream.rewrittenDream != null;
  bool get isCurrent => isTransformedNightmare && dream.isCurrentDream;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(dream.createdAt.toLocal());

    return GradientCard(
      colors: isTransformedNightmare
          ? DreamGradients.nightmare(isDark: isDark)
          : DreamGradients.positive(isDark: isDark),
      opacity: isDark ? 1.0 : 0.5,
      borderColor: isCurrent ? colorScheme.primary : null,
      borderWidth: isCurrent ? 2 : 1.25,
      padding: EdgeInsets.zero,
      onTap: onViewDetails,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 72.0, top: 12.0),
                  child: Text(
                    dream.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: colorScheme.onSurface,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      date,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (dream.intensity != null) ...[
                      const SizedBox(width: 14),
                      Icon(
                        Icons.bolt_outlined,
                        size: 16,
                        color: colorScheme.onSurface,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${dream.intensity}/10',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (isTransformedNightmare)
                      _Badge(
                        icon: Icons.auto_fix_high_outlined,
                        label: l10n.collectionTransformedBadge,
                        color: colorScheme.tertiary,
                      )
                    else if (dream.isNightmare)
                      _Badge(
                        icon: Icons.nightlight_outlined,
                        label: l10n.dreamNightmareBadge,
                        color: colorScheme.secondary,
                      ),
                    if (isCurrent)
                      _Badge(
                        icon: Icons.star,
                        label: l10n.dreamCurrentBadge,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
                if (isTransformedNightmare) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: _PracticeProgressIndicator(
                      rehearsalCount: dream.practiceTimestamps.length,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrent)
                  Icon(Icons.star, color: colorScheme.primary, size: 22),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'practice':
                        onPractice();
                      case 'current':
                        onSetCurrent();
                      case 'delete':
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    if (isTransformedNightmare)
                      PopupMenuItem<String>(
                        value: 'practice',
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(l10n.collectionMenuPractice),
                          ],
                        ),
                      ),
                    if (isTransformedNightmare && !isCurrent)
                      PopupMenuItem<String>(
                        value: 'current',
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_outline,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(l10n.dreamSetCurrent),
                          ],
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Text(l10n.dreamDeleteAction),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Practice progress bar (ported from legacy PracticeDreamIndicator).
class _PracticeProgressIndicator extends StatelessWidget {
  const _PracticeProgressIndicator({required this.rehearsalCount});

  static const int _totalSessions = 7;
  final int rehearsalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final completedColor = colorScheme.primary;
    final progress = (rehearsalCount / _totalSessions).clamp(0.0, 1.0);

    return Column(
      children: [
        Container(
          height: 8,
          width: 160,
          decoration: BoxDecoration(
            color: colorScheme.outline.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      completedColor,
                      completedColor.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.practiceSessionsProgress(
            rehearsalCount.clamp(0, _totalSessions),
            _totalSessions,
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
