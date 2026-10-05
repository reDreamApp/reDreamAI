import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

/// Sun/moon pill from the app bar. Explicit light/dark; never "system".
/// A tap anywhere on it switches to the other mode.
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final dark = settings.isDark(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: dark,
      label: AppLocalizations.of(context)!.settingsThemeSubtitle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            settings.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
        // The padding is part of the tap target; the pill itself is 32 high.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
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
                  selectedColor: BrandColors.sun,
                ),
                _Segment(
                  icon: Icons.dark_mode_outlined,
                  selected: dark,
                  selectedColor: scheme.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.selected,
    required this.selectedColor,
  });

  final IconData icon;
  final bool selected;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 30,
      decoration: BoxDecoration(
        color: selected ? scheme.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        icon,
        size: 16,
        color: selected ? selectedColor : scheme.onSurfaceVariant,
      ),
    );
  }
}
