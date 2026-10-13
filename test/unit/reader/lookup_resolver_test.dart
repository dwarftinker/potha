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
      expect(r.sections.first.entry.headword, 'example');
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

  group('inflections, capitals and hyphens (US2)', () {
    final lexicon = MapLexicon(
      {
        'mouse': [e('mouse', 'noun', 'A small rodent.')],
        'better': [e('better', 'adj'), e('better', 'noun')],
        'good': [e('good', 'adj')],
        'well': [e('well', 'adv'), e('well', 'noun')],
        'building': [e('building', 'noun')],
        'build': [e('build', 'verb')],
        'study': [e('study', 'verb'), e('study', 'noun')],
        'turkey': [e('turkey', 'noun', 'A bird.'), e('Turkey', 'name', 'A country.')],
        'known': [e('known', 'adj')],
        'example': [e('example', 'noun')],
        'exam-ple': [e('exam-ple', 'noun')],
      },
      {
        'mice': [const WordFormLink('mice', 'mouse', FormRelation.plural)],
        'better': [
          const WordFormLink('better', 'good', FormRelation.comparative),
          const WordFormLink('better', 'well', FormRelation.comparative),
        ],
        'building': [const WordFormLink('building', 'build', FormRelation.form)],
        'studied': [const WordFormLink('studied', 'study', FormRelation.past)],
      },
    );
    final resolver = LookupResolver(lexicon);

    List<(String, String?)> shown(LookupResult r) => [
      for (final s in r.sections) (s.entry.headword, s.note),
    ];

    test('mice -> mouse with "mice – plural of mouse"', () async {
      final r = await resolver.resolve(q(['mice']));
      expect(shown(r), [('mouse', 'mice – plural of mouse')]);
    });

    test("better -> its own entries first, then good and well", () async {
      final r = await resolver.resolve(q(['better']));
      expect(shown(r), [
        ('better', null),
        ('better', null),
        ('good', 'better – comparative of good'),
        ('well', 'better – comparative of well'),
        ('well', null),
      ]);
    });

    test('building -> the noun first, then build', () async {
      final r = await resolver.resolve(q(['building']));
      expect(shown(r), [('building', null), ('build', 'building – form of build')]);
    });

    test('studied -> study via forms; the display word is used in the note', () async {
      final r = await resolver.resolve(q(['studied'], display: 'Studied'));
      expect(r.sections.first.note, 'Studied – past tense of study');
      expect(r.sections.map((s) => s.entry.pos), ['verb', 'noun']);
    });

    test('studies -> study via the rules when the forms are missing', () async {
      final r = await resolver.resolve(q(['studies']));
      expect(shown(r).first, ('study', 'studies – form of study'));
    });

    test('Turkey mid-sentence: proper noun first; otherwise common first (FR-010)', () async {
      final mid = await resolver.resolve(
        const LookupQuery(candidates: ['turkey'], display: 'Turkey', capitalisedMidSentence: true),
      );
      expect(mid.sections.map((s) => s.entry.pos), ['name', 'noun']);
      final start = await resolver.resolve(q(['turkey'], display: 'Turkey'));
      expect(start.sections.map((s) => s.entry.pos), ['noun', 'name']);
    });

    test('a hyphenated word without an entry shows its parts as sections (FR-009)', () async {
      final r = await resolver.resolve(q(['well-known'], parts: ['well', 'known']));
      expect(shown(r).map((s) => s.$1), ['well', 'well', 'known']);
    });

    test('a line-break word: the joined spelling first, then the hyphenated one', () async {
      final r = await resolver.resolve(q(['example', 'exam-ple'], parts: ['exam', 'ple']));
      expect(shown(r), [('example', null), ('exam-ple', null)]);
      final only = await resolver.resolve(q(['wellknown', 'well-known'], parts: ['well', 'known']));
      expect(shown(only).map((s) => s.$1), [
        'well',
        'well',
        'known',
      ], reason: 'neither spelling: the parts');
    });

    test('no entry and no base -> notFound', () async {
      final r = await resolver.resolve(q(['zorblaxes']));
      expect(r.found, isFalse);
    });
  });

  group('phrases (US5)', () {
    final lexicon = MapLexicon({
      'give up': [e('give up', 'verb', 'To stop trying.')],
      'in spite of': [e('in spite of', 'prep', 'Despite.')],
      'give': [e('give', 'verb', 'To hand over.')],
    });
    final resolver = LookupResolver(lexicon);

    LookupQuery phrase(String key, String first) => LookupQuery(
      candidates: [key],
      display: key,
      isPhrase: true,
      firstWord: LookupQuery(candidates: [first], display: first),
    );

    test('a phrase with an entry shows it', () async {
      final r = await resolver.resolve(phrase('give up', 'give'));
      expect(r.sections.single.entry.headword, 'give up');
      expect(r.phraseNotFound, isNull);
      expect((await resolver.resolve(phrase('in spite of', 'in'))).headword, 'in spite of');
    });

    test('an unknown phrase shows the first word under "phraseNotFound" (FR-019)', () async {
      final r = await resolver.resolve(phrase('give over there', 'give'));
      expect(r.phraseNotFound, 'give over there');
      expect(r.sections.single.entry.headword, 'give');
    });

    test('an unknown phrase whose first word is unknown too is not found', () async {
      final r = await resolver.resolve(phrase('zorb blax', 'zorb'));
      expect(r.found, isFalse);
      expect(r.phraseNotFound, 'zorb blax');
    });
  });
}
