import 'package:flutter_test/flutter_test.dart';
import 'package:redream_app/core/api/api_exception.dart';

import 'fake_api.dart';

void main() {
  test('sends bearer token and decodes JSON objects and lists', () async {
    final api = FakeApi()
      ..on('GET /api/v1/one', (_, _) => {'a': 1})
      ..on('GET /api/v1/many', (_, _) => [1, 2]);
    final client = api.client(token: 't0k');

    expect(await client.get('/api/v1/one'), {'a': 1});
    expect(await client.getList('api/v1/many'), [1, 2]);
    expect(api.lastToken, 'Bearer t0k');
  });

  test('maps transport failures to NetworkException', () async {
    final client = FakeApi(offline: true).client();
    await expectLater(client.get('/x'), throwsA(isA<NetworkException>()));
  });

  test(
    'maps non-2xx to ApiException with FastAPI detail and Retry-After',
    () async {
      final api = FakeApi()
        ..on(
          'POST /api/v1/limited',
          (_, _) => throw FakeApiError(
            429,
            'budget exceeded',
            headers: {'retry-after': '120'},
          ),
        );
      try {
        await api.client().post('/api/v1/limited', {'x': 1});
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.isRateLimited, isTrue);
        expect(e.message, 'budget exceeded');
        expect(e.retryAfterSeconds, 120);
      }
    },
  );

  test('refreshes the session once on 401 and retries', () async {
    var attempts = 0;
    final api = FakeApi()
      ..on('GET /api/v1/me', (_, _) {
        attempts++;
        if (attempts == 1) throw FakeApiError(401, 'expired');
        return {'ok': true};
      });
    var refreshed = 0;
    final client = api.client(refreshSession: () async => refreshed++);

    expect(await client.get('/api/v1/me'), {'ok': true});
    expect(refreshed, 1);
    expect(attempts, 2);
  });

  test('delete tolerates empty 204 bodies', () async {
    final api = FakeApi()..on('DELETE /api/v1/thing/1', (_, _) => null);
    await api.client().delete('/api/v1/thing/1');
    expect(api.calls, ['DELETE /api/v1/thing/1']);
  });
}
