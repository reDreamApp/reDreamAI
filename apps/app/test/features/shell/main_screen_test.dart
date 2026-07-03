import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:redream_app/core/api/api_client.dart';
import 'package:redream_app/core/auth/auth_service.dart';
import 'package:redream_app/core/language/language_provider.dart';
import 'package:redream_app/core/models/dream.dart';
import 'package:redream_app/core/services/dream_service.dart';
import 'package:redream_app/core/theme/theme_provider.dart';
import 'package:redream_app/features/chat/chat_models.dart';
import 'package:redream_app/features/chat/chat_service.dart';
import 'package:redream_app/features/chat/chat_state.dart';
import 'package:redream_app/features/collection/collection_state.dart';
import 'package:redream_app/features/shell/main_screen.dart';
import 'package:redream_app/features/shell/tab_navigator.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';

class _FakeAuth extends ChangeNotifier implements IAuthService {
  @override
  String? get accessToken => 'token';
  @override
  bool get isSignedIn => true;
  @override
  String? get userEmail => 'test@example.com';
  @override
  Stream<bool> get authChanges => const Stream.empty();
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> updateEmail(String newEmail) async {}
  @override
  Future<void> updatePassword(String newPassword) async {}
  @override
  Future<void> signOut() async {}
}

class _FakeChatService implements IChatService {
  @override
  Future<ChatStart> start({required String language}) async => ChatStart(
    chatId: 1,
    language: language,
    currentStage: IrtStage.recording,
  );
  @override
  Future<List<ChatSummary>> listChats() async => [];
  @override
  Future<List<ChatMessage>> listMessages(int chatId) async => [];
  @override
  Future<ChatTurn> sendMessage({required int chatId, required String content}) {
    throw UnimplementedError();
  }

  @override
  Stream<ChatStreamEvent> sendMessageStream({
    required int chatId,
    required String content,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteChat(int chatId) async {}
}

class _FakeDreamService implements IDreamService {
  @override
  Future<List<Dream>> list() async => [];
  @override
  Future<Dream> getById(int id) => throw UnimplementedError();
  @override
  Future<Dream> create({
    required String title,
    required String originalDream,
    String? rewrittenDream,
    int? intensity,
    bool isNightmare = false,
  }) => throw UnimplementedError();
  @override
  Future<Dream> update(int id, Map<String, dynamic> fields) =>
      throw UnimplementedError();
  @override
  Future<void> delete(int id) async {}
  @override
  Future<Dream> setCurrent(int id) => throw UnimplementedError();
  @override
  Future<Dream> recordPractice(int id) => throw UnimplementedError();
  @override
  Future<Dream> generateRehearsal(int id, {required String language}) =>
      throw UnimplementedError();
}

void main() {
  testWidgets('MainScreen mounts and all five tabs render without exceptions', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    final chatService = _FakeChatService();
    final dreamService = _FakeDreamService();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ListenableProvider<IAuthService>(create: (_) => _FakeAuth()),
          Provider<ApiClient>.value(
            value: ApiClient(baseUrl: 'http://test', tokenProvider: () => null),
          ),
          Provider<IChatService>.value(value: chatService),
          Provider<IDreamService>.value(value: dreamService),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(),
          ),
          ChangeNotifierProvider<TabNavigator>(create: (_) => TabNavigator()),
          ChangeNotifierProvider<ChatState>(
            create: (_) => ChatState(chatService),
          ),
          ChangeNotifierProvider<DreamCollectionState>(
            create: (_) => DreamCollectionState(dreamService),
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    for (final tab in [
      AppTabs.chat,
      AppTabs.collection,
      AppTabs.record,
      AppTabs.learn,
      AppTabs.home,
    ]) {
      tester
          .element(find.byType(BottomNavigationBar))
          .read<TabNavigator>()
          .goTo(tab);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'tab $tab threw');
    }
  });
}
