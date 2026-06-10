import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/auth/auth_service.dart';
import 'core/env.dart';
import 'features/chat/chat_service.dart';
import 'features/chat/chat_state.dart';

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SupabaseAuthService>.value(value: authService),
        Provider<IAuthService>.value(value: authService),
        Provider<ApiClient>.value(value: apiClient),
        Provider<IChatService>.value(value: chatService),
        ChangeNotifierProvider<ChatState>(create: (_) => ChatState(chatService)),
      ],
      child: const ReDreamApp(),
    ),
  );
}
