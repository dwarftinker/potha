// Unpacking the bundled dictionary on Android and iOS (003 T015, research R2).
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_database.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/dictionary/dictionary_store_io.dart';
import 'package:potha/core/dictionary/lexicon.dart';

final _sample = File('build/fixtures/dict_sample.sqlite');
final _skip = _sample.existsSync()
    ? null
    : 'Sample dictionary missing; run tool/build_dictionary.py --sample';

void main() {
  late Directory support;
  late Uint8List asset;
  late int assetLoads;
  final stores = <IoDictionaryStore>[];

  setUp(() {
    support = Directory.systemTemp.createTempSync('dict_store');
    if (_skip == null) asset = Uint8List.fromList(gzip.encode(_sample.readAsBytesSync()));
    assetLoads = 0;
  });

  tearDown(() async {
    for (final s in stores) {
      await s.close();
    }
    stores.clear();
    support.deleteSync(recursive: true);
  });

  IoDictionaryStore store({String version = '20260902.1'}) {
    final s = IoDictionaryStore(
      supportDirectory: () async => support,
      loadAsset: () async {
        assetLoads++;
        return asset;
      },
      loadVersion: () async => version,
      openExecutor: (file) =>
          NativeDatabase(file, setup: (db) => db.execute(DictionaryDatabase.readOnlyPragma)),
    );
    stores.add(s);
    return s;
  }

  File dictFile(String version) => File('${support.path}/dictionary/en-$version.sqlite');

  test('unpacks, reports unpacking then ready, and gives a working lexicon', () async {
    final s = store();
    final statuses = <DictionaryStatus>[];
    s.status.listen(statuses.add);
    expect(s.current, isA<DictionaryNotStarted>());
    s.ensureStarted();
    final lexicon = await s.ready;
    await pumpEventQueue();
    expect(statuses.map((e) => e.runtimeType), [DictionaryUnpacking, DictionaryReady]);
    expect(await lexicon.entries('melancholy'), isNotEmpty);
    expect(dictFile('20260902.1').existsSync(), isTrue);
    expect(Directory('${support.path}/dictionary').listSync().whereType<File>(), hasLength(1));
  }, skip: _skip);

  test('a second ensureStarted does not unpack again', () async {
    final s = store();
    s.ensureStarted();
    s.ensureStarted();
    await s.ready;
    s.ensureStarted();
    expect(assetLoads, 1);
  }, skip: _skip);

  test('an existing file is opened without unpacking', () async {
    final first = store();
    first.ensureStarted();
    await first.ready;
    await first.close();
    final second = store();
    second.ensureStarted();
    await second.ready;
    expect(assetLoads, 1);
  }, skip: _skip);

  test('an interrupted unpack (temporary file left) is redone', () async {
    Directory('${support.path}/dictionary').createSync();
    File('${dictFile('20260902.1').path}.part').writeAsStringSync('half a file');
    final s = store();
    s.ensureStarted();
    final lexicon = await s.ready;
    expect(await lexicon.hasEntry('melancholy'), isTrue);
    expect(File('${dictFile('20260902.1').path}.part').existsSync(), isFalse);
  }, skip: _skip);

  test('older versions are deleted once the new one is ready', () async {
    Directory('${support.path}/dictionary').createSync();
    dictFile('20250101.1').writeAsStringSync('old');
    final s = store();
    s.ensureStarted();
    await s.ready;
    expect(dictFile('20250101.1').existsSync(), isFalse);
    expect(dictFile('20260902.1').existsSync(), isTrue);
  }, skip: _skip);

  test('a failure reports failed(error), and the next ensureStarted retries', () async {
    var fail = true;
    final s = IoDictionaryStore(
      supportDirectory: () async => support,
      loadAsset: () async {
        if (fail) throw StateError('asset missing');
        return asset;
      },
      loadVersion: () async => '1',
      openExecutor: (file) => NativeDatabase(file),
    );
    stores.add(s);
    s.ensureStarted();
    await s.status.firstWhere((e) => e is DictionaryFailed);
    expect((s.current as DictionaryFailed).reason, DictionaryFailure.error);
    fail = false;
    s.ensureStarted();
    expect(await (await s.ready).hasEntry('melancholy'), isTrue);
  }, skip: _skip);
}
