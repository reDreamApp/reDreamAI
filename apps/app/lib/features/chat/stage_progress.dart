import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'chat_models.dart';

/// Horizontal 5-step IRT progress bar above the chat, ported from legacy
/// `chat_builders.dart` `stageProgressIndicator`: one square per stage
/// (recording → intensity → rewriting → summary → final) joined by
/// connector lines, with the current stage highlighted.
class StageProgressBar extends StatelessWidget {
  const StageProgressBar({required this.stage, super.key});

  final IrtStage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    const stages = IrtStage.values;
    final stageIndex = stages.indexOf(stage);
    final activeColor = theme.colorScheme.tertiary;
    final inactiveColor =
        theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var index = 0; index < stages.length; index++) ...[
                _StageSquare(
                  isCompleted: index < stageIndex,
                  isCurrent: index == stageIndex,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                ),
                if (index != stages.length - 1)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index < stageIndex ? activeColor : inactiveColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < stages.length; index++)
                Expanded(
                  child: Text(
                    _label(stages[index], l10n),
                    textAlign: index == 0
                        ? TextAlign.left
                        : index == stages.length - 1
                            ? TextAlign.right
                            : TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: index == stageIndex
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: index <= stageIndex
                          ? theme.colorScheme.onSurface
                          : inactiveColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(IrtStage s, AppLocalizations l10n) {
    switch (s) {
      case IrtStage.recording:
        return l10n.stageRecording;
      case IrtStage.intensity:
        return l10n.stageIntensity;
      case IrtStage.rewriting:
        return l10n.stageRewriting;
      case IrtStage.summary:
        return l10n.stageSummary;
      case IrtStage.finalStage:
        return l10n.stageFinal;
    }
  }
}

class _StageSquare extends StatelessWidget {
  const _StageSquare({
    required this.isCompleted,
    required this.isCurrent,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool isCompleted;
  final bool isCurrent;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final fillColor = isCompleted
        ? activeColor
        : isCurrent
            ? activeColor.withValues(alpha: 0.15)
            : Colors.transparent;
    final borderColor = isCompleted || isCurrent ? activeColor : inactiveColor;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 2),
      ),
    );
  }
}
