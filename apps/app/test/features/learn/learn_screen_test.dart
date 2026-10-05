import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:redream_app/core/settings/app_settings.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/learn/article.dart';
import 'package:redream_app/features/learn/articles_service.dart';
import 'package:redream_app/features/learn/learn_screen.dart';
import 'package:redream_app/l10n/generated/app_localizations.dart';
import 'package:redream_app/l10n/generated/app_localizations_de.dart';
import 'package:redream_app/l10n/generated/app_localizations_en.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, Object> _post = {
  'slug': 'blog_creativity',
  'title': {
    'en': 'Dreams boost Creativity',
    'de': 'Träume fördern Kreativität',
  },
  'excerpt': {'en': 'How dreams solve problems.', 'de': 'Wie Träume helfen.'},
  'post_url': {
    'en': {'light': 'https://example.com/en', 'dark': 'https://example.com/en'},
  },
};

void main() {
  testWidgets('the team study comes first, then the website posts', (
    tester,
  ) async {
    // The service reads the website's address from the app's env file.
    dotenv.loadFromString(isOptional: true);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(
      await LocalStore.open(),
      platformLanguage: 'en',
    );
    final website = MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'posts': [_post],
          }),
        ),
        200,
      ),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: LearnScreen(service: ArticlesService(httpClient: website)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final study = find.text(
      'Our study: rewriting nightmares with a web application',
    );
    final post = find.text('Dreams boost Creativity');
    expect(study, findsOneWidget);
    expect(post, findsOneWidget);
    expect(tester.getTopLeft(study).dy, lessThan(tester.getTopLeft(post).dy));
  });

  test('the study links to the journal and keeps the not-therapy line', () {
    final en = Article.ownStudy(AppLocalizationsEn());
    final de = Article.ownStudy(AppLocalizationsDe());

    for (final brightness in Brightness.values) {
      expect(
        en.urlFor(brightness),
        'https://link.springer.com/article/10.1007/s11818-026-00550-w',
      );
    }
    expect(en.excerpt, contains('is not therapy'));
    expect(de.excerpt, contains('keine Therapie'));
  });
}
