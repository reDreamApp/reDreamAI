import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/core/storage/local_store.dart';
import 'package:redream_app/features/journal/dream.dart';
import 'package:redream_app/features/journal/dream_service.dart';
import 'package:redream_app/features/journal/dream_store.dart';
import 'package:redream_app/features/journal/journal_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_api.dart';

const _input = DreamInput(
  title: 'Falling',
  originalDream: 'I fell.',
  rewrittenDream: 'I landed softly.',
  intensity: 6,
  isNightmare: true,
);

Future<(JournalState, FakeApi)> _setup({
  List<Map<String, dynamic>>? dreams,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  final store = await LocalStore.open();
  final serverDreams =
      dreams ??
      [
        dreamJson(1, current: true),
        dreamJson(2, nightmare: false, rewritten: null, intensity: null),
      ];
  var nextId = 100;
  final api = FakeApi()
    ..on('GET /api/v1/dreams', (_, _) => serverDreams)
    ..on('POST /api/v1/dreams', (_, body) {
      final json = dreamJson(nextId++, title: body['title'] as String);
      serverDreams.add(json);
      return json;
    })
    ..on(
      'PUT /api/v1/dreams/{id}',
      (req, body) => dreamJson(
        int.parse(req.url.pathSegments.last),
        title: body['title'] as String,
      ),
    )
    ..on(
      'PATCH /api/v1/dreams/{id}/favorite',
      (req, _) => dreamJson(
        int.parse(req.url.pathSegments[3]),
        current: true,
      ),
    )
    ..on(
      'POST /api/v1/dreams/{id}/practice',
      (req, _) => dreamJson(
        int.parse(req.url.pathSegments[3]),
        practices: [DateTime.now().toUtc().toIso8601String()],
      ),
    )
    ..on('DELETE /api/v1/dreams/{id}', (_, _) => null);
  final state = JournalState(
    DreamService(api.client()),
    DreamStore(store, 'user-1'),
  );
  return (state, api);
}

void main() {
  test('loads, sorts focus dream first and caches for offline use', () async {
    final (state, api) = await _setup();
    await state.load();

    expect(state.dreams.map((d) => d.id), [1, 2]);
    expect(state.focusDream?.id, 1);
    expect(state.nightmares.length, 1);
    expect(state.usedCache, isFalse);

    api.offline = true;
    final offline = JournalState(
      DreamService(api.client()),
      DreamStore(await LocalStore.open(), 'user-1'),
    );
    await offline.refresh();
    expect(offline.usedCache, isTrue);
    expect(offline.dreams.length, 2);
  });

  test(
    'create while offline saves a draft and syncs when back online',
    () async {
      final (state, api) = await _setup();
      await state.load();

      api.offline = true;
      final result = await state.create(_input);
      expect(result.savedOffline, isTrue);
      expect(result.dream.isLocal, isTrue);
      expect(state.hasUnsynced, isTrue);
      expect(
        state.dreams.where((d) => d.title == 'Falling').single.isLocal,
        isTrue,
      );

      api.offline = false;
      await state.refresh();
      expect(state.hasUnsynced, isFalse);
      expect(api.calls, contains('POST /api/v1/dreams'));
      expect(
        state.dreams.where((d) => d.title == 'Falling').single.isLocal,
        isFalse,
      );
    },
  );

  test(
    'records at most one practice per day and queues offline practices',
    () async {
      final (state, api) = await _setup();
      await state.load();
      final dream = state.byId(1)!;

      final first = await state.recordPractice(dream);
      expect(first.alreadyToday, isFalse);
      expect(first.dream.practiceCount, 1);

      final second = await state.recordPractice(state.byId(1)!);
      expect(second.alreadyToday, isTrue);

      api.offline = true;
      final fresh = await _setup(dreams: [dreamJson(3)]);
      await fresh.$1.load();
      fresh.$2.offline = true;
      final queued = await fresh.$1.recordPractice(fresh.$1.byId(3)!);
      expect(queued.savedOffline, isTrue);
      expect(fresh.$1.hasUnsynced, isTrue);
      expect(fresh.$1.practicesThisWeek, 1);
    },
  );

  test('setFocus is optimistic and rolls back on failure', () async {
    final (state, api) = await _setup(
      dreams: [dreamJson(1, current: true), dreamJson(2)],
    );
    await state.load();
    api.on(
      'PATCH /api/v1/dreams/{id}/favorite',
      (_, _) => throw FakeApiError(500, 'boom'),
    );

    await expectLater(state.setFocus(state.byId(2)!), throwsA(anything));
    expect(state.focusDream?.id, 1);
  });

  test('delete removes server dreams and local drafts', () async {
    final (state, api) = await _setup();
    await state.load();
    await state.delete(state.byId(2)!);
    expect(state.dreams.map((d) => d.id), [1]);

    api.offline = true;
    final draft = (await state.create(_input)).dream;
    await state.delete(draft);
    expect(state.hasUnsynced, isFalse);
  });
}
