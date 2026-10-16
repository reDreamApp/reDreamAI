import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/api/api_exception.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/core/widgets/feedback.dart';
import 'package:redream_app/features/consent/consent_screen.dart';
import 'package:redream_app/features/consent/consent_service.dart';
import 'package:redream_app/features/consent/consent_state.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class _FakeConsentService implements IConsentService {
  _FakeConsentService({this.requiredVersion = consentTextVersion});

  final String requiredVersion;
  ApiException? grantError;

  @override
  Future<ConsentStatus> status() async => ConsentStatus(
    requiredVersion: requiredVersion,
    grantedVersion: null,
    consentRequired: true,
  );

  @override
  Future<void> grant(String version) async {
    if (grantError case final error?) throw error;
  }

  @override
  Future<void> withdraw() async {}
}

/// The consent screen on a phone-sized display.
Future<void> _pumpConsent(
  WidgetTester tester,
  _FakeConsentService service,
) async {
  tester.view
    ..physicalSize = const Size(1080, 2340)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final state = ConsentState(service);
  await state.load();
  await tester.pumpWidget(
    ChangeNotifierProvider<ConsentState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ConsentScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The notice is on screen without scrolling.
void _expectNoticeVisible(WidgetTester tester, String text) {
  final message = find.text(text);
  expect(message, findsOneWidget);
  expect(
    find.ancestor(of: message, matching: find.byType(InlineNotice)),
    findsOneWidget,
  );
  final screen =
      Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  final rect = tester.getRect(message);
  expect(
    screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
    isTrue,
  );
}

void main() {
  testWidgets('an outdated consent text shows the update notice in view', (
    tester,
  ) async {
    await _pumpConsent(
      tester,
      _FakeConsentService(requiredVersion: '2099-01-01'),
    );

    _expectNoticeVisible(
      tester,
      'Update the app to review and accept the current consent text.',
    );
  });

  testWidgets('a refused grant shows the server message in view', (
    tester,
  ) async {
    const message = 'Please install the latest version of the app to continue.';
    final service = _FakeConsentService()
      ..grantError = ApiException(426, message);
    await _pumpConsent(tester, service);
    expect(find.byType(InlineNotice), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();

    _expectNoticeVisible(tester, message);
  });
}
