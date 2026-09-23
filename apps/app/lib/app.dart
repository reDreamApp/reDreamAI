import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/chat/chat_screen.dart';
import 'l10n/generated/app_localizations.dart';

class ReDreamApp extends StatelessWidget {
  const ReDreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'reDreamAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
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
    return context.watch<AuthService>().isSignedIn
        ? const ChatScreen()
        : const SignInScreen();
  }
}
