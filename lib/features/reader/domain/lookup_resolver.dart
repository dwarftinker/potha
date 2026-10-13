// From a query to the entries shown, in order (003 research R5). Pure Dart over Lexicon.
import 'package:flutter/foundation.dart';

import '../../../core/dictionary/lexicon.dart';
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

class LookupResolver {
  const LookupResolver(this._lexicon);

  final Lexicon _lexicon;

  Future<LookupResult> resolve(LookupQuery query) async {
    if (query.garbled) return LookupResult(query);
    for (final key in query.candidates) {
      final entries = await _lexicon.entries(key);
      if (entries.isNotEmpty) {
        return LookupResult(query, sections: [for (final e in entries) ResultSection(e)]);
      }
    }
    return LookupResult(query);
  }
}
