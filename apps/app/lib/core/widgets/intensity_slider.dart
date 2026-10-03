import 'package:flutter/material.dart';

import 'package:redream_app/l10n/generated/app_localizations.dart';

/// 0–10 nightmare intensity picker used by the editor and the chat.
class IntensitySlider extends StatelessWidget {
  const IntensitySlider({
    required this.value,
    required this.onChanged,
    super.key,
    this.title,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        Slider(
          value: value.toDouble(),
          max: 10,
          divisions: 10,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.intensityMild, style: theme.textTheme.bodySmall),
            Chip(label: Text(l10n.intensitySelected(value))),
            Text(l10n.intensityExtreme, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}
