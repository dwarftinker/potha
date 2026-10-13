// The web dictionary: downloaded on first use, then kept (003 T017, FR-022, research R2).
// Run with: flutter test --platform chrome test/web/
// test/web/sqlite3.wasm and drift_worker.js are symlinks to web/ so drift can load here.
@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/core/dictionary/dictionary_store_web.dart';
import 'package:web/web.dart' as web;

const _sample = '../fixtures/dictionary/dict_sample.sqlite.gz';

void main() {
  final stores = <WebDictionaryStore>[];

  tearDown(() async {
    for (final s in stores) {
      await s.close();
    }
    stores.clear();
  });

  WebDictionaryStore store({String asset = _sample, bool Function()? isOnline}) {
    // A fresh database name per test, so earlier downloads don't count.
    final version = 'test-${Random().nextInt(1 << 30)}';
    final s = WebDictionaryStore(
      assetUrl: asset,
      loadVersion: () async => version,
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
      isOnline: isOnline,
    );
    stores.add(s);
    return s;
  }

  int requestsFor(String asset) => web.window.performance
      .getEntriesByType('resource')
      .toDart
      .where((e) => e.name.endsWith(asset.split('/').last))
      .length;

  test('no request happens before ensureStarted', () async {
    web.window.performance.clearResourceTimings();
    final s = store();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(requestsFor(_sample), 0);
    expect(s.current, isA<DictionaryNotStarted>());
  });

  test('downloads with progress up to 100%, then is ready and looks up', () async {
    final s = store();
    final statuses = <DictionaryStatus>[];
    s.status.listen(statuses.add);
    s.ensureStarted();
    final lexicon = await s.ready.timeout(const Duration(seconds: 30));
    final progress = statuses.whereType<DictionaryDownloading>().toList();
    expect(progress, isNotEmpty);
    expect(progress.last.fraction, 1.0);
    expect(statuses.last, isA<DictionaryReady>());
    expect(await lexicon.entries('melancholy'), isNotEmpty);
    expect(lexicon.info.licence, 'CC BY-SA 4.0');
  });

  test('a failed download gives failed(error)', () async {
    final s = store(asset: 'missing.sqlite.gz');
    s.ensureStarted();
    final failed = await s.status
        .firstWhere((e) => e is DictionaryFailed)
        .timeout(const Duration(seconds: 30));
    expect((failed as DictionaryFailed).reason, DictionaryFailure.error);
  });

  test('offline gives failed(offline), and the next ensureStarted retries', () async {
    var online = false;
    final s = store(isOnline: () => online);
    s.ensureStarted();
    final failed = await s.status
        .firstWhere((e) => e is DictionaryFailed)
        .timeout(const Duration(seconds: 30));
    expect((failed as DictionaryFailed).reason, DictionaryFailure.offline);
    online = true;
    s.ensureStarted();
    final lexicon = await s.ready.timeout(const Duration(seconds: 30));
    expect(await lexicon.hasEntry('melancholy'), isTrue);
  });
}
