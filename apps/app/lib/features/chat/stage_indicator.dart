import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

extension IrtStageLabel on IrtStage {
  String label(AppLocalizations l10n) => switch (this) {
    IrtStage.recording => l10n.stageRecording,
    IrtStage.rewriting => l10n.stageRewriting,
    IrtStage.summary => l10n.stageSummary,
    IrtStage.finalStage => l10n.stageFinal,
  };
}

/// The colour of each stage's moon; the line blends from one to the next:
/// lilac, the app's light blue, green, and yellow for the last one.
const List<Color> stageColors = [
  Color(0xFF8B5CF6),
  BrandColors.turquoise,
  BrandColors.green,
  Color(0xFFF6C51B),
];

/// How far the shadow sits from each moon's centre, in radii: a slim
/// crescent for the first stage, more of the disc with every stage, and
/// the full moon at the end.
const _shadowOffsets = [0.42, 0.85, 1.38, 2.2];

const _moon = 20.0;
const _gap = 3.0;
const _barHeight = 30.0;

/// Progress bar of the routed chat stages: a line with one moon per stage,
/// growing from crescent to full, that fills in the stages' colours up to
/// the current one.
class StageIndicator extends StatelessWidget {
  const StageIndicator({required this.current, super.key});

  final IrtStage current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    const path = IrtStage.values;
    final index = path.indexOf(current);
    final last = path.length - 1;

    Widget label(int i, Alignment alignment) => Align(
      alignment: alignment,
      // A long label ("Zusammenfassung") shrinks instead of being cut off.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Text(
          path[i].label(l10n),
          maxLines: 1,
          style: TextStyle(
            fontSize: 11,
            fontWeight: i == index ? FontWeight.w600 : FontWeight.w400,
            color: i <= index ? scheme.onSurface : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: index / last),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          builder: (context, progress, _) => CustomPaint(
            size: const Size(double.infinity, _barHeight),
            painter: _BarPainter(
              progress: progress,
              inactive: scheme.outline,
              // The inside of a moon takes the tone of the page.
              inside: Theme.of(context).scaffoldBackgroundColor,
            ),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // The moons sit at the ends and at even steps between them; the
            // outer labels hug the edges, the inner ones centre on a moon.
            final step = (constraints.maxWidth - _moon) / last;
            return SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (var i = 0; i <= last; i++)
                    if (i == 0)
                      Positioned(
                        left: 0,
                        width: _moon / 2 + step / 2,
                        top: 0,
                        bottom: 0,
                        child: label(i, Alignment.centerLeft),
                      )
                    else if (i == last)
                      Positioned(
                        right: 0,
                        width: _moon / 2 + step / 2,
                        top: 0,
                        bottom: 0,
                        child: label(i, Alignment.centerRight),
                      )
                    else
                      Positioned(
                        left: _moon / 2 + (i - 0.5) * step,
                        width: step,
                        top: 0,
                        bottom: 0,
                        child: label(i, Alignment.center),
                      ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.progress,
    required this.inactive,
    required this.inside,
  });

  /// 0 at the first moon, 1 at the last; animated between stages.
  final double progress;
  final Color inactive;
  final Color inside;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 4;
    const r = _moon / 2;
    final y = size.height / 2;
    final span = size.width - _moon;
    double x(int i) => r + span * i / (count - 1);
    final reach = r + span * progress;

    // The line runs between the moons and keeps a small distance to them.
    void segments(Paint paint) {
      for (var i = 0; i < count - 1; i++) {
        canvas.drawLine(
          Offset(x(i) + r + _gap, y),
          Offset(x(i + 1) - r - _gap, y),
          paint,
        );
      }
    }

    Paint line() => Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    segments(line()..color = inactive);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, reach, size.height));
    segments(
      line()
        ..shader = const LinearGradient(
          colors: stageColors,
        ).createShader(Rect.fromLTRB(r, 0, size.width - r, size.height)),
    );
    canvas.restore();

    for (var i = 0; i < count; i++) {
      final center = Offset(x(i), y);
      // A moon lights up once the line has (nearly) arrived at it.
      final reached = progress >= i / (count - 1) - 0.02;
      final color = reached ? stageColors[i] : inactive;
      final disc = Path()..addOval(Rect.fromCircle(center: center, radius: r));
      // The shadow lies to the upper right, as on the dark-mode symbol.
      final shadow = Path()
        ..addOval(
          Rect.fromCircle(
            center:
                center +
                const Offset(1, -1) * (r * _shadowOffsets[i] / math.sqrt2),
            radius: r,
          ),
        );
      final lit = Path.combine(PathOperation.difference, disc, shadow);

      if (reached && i == count - 1) {
        // The full moon shines orange.
        canvas.drawCircle(
          center,
          r + 3,
          Paint()
            ..color = BrandColors.flame.withValues(alpha: 0.7)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas
        // The part in shadow, barely there.
        ..drawPath(disc, Paint()..color = inside)
        ..drawPath(disc, Paint()..color = color.withValues(alpha: 0.14))
        // The lit part: the colour at the edge, the page's tone inside.
        ..drawPath(lit, Paint()..color = Color.lerp(color, inside, 0.62)!)
        ..drawPath(
          lit,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeJoin = StrokeJoin.round
            ..color = color,
        );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.progress != progress ||
      old.inactive != inactive ||
      old.inside != inside;
}
