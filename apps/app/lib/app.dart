import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_service.dart';
import 'core/language/language_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/consent/consent_screen.dart';
import 'features/consent/consent_service.dart';
import 'features/consent/consent_state.dart';
import 'features/shell/main_screen.dart';
import 'l10n/generated/app_localizations.dart';

class ReDreamApp extends StatelessWidget {
  const ReDreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    return MaterialApp(
      title: 'reDreamAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeProvider.themeMode,
      locale: language.localeOverride,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<IAuthService>();
    if (!auth.isSignedIn) return const SignInScreen();
    // ConsentState is scoped to the signed-in subtree: signing out disposes
    // it, so the next sign-in fetches a fresh status for that account.
    return ChangeNotifierProvider<ConsentState>(
      create: (context) => ConsentState(context.read<IConsentService>()),
      child: const ConsentGate(child: MainScreen()),
    );
  }
}
