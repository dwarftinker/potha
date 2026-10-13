// The dictionary seen by lookup (003 contracts/lookup.md). Format- and platform-agnostic:
// nothing here names SQLite, pdfrx or a web API.
import 'package:flutter/foundation.dart';

/// One language's dictionary. English only for now; other languages are other instances.
abstract interface class Lexicon {
  /// 'en'.
  String get language;

  /// Source, licence and dump date, shown in the panel and About (FR-034).
  DictionaryInfo get info;

  /// Entries whose key is [key] (see lookupKey), in dictionary order. [] if none.
  Future<List<DictionaryEntry>> entries(String key);

  /// Base words that [key] is a form of ("mice" -> mouse, plural). [] if none.
  Future<List<WordFormLink>> formsOf(String key);

  Future<bool> hasEntry(String key);
}

@immutable
class DictionaryInfo {
  const DictionaryInfo({
    required this.source,
    required this.licence,
    required this.licenceUrl,
    required this.sourceUrl,
    required this.dumpDate,
    required this.version,
  });

  /// "English Wiktionary via wiktextract / kaikki.org".
  final String source;

  /// "CC BY-SA 4.0".
  final String licence;
  final String licenceUrl;
  final String sourceUrl;

  /// "2026-09-02".
  final String dumpDate;

  /// "20260902.1".
  final String version;
}

/// One headword and part of speech.
@immutable
class DictionaryEntry {
  const DictionaryEntry({
    required this.headword,
    required this.pos,
    this.ipa,
    required this.senses,
  });

  /// As written in the dictionary ("Turkey", "give up").
  final String headword;

  /// Wiktionary's part of speech: noun, verb, adj, adv, name (proper noun), phrase, …
  final String pos;
  final String? ipa;
  final List<Sense> senses;

  bool get isProperNoun => pos == 'name';

  @override
  String toString() => 'DictionaryEntry($headword, $pos, ${senses.length} senses)';
}

@immutable
class Sense {
  const Sense(this.gloss, {this.tags = const [], this.examples = const []});

  final String gloss;

  /// Usage labels such as "informal" or "archaic".
  final List<String> tags;
  final List<String> examples;
}

/// How an inflected form relates to its base word. The names match the build script's.
enum FormRelation {
  plural,
  past,
  pastParticiple,
  presentParticiple,
  thirdPerson,
  comparative,
  superlative,
  form;

  /// From the dictionary file's `relation` column; unknown values are [form].
  static FormRelation parse(String value) => switch (value) {
    'plural' => plural,
    'past' => past,
    'past_participle' => pastParticiple,
    'present_participle' => presentParticiple,
    'third_person' => thirdPerson,
    'comparative' => comparative,
    'superlative' => superlative,
    _ => form,
  };
}

@immutable
class WordFormLink {
  const WordFormLink(this.form, this.base, this.relation);

  /// Keys, not display text.
  final String form;
  final String base;
  final FormRelation relation;

  @override
  bool operator ==(Object other) =>
      other is WordFormLink &&
      other.form == form &&
      other.base == base &&
      other.relation == relation;

  @override
  int get hashCode => Object.hash(form, base, relation);

  @override
  String toString() => 'WordFormLink($form -> $base, ${relation.name})';
}

/// Whether the dictionary can be used yet (FR-022; research R2).
@immutable
sealed class DictionaryStatus {
  const DictionaryStatus();
}

class DictionaryNotStarted extends DictionaryStatus {
  const DictionaryNotStarted();
}

/// Web: the first download. [total] is null when the size isn't known.
class DictionaryDownloading extends DictionaryStatus {
  const DictionaryDownloading(this.bytes, this.total);

  final int bytes;
  final int? total;

  /// 0–1, or null if unknown.
  double? get fraction => total == null || total == 0 ? null : (bytes / total!).clamp(0.0, 1.0);
}

/// Mobile: unpacking the bundled file after install or upgrade.
class DictionaryUnpacking extends DictionaryStatus {
  const DictionaryUnpacking();
}

class DictionaryReady extends DictionaryStatus {
  const DictionaryReady();
}

enum DictionaryFailure { offline, error }

class DictionaryFailed extends DictionaryStatus {
  const DictionaryFailed(this.reason);

  final DictionaryFailure reason;
}

/// An online dictionary, used only from the "Search online" action (FR-021, FR-032).
abstract interface class OnlineDictionary {
  Future<OnlineResult> lookUp(String word);
}

@immutable
sealed class OnlineResult {
  const OnlineResult();
}

class OnlineFound extends OnlineResult {
  const OnlineFound(this.entries);

  final List<DictionaryEntry> entries;
}

class OnlineNotFound extends OnlineResult {
  const OnlineNotFound();
}

class OnlineFailed extends OnlineResult {
  const OnlineFailed([this.cause]);

  final Object? cause;
}
