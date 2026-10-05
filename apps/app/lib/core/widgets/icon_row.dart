import 'package:flutter/material.dart';

import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/widgets/app_card.dart';

/// One row of a card list: icon tile, title, optional second line and a
/// trailing widget. [color] tints the tile; without it the tile uses the
/// primary colour.
class IconRow extends StatelessWidget {
  const IconRow({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.color,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? color;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconTile(
            icon: icon,
            size: 40,
            color: color,
            background: color?.withValues(alpha: dark ? 0.2 : 0.12),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                  ),
                ),
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: BrandTheme.of(context).muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing case final trailing?) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// The "opens another screen" mark at the end of an [IconRow].
class RowChevron extends StatelessWidget {
  const RowChevron({super.key});

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.chevron_right_rounded, color: BrandTheme.of(context).muted);
}
