// The rule fallback for regular English forms missing from the dictionary's form data
// (003 research R5). Irregular forms ("mice", "went") come only from the dictionary.
import '../../../core/dictionary/lexicon.dart';

class Lemmatiser {
  const Lemmatiser(this._lexicon);

  final Lexicon _lexicon;

  /// Bases of [key] by the rules, in rule order, kept only if they are entries.
  Future<List<WordFormLink>> basesOf(String key) async {
    final out = <WordFormLink>[];
    for (final (base, relation) in _guesses(key)) {
      if (base.length < 2 || base == key || out.any((l) => l.base == base)) continue;
      if (await _lexicon.hasEntry(base)) out.add(WordFormLink(key, base, relation));
    }
    return out;
  }

  static Iterable<(String, FormRelation)> _guesses(String w) sync* {
    if (w.length < 4) return;
    String cut(int n) => w.substring(0, w.length - n);
    // -ies, -es, -s: plural or third person; "form of" covers both.
    if (w.endsWith('ies')) yield ('${cut(3)}y', FormRelation.form);
    if (w.endsWith('es')) yield (cut(2), FormRelation.form);
    if (w.endsWith('s') && !w.endsWith('ss')) yield (cut(1), FormRelation.form);
    // -ied, -ed (stopped, baked).
    if (w.endsWith('ied')) yield ('${cut(3)}y', FormRelation.past);
    if (w.endsWith('ed')) {
      final stem = cut(2);
      if (_doubled(stem)) yield (stem.substring(0, stem.length - 1), FormRelation.past);
      yield (stem, FormRelation.past);
      yield ('${stem}e', FormRelation.past);
    }
    // -ing (running, making).
    if (w.endsWith('ing')) {
      final stem = cut(3);
      if (_doubled(stem)) {
        yield (stem.substring(0, stem.length - 1), FormRelation.presentParticiple);
      }
      yield (stem, FormRelation.presentParticiple);
      yield ('${stem}e', FormRelation.presentParticiple);
    }
    // -ier/-iest, -er/-est (happier, biggest, larger).
    for (final (suffix, relation) in [
      ('est', FormRelation.superlative),
      ('er', FormRelation.comparative),
    ]) {
      if (!w.endsWith(suffix)) continue;
      final stem = cut(suffix.length);
      if (stem.endsWith('i')) yield ('${stem.substring(0, stem.length - 1)}y', relation);
      if (_doubled(stem)) yield (stem.substring(0, stem.length - 1), relation);
      yield (stem, relation);
      yield ('${stem}e', relation);
    }
  }

  /// "stopp", "runn", "bigg": a doubled final consonant.
  static bool _doubled(String stem) =>
      stem.length >= 3 &&
      stem[stem.length - 1] == stem[stem.length - 2] &&
      !'aeiou'.contains(stem[stem.length - 1]);
}
