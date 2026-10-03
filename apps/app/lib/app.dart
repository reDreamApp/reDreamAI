import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/theme/app_theme.dart';
import 'package:redream_app/features/auth/sign_in_screen.dart';
import 'package:redream_app/features/consent/consent_screen.dart';
import 'package:redream_app/features/onboarding/onboarding_screen.dart';
import 'package:redream_app/features/shell/main_shell.dart';
import 'package:redream_app/features/shell/user_scope.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class ReDreamApp extends StatelessWidget {
  const ReDreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    return MaterialApp(
      title: 'reDreamAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}

/// Signed out → sign in. Signed in → per-user scope.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthService>().userId;
    if (userId == null) return const SignInScreen();
    return UserScope(
      key: ValueKey(userId),
      userId: userId,
      child: const UserHome(),
    );
  }
}

/// First screen inside the user scope: the Art. 9 consent gate, then
/// onboarding once after sign-up, otherwise the tabbed shell.
class UserHome extends StatelessWidget {
  const UserHome({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthService>().userId;
    final settings = context.watch<AppSettings>();
    final onboarding = userId != null && settings.needsOnboarding(userId);
    return ConsentGate(
      child: onboarding ? const OnboardingScreen() : const MainShell(),
    );
  }
}
