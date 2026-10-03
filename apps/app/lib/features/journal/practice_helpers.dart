import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/journal/dream.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

/// Records a practice, reports the outcome and pops on success.
Future<void> completePractice(BuildContext context, Dream dream) async {
  final l10n = AppLocalizations.of(context)!;
  try {
    final result = await context.read<JournalState>().recordPractice(dream);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      result.alreadyToday
          ? l10n.practiceAlreadyToday
          : result.savedOffline
          ? l10n.practiceSavedOffline
          : l10n.practiceRecorded,
      duration: const Duration(seconds: 4),
    );
    Navigator.pop(context, result.dream);
  } on Exception catch (e) {
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      l10n.practiceSaveFailed(describeError(e, l10n)),
      error: true,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(
        label: l10n.retry,
        textColor: Colors.white,
        onPressed: () => completePractice(context, dream),
      ),
    );
  }
}

class PageDots extends StatelessWidget {
  const PageDots({required this.count, required this.index, super.key});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == index ? scheme.primary : scheme.outline,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
