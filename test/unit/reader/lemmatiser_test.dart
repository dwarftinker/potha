// The rule fallback for regular forms missing from the dictionary's form data
// (003 research R5). Only bases that exist as entries are kept.
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/lexicon.dart';
import 'package:potha/features/reader/domain/lemmatiser.dart';

class Words implements Lexicon {
  Words(this.words);
  final Set<String> words;

  @override
  String get language => 'en';
  @override
  DictionaryInfo get info => throw UnimplementedError();
  @override
  Future<List<DictionaryEntry>> entries(String key) async => const [];
  @override
  Future<List<WordFormLink>> formsOf(String key) async => const [];
  @override
  Future<bool> hasEntry(String key) async => words.contains(key);
}

void main() {
  final lexicon = Words({
    'study',
    'stop',
    'run',
    'make',
    'box',
    'happy',
    'big',
    'large',
    'bake',
    'walk',
    'cat',
    'go',
    'mouse',
    'dog',
  });
  final lemmatiser = Lemmatiser(lexicon);

  Future<List<(String, FormRelation)>> bases(String word) async => [
    for (final l in await lemmatiser.basesOf(word)) (l.base, l.relation),
  ];

  test('regular forms give their base and relation', () async {
    expect(await bases('studies'), [('study', FormRelation.form)]);
    expect(await bases('studied'), [('study', FormRelation.past)]);
    expect(await bases('stopped'), [('stop', FormRelation.past)]);
    expect(await bases('running'), [('run', FormRelation.presentParticiple)]);
    expect(await bases('making'), [('make', FormRelation.presentParticiple)]);
    expect(await bases('boxes'), [('box', FormRelation.form)]);
    expect(await bases('happier'), [('happy', FormRelation.comparative)]);
    expect(await bases('biggest'), [('big', FormRelation.superlative)]);
    expect(await bases('larger'), [('large', FormRelation.comparative)]);
    expect(await bases('baked'), [('bake', FormRelation.past)]);
    expect(await bases('walks'), [('walk', FormRelation.form)]);
    expect(await bases('cats'), [('cat', FormRelation.form)]);
  });

  test('only bases that are entries are kept', () async {
    expect(await bases('zorblaxes'), isEmpty);
    expect(await bases('dogs'), [('dog', FormRelation.form)]);
    expect(await bases('happiness'), isEmpty);
  });

  test('irregular forms are not invented', () async {
    expect(await bases('mice'), isEmpty);
    expect(await bases('went'), isEmpty);
  });

  test('the form itself and very short stems are never bases', () async {
    expect(await bases('is'), isEmpty);
    expect(await bases('as'), isEmpty);
  });
}
