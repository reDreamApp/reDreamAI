import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Subtle card border colors ported from the legacy theme.
abstract final class CardBorders {
  static const Color dark = Color(0x26818CF8); // rgba(129, 140, 248, 0.15)
  static const Color light = Color(0x14000000); // rgba(0, 0, 0, 0.08)

  static Color of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Reusable gradient card (violet → turquoise), ported from the legacy
/// widgets/gradient_card.dart so home/progress surfaces match the brand look.
class GradientCard extends StatelessWidget {
  const GradientCard({
    super.key,
    required this.child,
    this.elevation = 4,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.opacity = 0.5,
    this.borderWidth = 1.25,
    this.borderColor,
  });

  final Widget child;
  final double elevation;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double opacity;
  final double borderWidth;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final gradient = BrandColors.brandGradient();

    return Container(
      margin: margin,
      child: Card(
        elevation: elevation,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient.colors
                  .map((color) => color.withValues(alpha: opacity))
                  .toList(),
              begin: gradient.begin,
              end: gradient.end,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              width: borderWidth,
              color: borderColor ?? CardBorders.of(context),
            ),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
