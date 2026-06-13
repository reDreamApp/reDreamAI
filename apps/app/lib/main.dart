import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_service.dart';
import 'core/env.dart';
import 'core/language/language_provider.dart';
import 'core/services/dream_service.dart';
import 'core/theme/theme_provider.dart';
import 'features/chat/chat_service.dart';
import 'features/chat/chat_state.dart';
import 'features/collection/collection_state.dart';
import 'features/shell/tab_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  final authService = SupabaseAuthService(Supabase.instance.client);
  final apiClient = ApiClient(
    baseUrl: Env.apiBaseUrl,
    tokenProvider: () => authService.accessToken,
  );
  final chatService = ChatService(apiClient);
  final dreamService = DreamService(apiClient);

  final themeProvider = ThemeProvider();
  final languageProvider = LanguageProvider();
  await themeProvider.loadFromPrefs();
  await languageProvider.loadFromPrefs();

  runApp(
    MultiProvider(
      providers: [
        ListenableProvider<IAuthService>.value(value: authService),
        Provider<ApiClient>.value(value: apiClient),
        Provider<IChatService>.value(value: chatService),
        Provider<IDreamService>.value(value: dreamService),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<LanguageProvider>.value(value: languageProvider),
        ChangeNotifierProvider<TabNavigator>(create: (_) => TabNavigator()),
        ChangeNotifierProvider<ChatState>(create: (_) => ChatState(chatService)),
        ChangeNotifierProvider<DreamCollectionState>(
          create: (_) => DreamCollectionState(dreamService),
        ),
      ],
      child: const ReDreamApp(),
    ),
  );
}
