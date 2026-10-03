import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/app.dart';
import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/core/app_services.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/env.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/reminders/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  final store = await LocalStore.open();
  final auth = SupabaseAuthService(Supabase.instance.client);
  final settings = AppSettings(
    store,
    platformLanguage: PlatformDispatcher.instance.locale.languageCode,
  );
  final notifications = NotificationService();
  await notifications.initialize();

  final services = AppServices(
    api: ApiClient(
      baseUrl: Env.apiBaseUrl,
      tokenProvider: () => auth.accessToken,
      refreshSession: auth.refreshSession,
    ),
    store: store,
    notifications: notifications,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        Provider<AppServices>.value(value: services),
      ],
      child: const ReDreamApp(),
    ),
  );
}
