import 'package:flutter/material.dart';
import 'package:redream_app/features/journal/dream.dart';
import 'package:redream_app/features/journal/practice_audio_screen.dart';
import 'package:redream_app/features/journal/practice_guided_screen.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

Future<void> showPracticeChooser(BuildContext context, Dream dream) async {
  final l10n = AppLocalizations.of(context)!;
  final choice = await showModalBottomSheet<Widget Function()>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: [
                  Text(
                    l10n.detailChoosePractice,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.detailChoosePracticeBody,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: Text(l10n.practiceReadingTitle),
              subtitle: Text(l10n.practiceReadingBody),
              onTap: () => Navigator.pop(
                ctx,
                () => PracticeGuidedScreen(dream: dream),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.graphic_eq_rounded),
              title: Text(l10n.practiceAudioTitle),
              subtitle: Text(l10n.practiceAudioBody),
              onTap: () => Navigator.pop(
                ctx,
                () => PracticeAudioScreen(dream: dream),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.cancel),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (_) => choice()),
  );
}
