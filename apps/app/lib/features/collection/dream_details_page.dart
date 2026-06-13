import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/dream.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import 'collection_screen.dart' show showDeleteDreamDialog;
import 'collection_state.dart';
import 'irt_practice_page.dart';
import 'widgets/gradient_card.dart';

/// Full dream view with inline editing, intensity slider, set-as-current,
/// delete and entry to the IRT practice flow (ported from legacy
/// dream_details_page.dart, restructured as a scrollable column).
class DreamDetailsPage extends StatefulWidget {
  const DreamDetailsPage({super.key, required this.dreamId});

  final int dreamId;

  @override
  State<DreamDetailsPage> createState() => _DreamDetailsPageState();
}

class _DreamDetailsPageState extends State<DreamDetailsPage> {
  bool _busy = false;

  /// Local slider position while dragging; null = follow the dream's value.
  double? _pendingIntensity;

  Future<void> _saveField(String jsonKey, String value) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<DreamCollectionState>().updateDream(widget.dreamId, {
        jsonKey: value,
      });
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dreamSaveFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveIntensity(int value) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<DreamCollectionState>().updateDream(widget.dreamId, {
        'intensity': value,
      });
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dreamSaveFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _pendingIntensity = null;
        });
      }
    }
  }

  Future<void> _editField({
    required String dialogTitle,
    required String jsonKey,
    required String initialValue,
    bool multiline = false,
  }) async {
    final result = await _showEditDialog(
      context,
      title: dialogTitle,
      initialValue: initialValue,
      multiline: multiline,
    );
    if (result == null || !mounted) return;
    if (result == initialValue) return;
    await _saveField(jsonKey, result);
  }

  Future<void> _setCurrent() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await context.read<DreamCollectionState>().setCurrentDream(
        widget.dreamId,
      );
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.dreamSetCurrentSuccess)),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.dreamActionFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDeleteDreamDialog(context);
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<DreamCollectionState>().deleteDream(widget.dreamId);
      navigator.pop();
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(l10n.dreamDeleteFailed)));
    }
  }

  void _startPractice() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IrtPracticePage(dreamId: widget.dreamId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = context.watch<DreamCollectionState>();
    final dream = state.dreamById(widget.dreamId);

    if (dream == null) {
      // Dream disappeared (deleted elsewhere / state reset).
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }

    final isTransformed = dream.rewrittenDream != null;
    final intensityValue =
        _pendingIntensity ?? (dream.intensity?.toDouble() ?? 0.0);
    final date = DateFormat.yMMMd(
      l10n.localeName,
    ).format(dream.createdAt.toLocal());

    return Scaffold(
      appBar: AppBar(
        title: Text(dream.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (value) {
              switch (value) {
                case 'current':
                  _setCurrent();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (context) => [
              if (isTransformed && !dream.isCurrentDream)
                PopupMenuItem<String>(
                  value: 'current',
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_outline,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(l10n.dreamSetCurrent),
                    ],
                  ),
                ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Text(l10n.dreamDeleteAction),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: BrandColors.backgroundGradient(isDark),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // Header: date, badges, practice info.
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isTransformed && dream.isCurrentDream) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.star, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.dreamCurrentBadge,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Title (editable).
            _SectionCard(
              header: _SectionHeader(
                label: dream.title,
                titleStyle: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                onEdit: _busy
                    ? null
                    : () => _editField(
                        dialogTitle: l10n.dreamEditTitleDialog,
                        jsonKey: 'title',
                        initialValue: dream.title,
                      ),
              ),
            ),

            // Rewritten dream — highlighted gradient card (legacy accent).
            if (isTransformed)
              GradientCard(
                colors: DreamGradients.positive(isDark: isDark),
                opacity: isDark ? 1.0 : 0.5,
                child: _DreamTextSection(
                  label: l10n.dreamRewrittenLabel,
                  text: dream.rewrittenDream!,
                  onEdit: _busy
                      ? null
                      : () => _editField(
                          dialogTitle: l10n.dreamEditRewrittenDialog,
                          jsonKey: 'rewritten_dream',
                          initialValue: dream.rewrittenDream!,
                          multiline: true,
                        ),
                ),
              ),

            // Original dream.
            GradientCard(
              colors: isTransformed
                  ? DreamGradients.nightmare(isDark: isDark)
                  : DreamGradients.positive(isDark: isDark),
              opacity: isDark ? 1.0 : 0.5,
              child: _DreamTextSection(
                label: isTransformed
                    ? l10n.dreamOriginalLabel
                    : l10n.dreamLabel,
                text: dream.originalDream,
                onEdit: _busy
                    ? null
                    : () => _editField(
                        dialogTitle: l10n.dreamEditOriginalDialog,
                        jsonKey: 'original_dream',
                        initialValue: dream.originalDream,
                        multiline: true,
                      ),
              ),
            ),

            // Intensity slider (0–10).
            if (dream.isNightmare || isTransformed || dream.intensity != null)
              _SectionCard(
                header: _SectionHeader(
                  label: l10n.dreamIntensityLabel,
                  trailing: Text(
                    dream.intensity == null && _pendingIntensity == null
                        ? l10n.dreamIntensityNotSet
                        : '${intensityValue.round()}/10',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                child: Slider(
                  value: intensityValue.clamp(0.0, 10.0),
                  max: 10,
                  divisions: 10,
                  label: '${intensityValue.round()}',
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _pendingIntensity = v),
                  onChangeEnd: _busy ? null : (v) => _saveIntensity(v.round()),
                ),
              ),

            // Practice stats + start button for transformed nightmares.
            if (isTransformed) ...[
              _SectionCard(
                header: _SectionHeader(
                  label: l10n.practiceCount(dream.practiceTimestamps.length),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dream.practiceTimestamps.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          l10n.practiceLastPracticed(
                            DateFormat.yMMMd(l10n.localeName).format(
                              _lastPractice(dream).toLocal(),
                            ),
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _startPractice,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(l10n.practiceStart),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  DateTime _lastPractice(Dream dream) =>
      dream.practiceTimestamps.reduce((a, b) => a.isAfter(b) ? a : b);
}

Future<String?> _showEditDialog(
  BuildContext context, {
  required String title,
  required String initialValue,
  required bool multiline,
}) {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initialValue);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: multiline ? 5 : 1,
        maxLines: multiline ? 12 : 2,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.dreamCancel),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            if (value.isEmpty) return; // Keep dialog open for empty input.
            Navigator.of(context).pop(value);
          },
          child: Text(l10n.dreamSave),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Plain (non-gradient) section card with optional [child] below the header.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.header, this.child});

  final _SectionHeader header;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if (child != null) ...[const SizedBox(height: 8), child!],
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    this.titleStyle,
    this.onEdit,
    this.trailing,
  });

  final String label;
  final TextStyle? titleStyle;
  final VoidCallback? onEdit;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style:
                titleStyle ??
                theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        ?trailing,
        if (onEdit != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.edit_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            onPressed: onEdit,
          ),
      ],
    );
  }
}

/// Dream text block inside a gradient card, with an edit affordance.
class _DreamTextSection extends StatelessWidget {
  const _DreamTextSection({
    required this.label,
    required this.text,
    this.onEdit,
  });

  final String label;
  final String text;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (onEdit != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: theme.colorScheme.onSurface,
                ),
                onPressed: onEdit,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
