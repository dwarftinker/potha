// Fills build/web/potha_sw.js (copied from web/potha_sw.js by the Flutter build) with the
// files to cache when it installs and a version that changes with every build, so a new
// deploy installs a new worker with a fresh cache. Run by tool/build_web.sh:
//
//   dart run tool/write_service_worker.dart build/web
//
// Left out of the precache list:
// - CanvasKit: the build holds several variants and the browser loads one; the worker
//   caches that one when it is fetched (and the page reports it if it loaded first);
// - debug symbols, never fetched;
// - the dictionary (24 MB), which the app keeps in IndexedDB after its one download;
// - the service workers and Flutter's build id.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

const serviceWorkerFile = 'potha_sw.js';
const _versionPlaceholder = "'__POTHA_VERSION__'";
const _precachePlaceholder = "'__POTHA_PRECACHE__'";

// lib/core/dictionary/dictionary_store.dart's dictionaryAsset under assets/ (that file
// imports Flutter, so it can't be imported here; the test checks they match).
const _dictionaryPath = 'assets/assets/dictionary/en.sqlite.gz';

const _excludedFiles = {
  _dictionaryPath,
  serviceWorkerFile,
  'flutter_service_worker.js',
  '.last_build_id',
};

/// The build files the service worker caches when it installs, relative to the build
/// directory, with forward slashes, sorted.
List<String> precachePaths(Iterable<String> paths) {
  final kept = [
    for (final path in paths.map((p) => p.replaceAll(r'\', '/')))
      if (!path.startsWith('canvaskit/') &&
          !path.endsWith('.symbols') &&
          !_excludedFiles.contains(path))
        path,
  ];
  return kept..sort();
}

/// A short hash over every build file's path and bytes (CanvasKit included, the service
/// worker itself left out).
String buildVersion(Map<String, List<int>> files) {
  final paths = files.keys.where((p) => p != serviceWorkerFile).toList()..sort();
  final digest = sha256.convert([
    for (final path in paths) ...[...utf8.encode(path), 0, ...sha256.convert(files[path]!).bytes],
  ]);
  return digest.toString().substring(0, 16);
}

/// [template] with its version and precache list filled in.
String fillServiceWorker(String template, {required String version, required List<String> paths}) {
  if (!template.contains(_versionPlaceholder) || !template.contains(_precachePlaceholder)) {
    throw StateError('$serviceWorkerFile has no $_versionPlaceholder or $_precachePlaceholder');
  }
  return template
      .replaceFirst(_versionPlaceholder, "'$version'")
      .replaceFirst(_precachePlaceholder, jsonEncode(paths));
}

/// Fills [buildDir]/potha_sw.js from the build in [buildDir].
({String version, List<String> paths}) writeServiceWorker(Directory buildDir) {
  final files = <String, List<int>>{
    for (final file in buildDir.listSync(recursive: true).whereType<File>())
      file.path.substring(buildDir.path.length + 1).replaceAll(r'\', '/'): file.readAsBytesSync(),
  };
  final version = buildVersion(files);
  final paths = precachePaths(files.keys);
  final worker = File('${buildDir.path}/$serviceWorkerFile');
  worker.writeAsStringSync(
    fillServiceWorker(worker.readAsStringSync(), version: version, paths: paths),
  );
  return (version: version, paths: paths);
}

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run tool/write_service_worker.dart <web build directory>');
    exit(64);
  }
  final result = writeServiceWorker(Directory(args.single));
  stdout.writeln('$serviceWorkerFile: version ${result.version}, ${result.paths.length} files');
}
