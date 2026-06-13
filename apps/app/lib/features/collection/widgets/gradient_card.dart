import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Reusable gradient card (ported from legacy widgets/gradient_card.dart).
///
/// Defaults to the brand gradient (violet → turquoise); pass [colors] for the
/// per-dream-type gradients used in the collection list.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.colors,
    this.elevation = 4,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.opacity = 0.5,
    this.borderWidth = 1.25,
    this.borderColor,
    this.onTap,
  });

  final Widget child;

  /// Gradient colors before [opacity] is applied. Null = brand gradient.
  final List<Color>? colors;
  final double elevation;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double opacity;
  final double borderWidth;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradientColors = (colors ?? BrandColors.brandGradient().colors)
        .map((color) => color.withValues(alpha: opacity))
        .toList(growable: false);
    final borderColorValue =
        borderColor ?? theme.colorScheme.outline.withValues(alpha: 0.4);

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: elevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(width: borderWidth, color: borderColorValue),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            splashColor: theme.colorScheme.primary.withValues(alpha: 0.08),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Per-dream-type gradients ported from legacy dream_collection.dart.
abstract final class DreamGradients {
  /// Plain dreams (no rewritten version): calm teal/blue.
  static List<Color> positive({required bool isDark}) => isDark
      ? const [Color(0xFF0E2434), Color(0xFF124355), Color(0xFF1FB6AE)]
      : [
          Colors.green.withValues(alpha: 0.6),
          Colors.blue.withValues(alpha: 0.6),
        ];

  /// Transformed nightmares (rewritten version present): warm accent.
  static List<Color> nightmare({required bool isDark}) => isDark
      ? const [Color(0xFF2E101C), Color(0xFF7C1F32), Color(0xFFFF5B3B)]
      : [
          Colors.red.withValues(alpha: 0.6),
          Colors.orange.withValues(alpha: 0.6),
        ];
}
