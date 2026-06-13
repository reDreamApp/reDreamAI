import 'package:flutter/material.dart';

import '../educational_article.dart';

/// Pill-shaped topic tag, ported from the legacy
/// screens/learn/widgets/category_indicators.dart.
class CategoryTag extends StatelessWidget {
  const CategoryTag({super.key, required this.style});

  final TagStyle style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final baseColor = style.color;
    final backgroundColor = Color.alphaBlend(
      Colors.white.withValues(alpha: isDarkMode ? 0.08 : 0.3),
      baseColor.withValues(alpha: isDarkMode ? 0.5 : 0.25),
    );
    final borderColor = baseColor.withValues(alpha: isDarkMode ? 0.25 : 0.55);
    final labelColor = baseColor.darken(isDarkMode ? 0.5 : 0.25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        style.label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
      ),
    );
  }
}
