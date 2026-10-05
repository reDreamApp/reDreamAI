import 'package:flutter/material.dart';

import 'package:redream_app/core/theme/app_theme.dart';

/// Bordered surface card. [highlight] uses the tinted "call to action" look;
/// [gradient] replaces the flat surface colour.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.highlight = false,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool highlight;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = BrandTheme.of(context);
    final radius = BorderRadius.circular(16);
    final body = Padding(padding: padding, child: child);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient != null
            ? null
            : highlight
            ? brand.highlightSurface
            : Theme.of(context).colorScheme.surface,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(
          color:
              borderColor ??
              (highlight ? brand.highlightBorder : brand.cardBorder),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? body
          : InkWell(onTap: onTap, borderRadius: radius, child: body),
    );
  }
}

/// Rounded icon tile used in card headers and stat rows.
class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    super.key,
    this.size = 48,
    this.color,
    this.background,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.primaryContainer,
        borderRadius: BorderRadius.circular(size / 4),
      ),
      child: Icon(icon, size: size * 0.5, color: color ?? scheme.primary),
    );
  }
}
