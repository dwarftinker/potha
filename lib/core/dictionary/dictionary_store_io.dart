// Android and iOS: the dictionary ships in the install (clarification Q4). The gzip
// asset is unpacked once per install or upgrade, in a background isolate, into
// <app support>/dictionary/en-<version>.sqlite and opened read-only (research R2).
// ignore_for_file: prefer_initializing_formals (named parameters can't be private)
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'dictionary_database.dart';
import 'dictionary_store.dart';

DictionaryStore createDictionaryStore() => IoDictionaryStore(
  supportDirectory: getApplicationSupportDirectory,
  loadAsset: () async => (await rootBundle.load(dictionaryAsset)).buffer.asUint8List(),
  loadVersion: () async => (await rootBundle.loadString(dictionaryVersionAsset)).trim(),
  openExecutor: (file) => driftDatabase(
    name: 'dictionary',
    native: DriftNativeOptions(
      databasePath: () async => file.path,
      setup: (db) => db.execute(DictionaryDatabase.readOnlyPragma),
    ),
  ),
);

class IoDictionaryStore implements DictionaryStore {
  IoDictionaryStore({
    required Future<Directory> Function() supportDirectory,
    required Future<Uint8List> Function() loadAsset,
    required Future<String> Function() loadVersion,
    required QueryExecutor Function(File file) openExecutor,
  }) : _supportDirectory = supportDirectory,
       _loadAsset = loadAsset,
       _loadVersion = loadVersion,
       _openExecutor = openExecutor;

  final Future<Directory> Function() _supportDirectory;
  final Future<Uint8List> Function() _loadAsset;
  final Future<String> Function() _loadVersion;
  final QueryExecutor Function(File file) _openExecutor;

  final _changes = StreamController<DictionaryStatus>.broadcast();
  final _ready = Completer<Lexicon>();
  DictionaryStatus _current = const DictionaryNotStarted();
  bool _running = false;
  DictionaryDatabase? _db;

  @override
  DictionaryStatus get current => _current;

  @override
  Stream<DictionaryStatus> get status => _changes.stream;

  @override
  Future<Lexicon> get ready => _ready.future;

  @override
  void ensureStarted() {
    if (_running || _ready.isCompleted) return;
    _running = true;
    unawaited(_prepare()); // clears _running itself on failure; success completes ready
  }

  Future<void> _prepare() async {
    try {
      final version = await _loadVersion();
      final dir = Directory('${(await _supportDirectory()).path}/dictionary');
      await dir.create(recursive: true);
      final file = File('${dir.path}/en-$version.sqlite');
      if (!await file.exists()) {
        _set(const DictionaryUnpacking());
        final bytes = await _loadAsset();
        await Isolate.run(() => _unpack(bytes, file.path));
      }
      final db = await DictionaryDatabase.open(_openExecutor(file));
      _db = db;
      await _deleteOthers(dir, keep: file.path);
      _set(const DictionaryReady());
      _ready.complete(db);
    } catch (_) {
      _running = false; // before announcing it, so a listener can retry at once
      _set(const DictionaryFailed(DictionaryFailure.error));
    }
  }

  /// Writes to a temporary name and renames when done, so an interrupted unpack is
  /// redone next time.
  static void _unpack(Uint8List gz, String path) {
    final part = File('$path.part');
    part.writeAsBytesSync(gzip.decode(gz), flush: true);
    part.renameSync(path);
  }

  static Future<void> _deleteOthers(Directory dir, {required String keep}) async {
    await for (final entity in dir.list()) {
      if (entity is File && entity.path != keep) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  void _set(DictionaryStatus status) {
    _current = status;
    if (!_changes.isClosed) _changes.add(status);
  }

  @override
  Future<void> close() async {
    await _changes.close();
    await _db?.close();
  }
}
