import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:redream_app/core/settings/app_settings.dart';

/// Sun/moon pill from the app bar. Explicit light/dark; never "system".
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final dark = settings.isDark(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            icon: Icons.light_mode_outlined,
            selected: !dark,
            onTap: () => settings.setThemeMode(ThemeMode.light),
          ),
          _Segment(
            icon: Icons.dark_mode_outlined,
            selected: dark,
            onTap: () => settings.setThemeMode(ThemeMode.dark),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 30,
        decoration: BoxDecoration(
          color: selected ? scheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 16,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
