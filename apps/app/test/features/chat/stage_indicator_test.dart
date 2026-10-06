import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/stage_indicator.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('inner labels sit under their moons, outer ones at the edges', (
    tester,
  ) async {
    // 20 px moons at both ends and at even steps: 10, 110, 210, 310.
    const width = 320.0;
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(
          child: SizedBox(
            width: width,
            child: StageIndicator(current: IrtStage.rewriting),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final left = tester.getTopLeft(find.byType(StageIndicator)).dx;
    double centre(String label) => tester.getCenter(find.text(label)).dx - left;

    expect(centre('Rewriting'), closeTo(110, 0.5));
    expect(centre('Summary'), closeTo(210, 0.5));
    expect(
      tester.getTopLeft(find.text('Recording')).dx - left,
      closeTo(0, 0.5),
    );
    expect(
      tester.getTopRight(find.text('Final')).dx - left,
      closeTo(width, 0.5),
    );
  });
}
