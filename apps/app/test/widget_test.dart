import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/features/auth/sign_in_screen.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class _FakeAuth implements IAuthService {
  @override
  String? get accessToken => null;
  @override
  bool get isSignedIn => false;
  @override
  String? get userEmail => null;
  @override
  Stream<bool> get authChanges => const Stream.empty();
  @override
  Future<void> signIn({required String email, required String password}) async {}
  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets('sign-in screen renders localized title + fields', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<IAuthService>.value(value: _FakeAuth()),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
