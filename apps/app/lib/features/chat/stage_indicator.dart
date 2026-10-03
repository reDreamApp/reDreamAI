import 'package:flutter/material.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

extension IrtStageLabel on IrtStage {
  String label(AppLocalizations l10n) => switch (this) {
    IrtStage.recording => l10n.stageRecording,
    IrtStage.intensity => l10n.stageIntensity,
    IrtStage.rewriting => l10n.stageRewriting,
    IrtStage.summary => l10n.stageSummary,
    IrtStage.finalStage => l10n.stageFinal,
  };
}

/// Compact step row for the IRT stage path.
class StageIndicator extends StatelessWidget {
  const StageIndicator({required this.path, required this.current, super.key});

  final List<IrtStage> path;
  final IrtStage current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final index = path.indexOf(current).clamp(0, path.length - 1);
    final inactive = scheme.outline;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (var i = 0; i < path.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 2,
                    color: i <= index ? scheme.primary : inactive,
                  ),
                ),
              _Step(state: i < index ? 2 : (i == index ? 1 : 0)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < path.length; i++)
              Expanded(
                child: Text(
                  path[i].label(l10n),
                  textAlign: i == 0
                      ? TextAlign.left
                      : (i == path.length - 1
                            ? TextAlign.right
                            : TextAlign.center),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
                    color: i <= index
                        ? scheme.onSurface
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.state});

  /// 0 future, 1 current, 2 completed.
  final int state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = state > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: state == 2
            ? scheme.primary
            : (state == 1
                  ? scheme.primary.withValues(alpha: 0.18)
                  : Colors.transparent),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? scheme.primary : scheme.outline,
          width: 2,
        ),
      ),
    );
  }
}
