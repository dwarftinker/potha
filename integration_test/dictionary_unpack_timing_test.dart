// 003 T083: how long the first launch after an install takes to unpack the dictionary
// and open it, in profile mode on the device:
//   flutter drive --profile --no-dds --driver=test_driver/perf_driver.dart \
//     --target=integration_test/dictionary_unpack_timing_test.dart -d <device>
// The unpacked copy is deleted first, so the run is the same as a fresh install.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('the dictionary is unpacked and ready after a fresh install', (tester) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/dictionary');
    if (dir.existsSync()) dir.deleteSync(recursive: true);

    final watch = Stopwatch()..start();
    await app.main(); // starts the unpack after the first frame
    await tester.pump();
    final store = containerOf(tester).read(dictionaryStoreProvider);
    expect(store.current, isNot(isA<DictionaryReady>()));
    final lexicon = await store.ready.timeout(const Duration(minutes: 2));
    final readyMs = watch.elapsedMilliseconds;
    expect(await lexicon.entries('melancholy'), isNotEmpty);
    final file = dir.listSync().whereType<File>().single;
    // ignore: avoid_print
    print('dictionary: ready $readyMs ms after app start; ${file.lengthSync()} bytes');
    binding.reportData = {
      'dictionary_unpack': {'ready_ms': readyMs, 'bytes': file.lengthSync()},
    };
  });
}
