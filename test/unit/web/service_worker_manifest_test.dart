// The service worker's precache list and version (tool/write_service_worker.dart), which
// tool/build_web.sh writes into build/web/potha_sw.js after the Flutter build.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/dictionary/dictionary_store.dart';

import '../../../tool/write_service_worker.dart';

void main() {
  group('precachePaths', () {
    test('keeps the app, the reader part, pdfium and sqlite; sorted', () {
      final paths = precachePaths([
        'main.dart.js_1.part.js',
        'index.html',
        'main.dart.js',
        'flutter_bootstrap.js',
        'flutter.js',
        'manifest.json',
        'sqlite3.wasm',
        'drift_worker.js',
        'assets/packages/pdfrx/assets/pdfium.wasm',
        'assets/packages/pdfrx/assets/pdfium_worker.js',
        'assets/fonts/MaterialIcons-Regular.otf',
        'assets/assets/dictionary/version',
        'icons/Icon-192.png',
      ]);
      expect(paths, [
        'assets/assets/dictionary/version',
        'assets/fonts/MaterialIcons-Regular.otf',
        'assets/packages/pdfrx/assets/pdfium.wasm',
        'assets/packages/pdfrx/assets/pdfium_worker.js',
        'drift_worker.js',
        'flutter.js',
        'flutter_bootstrap.js',
        'icons/Icon-192.png',
        'index.html',
        'main.dart.js',
        'main.dart.js_1.part.js',
        'manifest.json',
        'sqlite3.wasm',
      ]);
    });

    test('leaves out CanvasKit, debug symbols, the dictionary and the workers', () {
      final paths = precachePaths([
        'canvaskit/canvaskit.wasm',
        'canvaskit/chromium/canvaskit.js',
        'canvaskit/skwasm.js.symbols',
        'main.dart.js.symbols',
        'assets/$dictionaryAsset',
        'flutter_service_worker.js',
        'potha_sw.js',
        '.last_build_id',
        'main.dart.js',
      ]);
      expect(paths, ['main.dart.js']);
    });

    test("matches the app's dictionary path", () {
      expect(precachePaths(['assets/$dictionaryAsset']), isEmpty);
    });

    test('uses forward slashes', () {
      expect(precachePaths([r'assets\fonts\MaterialIcons-Regular.otf']), [
        'assets/fonts/MaterialIcons-Regular.otf',
      ]);
    });
  });

  group('buildVersion', () {
    final files = {
      'main.dart.js': utf8.encode('main'),
      'canvaskit/chromium/canvaskit.wasm': utf8.encode('ck'),
    };

    test('is stable for the same files', () {
      expect(buildVersion(files), buildVersion(Map.of(files)));
      expect(buildVersion(files), matches(RegExp(r'^[0-9a-f]{16}$')));
    });

    test('changes when any file changes, CanvasKit included', () {
      final v = buildVersion(files);
      expect(buildVersion({...files, 'main.dart.js': utf8.encode('main2')}), isNot(v));
      expect(
        buildVersion({...files, 'canvaskit/chromium/canvaskit.wasm': utf8.encode('ck2')}),
        isNot(v),
      );
      expect(buildVersion({...files, 'flutter.js': utf8.encode('f')}), isNot(v));
    });

    test('a renamed file changes it', () {
      expect(
        buildVersion({'a.js': utf8.encode('x')}),
        isNot(buildVersion({'b.js': utf8.encode('x')})),
      );
    });

    test('ignores the service worker itself', () {
      expect(buildVersion({...files, 'potha_sw.js': utf8.encode('sw')}), buildVersion(files));
    });
  });

  group('fillServiceWorker', () {
    test('writes the version and the list', () {
      final js = fillServiceWorker(template, version: 'abc123', paths: ['index.html', 'a b.js']);
      expect(js, "const VERSION = 'abc123';\nconst PRECACHE = [\"index.html\",\"a b.js\"];\n");
    });

    test('refuses a template without the placeholders', () {
      expect(
        () => fillServiceWorker('const x = 1;', version: 'v', paths: []),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('writeServiceWorker fills build/web/potha_sw.js from the build', () {
    final dir = Directory.systemTemp.createTempSync('potha_sw_');
    addTearDown(() => dir.deleteSync(recursive: true));
    void put(String path, String content) =>
        (File('${dir.path}/$path')..createSync(recursive: true)).writeAsStringSync(content);
    put('index.html', '<html>');
    put('main.dart.js', 'main');
    put('canvaskit/canvaskit.wasm', 'ck');
    put('assets/$dictionaryAsset', 'gz');
    put('potha_sw.js', template);

    final result = writeServiceWorker(dir);

    expect(result.paths, ['index.html', 'main.dart.js']);
    final js = File('${dir.path}/potha_sw.js').readAsStringSync();
    expect(js, contains("const VERSION = '${result.version}';"));
    expect(js, contains('const PRECACHE = ["index.html","main.dart.js"];'));
  });
}

const template = "const VERSION = '__POTHA_VERSION__';\nconst PRECACHE = '__POTHA_PRECACHE__';\n";
