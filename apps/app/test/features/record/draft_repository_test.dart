import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/features/record/draft_models.dart';
import 'package:redream_app/features/record/draft_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

DreamDraft _draft(
  String id, {
  String title = 'A dream',
  String original = 'It happened',
  bool isNightmare = false,
  int? intensity,
  String? rewritten,
  DateTime? updatedAt,
}) {
  return DreamDraft(
    id: id,
    title: title,
    originalDream: original,
    rewrittenDream: rewritten,
    intensity: intensity,
    isNightmare: isNightmare,
    updatedAt: updatedAt ?? DateTime(2020),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late SharedPrefsDraftRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    repo = SharedPrefsDraftRepository(prefs: prefs);
  });

  test('starts empty', () async {
    expect(await repo.list(), isEmpty);
    expect(await repo.getById('missing'), isNull);
  });

  test('save inserts and round-trips fields', () async {
    final saved = await repo.save(
      _draft(
        '1',
        title: 'Nightmare',
        isNightmare: true,
        intensity: 7,
        rewritten: 'Better ending',
      ),
    );

    final fetched = await repo.getById('1');
    expect(fetched, isNotNull);
    expect(fetched!.title, 'Nightmare');
    expect(fetched.isNightmare, isTrue);
    expect(fetched.intensity, 7);
    expect(fetched.rewrittenDream, 'Better ending');
    // updatedAt is stamped on save, not taken from the input.
    expect(saved.updatedAt.isAfter(DateTime(2020)), isTrue);
  });

  test('save updates an existing draft instead of duplicating', () async {
    await repo.save(_draft('1', title: 'First'));
    await repo.save(_draft('1', title: 'Edited'));

    final all = await repo.list();
    expect(all, hasLength(1));
    expect(all.single.title, 'Edited');
  });

  test('list is sorted by updatedAt descending', () async {
    await repo.save(_draft('old', updatedAt: DateTime(2021)));
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await repo.save(_draft('new', updatedAt: DateTime(2022)));

    final all = await repo.list();
    expect(all.map((d) => d.id).toList(), <String>['new', 'old']);
  });

  test('delete removes only the matching draft', () async {
    await repo.save(_draft('1'));
    await repo.save(_draft('2'));

    await repo.delete('1');

    final all = await repo.list();
    expect(all.map((d) => d.id), <String>['2']);
  });

  test('clear removes everything', () async {
    await repo.save(_draft('1'));
    await repo.save(_draft('2'));

    await repo.clear();

    expect(await repo.list(), isEmpty);
  });

  test('tolerates corrupt stored json', () async {
    await prefs.setString(SharedPrefsDraftRepository.storageKey, 'not json');
    expect(await repo.list(), isEmpty);
  });
}
