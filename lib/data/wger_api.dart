/// Client for the wger exercise database, the project's REST API.
///
/// Docs: https://wger.readthedocs.io/en/latest/api/api.html
/// No API key is needed for reading exercises.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/models.dart';
import 'local_store.dart';

class ExerciseQuery {
  const ExerciseQuery({this.search = '', this.categoryId, this.equipmentId});

  final String search;
  final int? categoryId;
  final int? equipmentId;

  ExerciseQuery copyWith({String? search}) => ExerciseQuery(
        search: search ?? this.search,
        categoryId: categoryId,
        equipmentId: equipmentId,
      );

  ExerciseQuery withCategory(int? id) =>
      ExerciseQuery(search: search, categoryId: id, equipmentId: equipmentId);

  ExerciseQuery withEquipment(int? id) =>
      ExerciseQuery(search: search, categoryId: categoryId, equipmentId: id);

  @override
  bool operator ==(Object other) =>
      other is ExerciseQuery &&
      other.search == search &&
      other.categoryId == categoryId &&
      other.equipmentId == equipmentId;

  @override
  int get hashCode => Object.hash(search, categoryId, equipmentId);
}

class ExercisePage {
  const ExercisePage({
    required this.items,
    required this.hasMore,
    this.fromCache = false,
  });

  final List<Exercise> items;
  final bool hasMore;

  /// True when the network failed and a saved copy is shown instead.
  final bool fromCache;
}

/// A category or equipment option used in the catalogue filters.
class WgerOption {
  const WgerOption(this.id, this.name);
  final int id;
  final String name;
}

class WgerException implements Exception {
  const WgerException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WgerApi {
  WgerApi(this._client, this._store);

  final http.Client _client;
  final LocalStore _store;

  static const _host = 'wger.de';
  static const pageSize = 20;
  static const _englishLanguageId = 2;
  static const _timeout = Duration(seconds: 12);

  /// One page of exercises. Falls back to the cached copy of the same page
  /// when the request fails; throws [WgerException] when there is none.
  Future<ExercisePage> fetchExercises(ExerciseQuery query,
      {int offset = 0}) async {
    final params = <String, String>{
      'limit': '$pageSize',
      'offset': '$offset',
      'language__code': 'en',
      if (query.search.trim().isNotEmpty) 'name__search': query.search.trim(),
      if (query.categoryId != null) 'category': '${query.categoryId}',
      if (query.equipmentId != null) 'equipment': '${query.equipmentId}',
    };
    final uri = Uri.https(_host, '/api/v2/exerciseinfo/', params);
    final body = await _getWithCache(uri);
    final json = jsonDecode(body.text) as Map<String, dynamic>;
    return ExercisePage(
      items: [
        for (final r in json['results'] as List)
          ?parseExercise(r as Map<String, dynamic>),
      ],
      hasMore: json['next'] != null,
      fromCache: body.fromCache,
    );
  }

  Future<List<WgerOption>> fetchCategories() =>
      _fetchOptions('/api/v2/exercisecategory/');

  Future<List<WgerOption>> fetchEquipment() =>
      _fetchOptions('/api/v2/equipment/');

  Future<List<WgerOption>> _fetchOptions(String path) async {
    final body = await _getWithCache(Uri.https(_host, path, {'limit': '100'}));
    final json = jsonDecode(body.text) as Map<String, dynamic>;
    return [
      for (final r in json['results'] as List)
        WgerOption((r['id'] as num).toInt(), r['name'] as String? ?? ''),
    ];
  }

  Future<({String text, bool fromCache})> _getWithCache(Uri uri) async {
    final key = uri.toString();
    try {
      final response = await _client.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(_timeout);
      if (response.statusCode != 200) {
        throw WgerException('The exercise service answered '
            'with an error (${response.statusCode}).');
      }
      final text = utf8.decode(response.bodyBytes);
      unawaited(_store.cachePut(key, text));
      return (text: text, fromCache: false);
    } catch (e) {
      final cached = _store.cacheGet(key);
      if (cached != null) return (text: cached, fromCache: true);
      if (e is WgerException) rethrow;
      throw const WgerException(
          'Could not reach the exercise catalogue. Check your connection.');
    }
  }

  /// Converts one `exerciseinfo` result. Returns null when the exercise has
  /// no English name, so the list never shows a blank row.
  static Exercise? parseExercise(Map<String, dynamic> json) {
    final translations = (json['translations'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    Map<String, dynamic>? english;
    for (final t in translations) {
      if (t['language'] == _englishLanguageId) {
        english = t;
        break;
      }
    }
    final name = (english?['name'] as String? ?? '').trim();
    if (english == null || name.isEmpty) return null;

    final images =
        (json['images'] as List? ?? const []).cast<Map<String, dynamic>>();
    String? imageUrl;
    for (final image in images) {
      imageUrl ??= image['image'] as String?;
      if (image['is_main'] == true) {
        imageUrl = image['image'] as String?;
        break;
      }
    }

    String muscleName(Map<String, dynamic> m) {
      final plain = m['name_en'] as String? ?? '';
      return plain.isNotEmpty ? plain : m['name'] as String? ?? '';
    }

    final license = json['license'] as Map<String, dynamic>?;
    return Exercise(
      id: (json['id'] as num).toInt(),
      name: name,
      category: (json['category'] as Map?)?['name'] as String? ?? '',
      muscles: [
        for (final m in (json['muscles'] as List? ?? const []))
          muscleName(m as Map<String, dynamic>),
      ],
      equipment: [
        for (final e in (json['equipment'] as List? ?? const []))
          equipmentLabel((e as Map)['name'] as String? ?? ''),
      ],
      description: htmlToText(english['description'] as String? ?? ''),
      imageUrl: imageUrl,
      license: (license?['short_name'] as String? ?? '').trim(),
      licenseUrl: license?['url'] as String? ?? '',
      author: (json['license_author'] as String? ?? '').trim(),
    );
  }

  /// wger names the bodyweight option "none (bodyweight exercise)".
  static String equipmentLabel(String name) =>
      name.startsWith('none') ? 'Bodyweight' : name;

  /// Reduces API-provided HTML to plain text, so no markup or script from
  /// the network is ever rendered.
  static String htmlToText(String html) {
    var text = html
        .replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>',
            caseSensitive: false), '')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '\n- ')
        .replaceAll(
            RegExp(r'<br\s*/?>|</p>|</li>|</ul>|</ol>|</h\d>',
                caseSensitive: false),
            '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
    };
    entities.forEach((k, v) => text = text.replaceAll(k, v));
    return text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l != '-')
        .join('\n');
  }
}
