// From a query to the entries shown (003 research R5). Fake lexicon.
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/features/reader/domain/lookup_resolver.dart';
import 'package:potha/features/reader/domain/word_extractor.dart';

class MapLexicon implements Lexicon {
  MapLexicon(this.entryMap, [this.formMap = const {}]);

  final Map<String, List<DictionaryEntry>> entryMap;
  final Map<String, List<WordFormLink>> formMap;
  final asked = <String>[];

  @override
  String get language => 'en';
  @override
  DictionaryInfo get info => throw UnimplementedError();
  @override
  Future<List<DictionaryEntry>> entries(String key) async {
    asked.add(key);
    return entryMap[key] ?? const [];
  }

  @override
  Future<List<WordFormLink>> formsOf(String key) async => formMap[key] ?? const [];
  @override
  Future<bool> hasEntry(String key) async => entryMap.containsKey(key);
}

DictionaryEntry e(String headword, String pos, [String gloss = 'a meaning']) =>
    DictionaryEntry(headword: headword, pos: pos, senses: [Sense(gloss)]);

LookupQuery q(List<String> candidates, {String? display, List<String> parts = const []}) =>
    LookupQuery(candidates: candidates, display: display ?? candidates.first, parts: parts);

void main() {
  group('exact entries (US1)', () {
    test('an exact entry is returned, all its parts of speech in dictionary order', () async {
      final lexicon = MapLexicon({
        'melancholy': [e('melancholy', 'noun'), e('melancholy', 'adj')],
      });
      final r = await LookupResolver(lexicon).resolve(q(['melancholy']));
      expect(r.found, isTrue);
      expect(r.sections.map((s) => (s.entry.headword, s.entry.pos, s.note)), [
        ('melancholy', 'noun', null),
        ('melancholy', 'adj', null),
      ]);
      expect(r.source, EntrySource.offline);
    });

    test('candidates are tried in order: the joined line-break word wins', () async {
      final lexicon = MapLexicon({
        'example': [e('example', 'noun')],
        'exam-ple': [e('exam-ple', 'noun')],
      });
      final r = await LookupResolver(lexicon).resolve(q(['example', 'exam-ple']));
      expect(r.sections.single.entry.headword, 'example');
    });

    test('the next candidate is used when the first has no entry', () async {
      final lexicon = MapLexicon({
        'well-known': [e('well-known', 'adj')],
      });
      final r = await LookupResolver(lexicon).resolve(q(['wellknown', 'well-known']));
      expect(r.sections.single.entry.headword, 'well-known');
      expect(lexicon.asked, ['wellknown', 'well-known']);
    });

    test('no entry gives notFound with the query kept', () async {
      final query = q(['zorblax'], display: 'Zorblax');
      final r = await LookupResolver(MapLexicon({})).resolve(query);
      expect(r.found, isFalse);
      expect(r.sections, isEmpty);
      expect(r.query, same(query));
    });

    test('garbled text is not looked up', () async {
      final lexicon = MapLexicon({});
      final r = await LookupResolver(lexicon)
          .resolve(const LookupQuery(candidates: [], display: '\u0001\u0002', garbled: true));
      expect(r.found, isFalse);
      expect(lexicon.asked, isEmpty);
    });
  });
}
