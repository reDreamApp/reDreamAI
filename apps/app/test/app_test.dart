import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/app.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/features/reminders/notification_service.dart';
import 'package:redream_app/l10n/generated/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fake_auth.dart';

final _en = AppLocalizationsEn();

Future<(Widget, FakeApi, AppSettings)> _app({
  FakeAuth? auth,
  bool consentRequired = false,
}) async {
  var needsConsent = consentRequired;
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final settings = AppSettings(store, platformLanguage: 'en');
  final api = FakeApi()
    ..on(
      'GET /api/v1/dreams',
      (_, _) => [
        dreamJson(1, current: true, practices: ['2025-11-03T10:00:00Z']),
        dreamJson(
          2,
          title: 'Flying',
          nightmare: false,
          rewritten: null,
          intensity: null,
        ),
      ],
    )
    ..on('GET /api/v1/progress/stats', (_, _) => statsJson())
    ..on(
      'GET /api/v1/users/me/consent',
      (_, _) => consentJson(required: needsConsent),
    )
    ..on('POST /api/v1/users/me/consent', (_, _) {
      needsConsent = false;
      return null;
    })
    ..on('DELETE /api/v1/users/me/consent', (_, _) {
      needsConsent = true;
      return null;
    })
    ..on('PUT /api/v1/chats/{id}/intensity', (_, _) => {'ok': true})
    ..on(
      'GET /api/v1/chats',
      (_, _) => [chatJson(3, done: true, title: 'Old chat')],
    )
    ..on(
      'GET /api/v1/profile',
      (_, _) => {
        'gender': null,
        'age_range': null,
        'nightmare_frequency': 'Rarely',
      },
    )
    ..on(
      'POST /api/v1/chats/start',
      (_, _) => {'chat_id': 7, 'language': 'en', 'current_stage': 'recording'},
    )
    ..on(
      'POST /api/v1/chats/{id}/message/stream',
      (_, body) => body['content'] == 'yes, done'
          ? streamTurn(
              userText: 'yes, done',
              reply: 'Thank you for this session.',
              stage: 'final',
              done: true,
            )
          : streamTurn(
              userText: body['content'] as String,
              reply: 'Tell me more about it.',
            ),
    );
  final services = AppServices(
    api: api.client(token: 'test'),
    store: store,
    notifications: NotificationService(),
  );
  final app = MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthService>.value(value: auth ?? FakeAuth()),
      ChangeNotifierProvider<AppSettings>.value(value: settings),
      Provider<AppServices>.value(value: services),
    ],
    child: const ReDreamApp(),
  );
  return (app, api, settings);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Phone-sized but tall enough that lazily built lists render every card.
void _tallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('signed out shows the sign-in screen and signs in', (
    tester,
  ) async {
    final auth = FakeAuth();
    final (app, _, _) = await _app(auth: auth);
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    expect(find.text('Transform Your Nightmares'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'me@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret1');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await _settle(tester);

    expect(auth.signIns, ['me@example.com']);
    expect(find.text('Your Progress'), findsOneWidget);
  });

  testWidgets('home shows progress from the API and tabs switch screens', (
    tester,
  ) async {
    final (app, api, _) = await _app(
      auth: FakeAuth(userId: 'user-1', email: 'me@example.com'),
    );
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    expect(find.text('Begin Session'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    expect(
      find.textContaining('Focus dream: Lost in Dark Forest'),
      findsOneWidget,
    );
    expect(
      api.calls,
      containsAll(['GET /api/v1/dreams', 'GET /api/v1/progress/stats']),
    );

    await tester.tap(find.text('Journal'));
    await _settle(tester);
    expect(find.text('Dream Journal'), findsOneWidget);
    expect(find.text('Lost in Dark Forest'), findsOneWidget);
    expect(find.text('Intensity: 8/10'), findsOneWidget);
    expect(find.text('1 practiced | 13 remaining'), findsOneWidget);
    expect(find.text('Practice Dream'), findsOneWidget);
    expect(find.text('Flying'), findsOneWidget);

    await tester.tap(find.text('Nightmares'));
    await _settle(tester);
    expect(find.text('Flying'), findsNothing);
    expect(find.text('Showing 1 of 2 entries'), findsOneWidget);
  });

  testWidgets('session tab sends a message and renders the reply', (
    tester,
  ) async {
    final (app, api, _) = await _app(
      auth: FakeAuth(userId: 'user-1', email: 'me@example.com'),
    );
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.text('Session'));
    await _settle(tester);
    expect(find.text('reDreamAI Assistant'), findsOneWidget);
    expect(find.text(_en.chatWelcome), findsOneWidget);

    await tester.enterText(
      find.byType(TextField).last,
      'I dreamt about losing my dog',
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);

    expect(api.calls, contains('POST /api/v1/chats/start'));
    expect(api.calls, contains('POST /api/v1/chats/7/message/stream'));
    expect(find.text('I dreamt about losing my dog'), findsOneWidget);
    expect(find.text('Tell me more about it.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    expect(find.text('Chat History'), findsOneWidget);
    expect(find.text('Old chat'), findsOneWidget);
  });

  testWidgets('back closes the chat history instead of leaving the app', (
    tester,
  ) async {
    final (app, _, _) = await _app(
      auth: FakeAuth(userId: 'user-1', email: 'me@example.com'),
    );
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.text('Session'));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    expect(find.text('Chat History'), findsOneWidget);

    // What Android's back button or gesture sends.
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.text('Chat History'), findsNothing);
    expect(find.text('reDreamAI Assistant'), findsOneWidget);
  });

  testWidgets('journal buttons show their full labels', (tester) async {
    final (app, _, _) = await _app(
      auth: FakeAuth(userId: 'user-1', email: 'me@example.com'),
    );
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.text('Journal'));
    await _settle(tester);

    for (final label in [_en.journalAddDream, _en.journalNotifications]) {
      final text = tester.renderObject<RenderParagraph>(find.text(label));
      // A label cut off with "…" is laid out narrower than its text needs.
      expect(
        text.size.width,
        moreOrLessEquals(
          text.getMaxIntrinsicWidth(double.infinity),
          epsilon: 0.5,
        ),
        reason: label,
      );
    }
  });

  testWidgets('theme toggle persists the chosen mode', (tester) async {
    final (app, _, settings) = await _app(auth: FakeAuth(userId: 'user-1'));
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    Color? sunColor() =>
        tester.widget<Icon>(find.byIcon(Icons.light_mode_outlined)).color;
    expect(sunColor(), BrandColors.sun);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await _settle(tester);
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Your Progress'))).brightness,
      Brightness.dark,
    );
    // The sun is only yellow while light mode is the active one.
    expect(sunColor(), isNot(BrandColors.sun));
  });

  testWidgets('lists stop at their ends without stretching the screen', (
    tester,
  ) async {
    final (app, _, _) = await _app(auth: FakeAuth(userId: 'user-1'));
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    // Widget tests run as Android, where Material 3 stretches by default.
    expect(find.byType(Scrollable), findsWidgets);
    expect(find.byType(StretchingOverscrollIndicator), findsNothing);
  });

  testWidgets('consent gate blocks until the user agrees', (tester) async {
    final (app, api, _) = await _app(
      auth: FakeAuth(userId: 'user-1'),
      consentRequired: true,
    );
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    expect(find.text(_en.consentTitle), findsOneWidget);
    expect(find.text('Your Progress'), findsNothing);
    final agree = find.widgetWithText(FilledButton, _en.consentContinue);
    expect(tester.widget<FilledButton>(agree).onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await _settle(tester);
    await tester.tap(agree);
    await _settle(tester);

    expect(api.calls, contains('POST /api/v1/users/me/consent'));
    expect(find.text('Your Progress'), findsOneWidget);
  });

  testWidgets('settings opens with user state and can withdraw consent', (
    tester,
  ) async {
    final (app, api, _) = await _app(auth: FakeAuth(userId: 'user-1'));
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(api.calls, contains('GET /api/v1/profile'));

    await tester.tap(find.text(_en.settingsWithdrawConsent));
    await _settle(tester);
    await tester.tap(find.text(_en.withdrawConsentConfirm));
    await _settle(tester);

    expect(api.calls, contains('DELETE /api/v1/users/me/consent'));
    expect(find.text(_en.consentTitle), findsOneWidget);
  });

  testWidgets('dream details open from the journal', (tester) async {
    final (app, _, _) = await _app(auth: FakeAuth(userId: 'user-1'));
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.text('Journal'));
    await _settle(tester);
    await tester.tap(find.text('Flying'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Flying'), findsWidgets);
  });

  testWidgets('a finished session asks for the intensity rating', (
    tester,
  ) async {
    final (app, api, _) = await _app(auth: FakeAuth(userId: 'user-1'));
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.text('Session'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'yes, done');
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);

    expect(find.text('Thank you for this session.'), findsOneWidget);
    expect(find.text(_en.chatIntensityPrompt), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, _en.submit));
    await _settle(tester);

    expect(api.calls, contains('PUT /api/v1/chats/7/intensity'));
    expect(find.text(_en.chatIntensityPrompt), findsNothing);
    expect(find.text(_en.chatSessionDoneCta), findsOneWidget);
  });
}
