// The full dictionary for the accuracy evals (003 SC-001, SC-003, SC-004). Built by
// tool/build_dictionary.py --download; the evals are skipped when it is missing.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:potha/core/dictionary/dictionary_database.dart';

final fullDictionary = File('build/dictionary/en.sqlite');

final String? skipWithoutDictionary = fullDictionary.existsSync()
    ? null
    : 'Full dictionary missing: run tool/build_dictionary.py --download '
          '(see specs/003-dictionary-lookup/quickstart.md)';

Future<DictionaryDatabase> openFullDictionary() => DictionaryDatabase.open(
  NativeDatabase(fullDictionary, setup: (db) => db.execute(DictionaryDatabase.readOnlyPragma)),
);

/// Prints a share and returns it, for the eval reports.
double report(String what, int good, int total, List<String> misses) {
  final share = total == 0 ? 0.0 : good / total;
  // ignore: avoid_print
  print('$what: $good / $total = ${(share * 100).toStringAsFixed(1)}%');
  if (misses.isNotEmpty) {
    // ignore: avoid_print
    print('  misses: ${misses.join(', ')}');
  }
  return share;
}
