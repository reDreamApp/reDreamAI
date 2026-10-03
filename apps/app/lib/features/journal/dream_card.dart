import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/utils/errors.dart';
import 'package:redream_app/core/utils/formatting.dart';
import 'package:redream_app/core/widgets/app_button.dart';
import 'package:redream_app/core/widgets/app_card.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/journal/dream.dart';
import 'package:redream_app/features/journal/dream_detail_screen.dart';
import 'package:redream_app/features/journal/dream_editor_screen.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:redream_app/features/journal/practice_chooser.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

enum _Action { focus, edit, delete }

class DreamCard extends StatelessWidget {
  const DreamCard({required this.dream, super.key});

  final Dream dream;

  Future<void> _onAction(BuildContext context, _Action action) async {
    final l10n = AppLocalizations.of(context)!;
    final journal = context.read<JournalState>();
    switch (action) {
      case _Action.focus:
        if (dream.isLocal) {
          showAppSnackBar(context, l10n.journalSyncDraftFirst);
          return;
        }
        try {
          await journal.setFocus(dream);
        } on Exception catch (e) {
          if (context.mounted) {
            showAppSnackBar(
              context,
              l10n.journalFocusFailed(describeError(e, l10n)),
              error: true,
            );
          }
        }
      case _Action.edit:
        await Navigator.push(
          context,
          MaterialPageRoute<Dream>(
            fullscreenDialog: true,
            builder: (_) => DreamEditorScreen(existing: dream),
          ),
        );
      case _Action.delete:
        final ok = await confirmDialog(
          context,
          title: l10n.journalDeleteTitle,
          body: l10n.journalDeleteBody,
          confirmLabel: l10n.delete,
          cancelLabel: l10n.cancel,
          destructive: true,
        );
        if (!ok) return;
        try {
          await journal.delete(dream);
        } on Exception catch (e) {
          if (context.mounted) {
            showAppSnackBar(
              context,
              l10n.journalDeleteFailed(describeError(e, l10n)),
              error: true,
            );
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brand = BrandTheme.of(context);
    final practicable = dream.isNightmare && dream.hasRewrite;
    final focus = dream.isCurrentDream && dream.hasRewrite;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.zero,
      borderColor: focus ? scheme.primary : null,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DreamDetailScreen(dream: dream),
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 36),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.image_outlined,
                          size: 20,
                          color: brand.muted,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          dream.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatShortDate(dream.createdAt),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: brand.muted,
                      ),
                    ),
                    if (dream.intensity != null)
                      _Pill(text: l10n.journalIntensity(dream.intensity!)),
                    if (focus)
                      _Pill(
                        text: l10n.journalFocusLabel,
                        icon: Icons.star_rounded,
                        color: scheme.primary,
                      ),
                    if (dream.isLocal)
                      _Pill(
                        text: l10n.journalDraftLabel,
                        icon: Icons.cloud_off_outlined,
                        color: brand.muted,
                      ),
                  ],
                ),
                if (practicable) ...[
                  const SizedBox(height: 18),
                  _PracticeDots(count: dream.practiceCount),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.journalPracticed(
                            dream.practiceCount,
                            dream.practiceRemaining,
                          ),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            minHeight: 8,
                            value: (dream.practiceCount / Dream.practiceTarget)
                                .clamp(0, 1),
                            backgroundColor: scheme.surfaceContainerHighest,
                            color: brand.inverseSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: l10n.journalPracticeDream,
                    icon: Icons.adjust_rounded,
                    onPressed: () => showPracticeChooser(context, dream),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<_Action>(
              icon: Icon(Icons.more_vert, color: brand.muted),
              onSelected: (a) => _onAction(context, a),
              itemBuilder: (_) => [
                if (practicable && !dream.isCurrentDream)
                  PopupMenuItem(
                    value: _Action.focus,
                    child: Text(l10n.journalSetFocus),
                  ),
                PopupMenuItem(value: _Action.edit, child: Text(l10n.edit)),
                PopupMenuItem(
                  value: _Action.delete,
                  child: Text(
                    l10n.delete,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon, this.color});

  final String text;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeDots extends StatelessWidget {
  const _PracticeDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < Dream.practiceTarget; i++)
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < count ? BrandColors.turquoise : scheme.outline,
            ),
          ),
      ],
    );
  }
}
