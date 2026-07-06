/// Live smoke test — drives the REAL app against the local dev stack.
///
/// Prerequisites (see docs in repo root):
///   - `supabase start` running (local Supabase on :54321/:54322)
///   - apps/ai on :8080 and apps/api on :8001
///   - test user test@local.dev / Test-12345-chat (created via GoTrue admin API)
///   - apps/app/.env pointing at the local stack (10.0.2.2 on Android)
///
/// Run: fvm flutter test integration_test/live_smoke_test.dart -d <device>
///
/// This intentionally hits the real AI service (real LLM calls), so it is NOT
/// part of `flutter test` CI — it's the manual cross-platform smoke check.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/features/auth/sign_in_screen.dart';
import 'package:redream_app/features/auth/widgets/auth_email_field.dart';
import 'package:redream_app/features/auth/widgets/auth_password_field.dart';
import 'package:redream_app/features/onboarding/onboarding_screen.dart';
import 'package:redream_app/features/chat/chat_screen.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/shell/main_screen.dart';
import 'package:redream_app/features/shell/tab_navigator.dart';
import 'package:redream_app/main.dart' as app;

const _email = 'test@local.dev';
const _password = 'Test-12345-chat';

/// Pump until [condition] is true, failing after [timeout].
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out after $timeout waiting for: $description');
    }
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign in, open chat, send a message, receive AI reply',
      (tester) async {
    // In-memory prefs make every run hermetic: no persisted Supabase session
    // (always a fresh sign-in) and — crucially — no first-run onboarding.
    // HomeScreen pushes the onboarding flow FULLSCREEN one frame after the
    // shell appears; the opaque route puts MainScreen offstage and every
    // finder in this test stops matching.
    SharedPreferences.setMockInitialValues(
        <String, Object>{OnboardingScreen.seenPrefsKey: true});

    await app.main();
    await tester.pump(const Duration(seconds: 1));

    // Fresh install boots to the sign-in screen; a persisted session skips it.
    await pumpUntil(
      tester,
      () =>
          tester.any(find.byType(SignInScreen)) ||
          tester.any(find.byType(BottomNavigationBar)),
      description: 'sign-in screen or main shell',
    );

    // Always start from a fresh sign-in. A session persisted from a previous
    // run dies seconds into the test: its rotated refresh token was already
    // used, so GoTrue's reuse detection revokes the session mid-flight and
    // the auth gate silently swaps MainScreen back to SignInScreen.
    // Diagnostic: trace every auth event with expiry vs device clock.
    Supabase.instance.client.auth.onAuthStateChange.listen((s) {
      final exp = s.session?.expiresAt;
      debugPrint('SMOKE-AUTH: ${s.event} expiresAt=$exp '
          'now=${DateTime.now().millisecondsSinceEpoch ~/ 1000}');
    });

    final auth = tester
        .element(find.byType(MaterialApp))
        .read<IAuthService>();
    if (auth.isSignedIn) {
      await auth.signOut();
      await pumpUntil(
        tester,
        () => tester.any(find.byType(SignInScreen)),
        description: 'sign-in screen after forced sign-out',
      );
    }

    if (tester.any(find.byType(SignInScreen))) {
      await tester.enterText(
        find.descendant(
          of: find.byType(AuthEmailField),
          matching: find.byType(TextField),
        ),
        _email,
      );
      await tester.enterText(
        find.descendant(
          of: find.byType(AuthPasswordField),
          matching: find.byType(TextField),
        ),
        _password,
      );
      await tester.tap(find.byType(FilledButton));
      // Auth roundtrip + shell build.
      await pumpUntil(
        tester,
        () => tester.any(find.byType(BottomNavigationBar)),
        description: 'main shell after sign-in',
      );
    }

    // Switch to the chat tab via TabNavigator — tapping the nav-bar icon is
    // flaky (IndexedStack keeps inactive tabs offstage, and a missed tap
    // strands the test on the home tab).
    tester
        .element(find.byType(MainScreen))
        .read<TabNavigator>()
        .goTo(AppTabs.chat);
    await tester.pump(const Duration(milliseconds: 500));

    // The composer renders before /chats/start returns — poll the state, not
    // the widget tree, to know when the chat has actually started.
    await pumpUntil(
      tester,
      () => tester.any(find.byType(ChatScreen)),
      description: 'chat screen mounted',
    );
    final chatState = tester.element(find.byType(ChatScreen)).read<ChatState>();
    await pumpUntil(
      tester,
      () => chatState.chatId != null || chatState.errorMessage != null,
      description: 'chat to start via /chats/start',
    );
    expect(chatState.errorMessage, isNull,
        reason: 'no error banner after chat start');
    expect(chatState.chatId, isNotNull, reason: 'chat should have started');
    final messagesBefore = chatState.messages.length;

    // Let the post-start rebuild land before poking the composer.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    final composerField = find.descendant(
      of: find.byType(ChatScreen),
      matching: find.byType(TextField),
    );
    debugPrint('SMOKE: composer fields=${tester.widgetList(composerField).length} '
        'stage=${chatState.stage} isDone=${chatState.isDone} '
        'sending=${chatState.sending} messages=${chatState.messages.length}');
    await pumpUntil(
      tester,
      () => tester.any(composerField),
      description: 'text composer to appear (stage=${chatState.stage})',
    );

    await tester.enterText(
      composerField,
      'I keep dreaming about being chased through my old school.',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(ChatScreen),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));

    // Real LLM turn: user message + streamed assistant reply.
    await pumpUntil(
      tester,
      () =>
          !chatState.awaitingReply &&
          chatState.messages.length >= messagesBefore + 2,
      description: 'assistant reply to arrive (live AI turn)',
      timeout: const Duration(seconds: 120),
    );

    expect(chatState.errorMessage, isNull,
        reason: 'turn must complete without error banner');
    expect(chatState.messages.last.isUser, isFalse,
        reason: 'last message should be the AI reply');
    expect(chatState.messages.last.content.trim(), isNotEmpty);

    // Give the UI a beat, then leave it visible for the screenshot.
    await tester.pump(const Duration(seconds: 1));
  });
}
