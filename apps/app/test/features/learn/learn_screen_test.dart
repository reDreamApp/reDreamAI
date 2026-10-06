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
import 'package:redream_app/features/learn/article_screen.dart';
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

/// Learn with one website post; [opened] collects the links it opens.
Future<void> _pumpLearn(WidgetTester tester, {List<Uri>? opened}) async {
  // The service reads the website's address from the app's env file.
  dotenv.loadFromString(isOptional: true);
  SharedPreferences.setMockInitialValues({});
  final settings = AppSettings(await LocalStore.open(), platformLanguage: 'en');
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
        home: LearnScreen(
          service: ArticlesService(httpClient: website),
          openUrl: (url) async {
            opened?.add(url);
            return true;
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the team study comes first, then the website posts', (
    tester,
  ) async {
    await _pumpLearn(tester);

    final study = find.text(
      'Our study: rewriting nightmares with a web application',
    );
    final post = find.text('Dreams boost Creativity');
    expect(study, findsOneWidget);
    expect(post, findsOneWidget);
    expect(tester.getTopLeft(study).dy, lessThan(tester.getTopLeft(post).dy));
  });

  testWidgets('the button under an article opens it in the browser', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pumpLearn(tester, opened: opened);

    // One turquoise button per article, right on the list.
    final buttons = find.widgetWithText(FilledButton, 'Open the article');
    expect(buttons, findsNWidgets(2));
    await tester.tap(buttons.at(1));
    await tester.pumpAndSettle();
    await tester.tap(buttons.at(0));
    await tester.pumpAndSettle();

    expect(opened.map((u) => u.toString()), [
      'https://example.com/en',
      'https://link.springer.com/article/10.1007/s11818-026-00550-w',
    ]);
    // Still on the list: no page in between.
    expect(find.byType(ArticleScreen), findsNothing);
  });

  testWidgets('a card opens the article page with its picture and link', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pumpLearn(tester, opened: opened);

    await tester.tap(find.text('Dreams boost Creativity'));
    await tester.pumpAndSettle();

    expect(find.byType(ArticleScreen), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/images/learn_creativity.webp')),
      findsOneWidget,
    );
    expect(opened, isEmpty);
    await tester.tap(find.widgetWithText(FilledButton, 'Open the article'));
    await tester.pumpAndSettle();
    expect(opened.single.toString(), 'https://example.com/en');
  });

  test('the known articles have their pictures, others none', () {
    Article post(String slug) =>
        Article(slug: slug, title: 't', excerpt: '', urls: const {});

    expect(
      Article.ownStudy(AppLocalizationsEn()).image,
      'assets/images/learn_study.webp',
    );
    expect(
      post('blog_creativity').image,
      'assets/images/learn_creativity.webp',
    );
    expect(post('blog_sleep_better').image, 'assets/images/learn_sleep.webp');
    expect(post('blog_something_new').image, isNull);
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
