import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../educational_article.dart';

/// Topic filter chips above the article list, ported from the legacy
/// screens/learn/widgets/topic_legend.dart (strings localized).
class TopicLegend extends StatelessWidget {
  const TopicLegend({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagSelected,
    required this.onClearFilter,
  });

  final List<String> tags;
  final String? selectedTag;
  final ValueChanged<String> onTagSelected;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isFiltering = selectedTag != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.learnTopics,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          if (isFiltering)
            Text(
              l10n.learnFilteringBy(selectedTag ?? ''),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: tags
                .map(
                  (tag) => _TagFilterChip(
                    tag: tag,
                    style: tagStyleFor(tag),
                    isSelected: tag == selectedTag,
                    onSelected: onTagSelected,
                    onClear: onClearFilter,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  const _TagFilterChip({
    required this.tag,
    required this.style,
    required this.isSelected,
    required this.onSelected,
    required this.onClear,
  });

  final String tag;
  final TagStyle style;
  final bool isSelected;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: isSelected ? style.color.darken(0.35) : style.color.darken(),
        );

    return FilterChip(
      label: Text(style.label),
      labelStyle: labelStyle,
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: style.color, shape: BoxShape.circle),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: BorderSide(color: style.color.withValues(alpha: 0.35)),
      backgroundColor: style.color.withValues(alpha: 0.14),
      selectedColor: style.color.withValues(alpha: 0.26),
      showCheckmark: false,
      selected: isSelected,
      deleteIcon: isSelected ? const Icon(Icons.close, size: 18) : null,
      onDeleted: isSelected ? onClear : null,
      onSelected: (_) => isSelected ? onClear() : onSelected(tag),
    );
  }
}
