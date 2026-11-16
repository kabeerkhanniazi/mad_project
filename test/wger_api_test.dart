import 'dart:convert';
import 'dart:io';

import 'package:fithabit/data/local_store.dart';
import 'package:fithabit/data/wger_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A response saved from the live API, trimmed to three results. The third
/// has no English translation.
final fixture = File('test/fixtures/wger_exerciseinfo.json').readAsStringSync();

void main() {
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance());
  });

  http.Response ok(String body) => http.Response.bytes(utf8.encode(body), 200,
      headers: {'content-type': 'application/json'});

  test('parses a real exerciseinfo response', () async {
    final api = WgerApi(MockClient((_) async => ok(fixture)), store);
    final page = await api.fetchExercises(const ExerciseQuery());

    expect(page.hasMore, isTrue);
    expect(page.fromCache, isFalse);
    // The result without an English name is skipped.
    expect(page.items.map((e) => e.name), ['Bench Press', 'Bench Press (Custom)']);

    final bench = page.items.first;
    expect(bench.id, 73);
    expect(bench.category, 'Chest');
    expect(bench.equipment, ['Barbell', 'Bench']);
    expect(bench.muscles, isNotEmpty);
    expect(bench.imageUrl, startsWith('https://wger.de/media/'));
    expect(bench.license, contains('CC-BY-SA'));
    expect(bench.description, startsWith('Lay down on a bench'));
    expect(bench.description, isNot(contains('<')));
    expect(bench.sourceUrl, 'https://wger.de/en/exercise/73/view/');
  });

  test('sends search and filters as query parameters', () async {
    late Uri requested;
    final api = WgerApi(MockClient((request) async {
      requested = request.url;
      return ok(fixture);
    }), store);
    await api.fetchExercises(
      const ExerciseQuery(search: ' squat ', categoryId: 9, equipmentId: 3),
      offset: 20,
    );
    expect(requested.host, 'wger.de');
    expect(requested.path, '/api/v2/exerciseinfo/');
    expect(requested.queryParameters, {
      'limit': '20',
      'offset': '20',
      'language__code': 'en',
      'name__search': 'squat',
      'category': '9',
      'equipment': '3',
    });
  });

  test('falls back to the cached page when the network fails', () async {
    var online = true;
    final api = WgerApi(MockClient((_) async {
      if (!online) throw const SocketException('offline');
      return ok(fixture);
    }), store);

    await api.fetchExercises(const ExerciseQuery(search: 'bench'));
    online = false;
    final cached = await api.fetchExercises(const ExerciseQuery(search: 'bench'));
    expect(cached.fromCache, isTrue);
    expect(cached.items, hasLength(2));

    // A search that was never loaded has nothing to fall back to.
    expect(
      () => api.fetchExercises(const ExerciseQuery(search: 'plank')),
      throwsA(isA<WgerException>()),
    );
  });

  test('a server error is reported, not parsed', () async {
    final api = WgerApi(MockClient((_) async => http.Response('oops', 500)), store);
    expect(
      () => api.fetchExercises(const ExerciseQuery()),
      throwsA(isA<WgerException>()
          .having((e) => e.message, 'message', contains('500'))),
    );
  });

  test('htmlToText removes markup and scripts', () {
    expect(
      WgerApi.htmlToText(
          '<p>Stand <em>tall</em> &amp; breathe.</p><ul><li>One</li><li>Two</li></ul>'
          '<script>alert(1)</script>'),
      'Stand tall & breathe.\n- One\n- Two',
    );
    expect(WgerApi.htmlToText(''), '');
  });

  test('bodyweight equipment gets a readable label', () {
    expect(WgerApi.equipmentLabel('none (bodyweight exercise)'), 'Bodyweight');
    expect(WgerApi.equipmentLabel('Dumbbell'), 'Dumbbell');
  });
}
