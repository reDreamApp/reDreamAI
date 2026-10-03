import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/app.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/reminders/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';
import 'fake_auth.dart';

Future<(Widget, FakeApi, AppSettings)> _app({FakeAuth? auth}) async {
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
      'POST /api/v1/chats/{id}/message',
      (_, body) => {
        'chat_id': 7,
        'user_message': messageJson(
          'u1',
          role: 'user',
          content: body['content'] as String,
        ),
        'ai_message': messageJson(
          'a1',
          role: 'assistant',
          content: 'Tell me more about it.',
        ),
        'stage': 'recording',
        'is_done': false,
        'safety_event': null,
      },
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
    expect(
      find.textContaining('Imagery Rehearsal Therapy for your nightmares'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextField).last,
      'I dreamt about losing my dog',
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await _settle(tester);

    expect(api.calls, contains('POST /api/v1/chats/start'));
    expect(find.text('I dreamt about losing my dog'), findsOneWidget);
    expect(find.text('Tell me more about it.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await _settle(tester);
    expect(find.text('Chat History'), findsOneWidget);
    expect(find.text('Old chat'), findsOneWidget);
  });

  testWidgets('theme toggle persists the chosen mode', (tester) async {
    final (app, _, settings) = await _app(auth: FakeAuth(userId: 'user-1'));
    _tallPhone(tester);
    await tester.pumpWidget(app);
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.dark_mode_outlined));
    await _settle(tester);
    expect(settings.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Your Progress'))).brightness,
      Brightness.dark,
    );
  });
}
