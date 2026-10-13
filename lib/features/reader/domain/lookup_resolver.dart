// From a query to the entries shown, in order (003 research R5). Pure Dart over Lexicon.
import 'package:flutter/foundation.dart';

import '../../../core/dictionary/lexicon.dart';
import 'lemmatiser.dart';
import 'word_extractor.dart';

/// Where the entries shown came from.
enum EntrySource { offline, online }

/// One entry in the panel, with a note when it is reached through another word
/// ("running – form of run").
@immutable
class ResultSection {
  const ResultSection(this.entry, {this.note});

  final DictionaryEntry entry;
  final String? note;
}

@immutable
class LookupResult {
  const LookupResult(
    this.query, {
    this.sections = const [],
    this.phraseNotFound,
    this.source = EntrySource.offline,
  });

  final LookupQuery query;

  /// Empty when nothing was found.
  final List<ResultSection> sections;

  /// A phrase without an entry: the phrase, shown above the first word's entries (FR-019).
  final String? phraseNotFound;
  final EntrySource source;

  bool get found => sections.isNotEmpty;

  /// The first headword shown, for history; null if not found.
  String? get headword => found ? sections.first.entry.headword : null;
}

/// "running – form of run" (data-model.md).
String formNote(String display, FormRelation relation, String base) {
  final how = switch (relation) {
    FormRelation.plural => 'plural of',
    FormRelation.past => 'past tense of',
    FormRelation.pastParticiple => 'past participle of',
    FormRelation.presentParticiple => 'present participle of',
    FormRelation.thirdPerson => 'third-person singular of',
    FormRelation.comparative => 'comparative of',
    FormRelation.superlative => 'superlative of',
    FormRelation.form => 'form of',
  };
  return '$display – $how $base';
}

/// Turns a query into ordered sections (research R5):
/// 1. per candidate, in order: exact entries, then the bases it is a form of (from the
///    dictionary, else from the rules); the first candidate with anything wins;
/// 2. exact entries first (FR-012), then each base's entries under a note;
/// 3. a capitalised word mid-sentence puts proper nouns first; otherwise they go last
///    (FR-010);
/// 4. a hyphenated word with nothing found shows its parts as sections (FR-009).
class LookupResolver {
  LookupResolver(this._lexicon) : _lemmatiser = Lemmatiser(_lexicon);

  final Lexicon _lexicon;
  final Lemmatiser _lemmatiser;

  Future<LookupResult> resolve(LookupQuery query) async {
    if (query.garbled) return LookupResult(query);
    for (final key in query.candidates) {
      final sections = await _word(key, query.display, query.capitalisedMidSentence);
      if (sections.isNotEmpty) return LookupResult(query, sections: sections);
    }
    if (query.parts.length > 1) {
      final sections = <ResultSection>[];
      for (final part in query.parts) {
        sections.addAll(await _word(part, part, false));
      }
      if (sections.isNotEmpty) return LookupResult(query, sections: sections);
    }
    return LookupResult(query);
  }

  /// Sections for one key: its own entries, then its bases'.
  Future<List<ResultSection>> _word(String key, String display, bool properFirst) async {
    final exact = _byCase(await _lexicon.entries(key), properFirst);
    var links = await _lexicon.formsOf(key);
    if (exact.isEmpty && links.isEmpty) links = await _lemmatiser.basesOf(key);
    final sections = [for (final e in exact) ResultSection(e)];
    final seen = <String>{key};
    for (final link in links) {
      if (!seen.add(link.base)) continue;
      final entries = _byCase(await _lexicon.entries(link.base), properFirst);
      final note = formNote(
        display,
        link.relation,
        entries.isEmpty ? link.base : entries.first.headword,
      );
      sections.addAll([
        for (var i = 0; i < entries.length; i++)
          ResultSection(entries[i], note: i == 0 ? note : null),
      ]);
    }
    return sections;
  }

  /// Proper nouns first or last; the dictionary's order otherwise.
  static List<DictionaryEntry> _byCase(List<DictionaryEntry> entries, bool properFirst) {
    final proper = entries.where((e) => e.isProperNoun);
    final common = entries.where((e) => !e.isProperNoun);
    return properFirst ? [...proper, ...common] : [...common, ...proper];
  }
}
