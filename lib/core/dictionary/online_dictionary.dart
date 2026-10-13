// "Search online" (003 US6, research R9): Wiktionary's definition service. Called only
// when the reader taps the button (FR-021, FR-032). Only the word is sent; the
// Api-User-Agent header names the app, as Wikimedia's policy asks, never the user.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'lexicon.dart';

const _endpoint = 'https://en.wiktionary.org/api/rest_v1/page/definition/';
const _agent = 'Potha/1.0 (https://github.com/dwarftinker/potha)';

class WikimediaDictionary implements OnlineDictionary {
  WikimediaDictionary({http.Client? client, this.timeout = const Duration(seconds: 8)})
    // ignore: prefer_initializing_formals (named parameters can't be private)
    : _client = client;

  /// Created on the first search, so nothing network-related exists before the reader
  /// asks (FR-032).
  http.Client? _client;
  final Duration timeout;

  @override
  Future<OnlineResult> lookUp(String word) async {
    // Wiktionary titles use underscores for spaces.
    final title = Uri.encodeComponent(word.trim().replaceAll(RegExp(r'\s+'), '_'));
    try {
      final response = await (_client ??= http.Client())
          .get(Uri.parse('$_endpoint$title'), headers: const {'Api-User-Agent': _agent})
          .timeout(timeout);
      if (response.statusCode == 404) return const OnlineNotFound();
      if (response.statusCode != 200) return OnlineFailed('HTTP ${response.statusCode}');
      final entries = parseWikimediaDefinitions(word, utf8.decode(response.bodyBytes));
      return entries.isEmpty ? const OnlineNotFound() : OnlineFound(entries);
    } catch (e) {
      return OnlineFailed(e);
    }
  }

  void close() => _client?.close();
}

/// The English section of a definition response (profile definition/0.8.x).
List<DictionaryEntry> parseWikimediaDefinitions(String word, String body) {
  final json = jsonDecode(body);
  if (json is! Map<String, dynamic>) return const [];
  final english = json['en'];
  if (english is! List) return const [];
  final out = <DictionaryEntry>[];
  for (final usage in english.whereType<Map<String, dynamic>>()) {
    final senses = <Sense>[];
    for (final d in (usage['definitions'] as List? ?? const []).whereType<Map<String, dynamic>>()) {
      final gloss = stripHtml(d['definition'] as String? ?? '');
      if (gloss.isEmpty) continue;
      final examples = [
        for (final x in (d['examples'] as List? ?? const []).whereType<String>()) stripHtml(x),
      ].where((x) => x.isNotEmpty).take(2).toList();
      senses.add(Sense(gloss, examples: examples));
    }
    if (senses.isEmpty) continue;
    out.add(
      DictionaryEntry(
        headword: word,
        pos: _pos(usage['partOfSpeech'] as String? ?? ''),
        senses: senses,
      ),
    );
  }
  return out;
}

/// Wikimedia's "Noun", "Proper noun", "Adjective" to the dictionary file's names.
String _pos(String name) => switch (name.toLowerCase()) {
  'adjective' => 'adj',
  'adverb' => 'adv',
  'proper noun' => 'name',
  'preposition' => 'prep',
  'interjection' => 'intj',
  'pronoun' => 'pron',
  'conjunction' => 'conj',
  'determiner' => 'det',
  final other => other.replaceAll(' ', '_'),
};

final _tag = RegExp(r'<[^>]*>');
final _entity = RegExp(r'&(#x?[0-9a-fA-F]+|[a-zA-Z]+);');

/// Plain text: tags removed (link text kept), entities decoded, spaces collapsed.
String stripHtml(String html) => html
    .replaceAll(_tag, '')
    .replaceAllMapped(_entity, (m) {
      final e = m[1]!;
      if (e.startsWith('#x')) return String.fromCharCode(int.parse(e.substring(2), radix: 16));
      if (e.startsWith('#')) return String.fromCharCode(int.parse(e.substring(1)));
      return switch (e) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        'nbsp' => ' ',
        _ => m[0]!,
      };
    })
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

final onlineDictionaryProvider = Provider<OnlineDictionary>((ref) {
  final online = WikimediaDictionary();
  ref.onDispose(online.close);
  return online;
});
