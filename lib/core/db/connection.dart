// Opens the app database on every platform.
//
// Web needs two static files in web/ that must match the resolved package versions in
// pubspec.lock:
//   - sqlite3.wasm    from https://github.com/simolus3/sqlite3.dart/releases (sqlite3-<version>)
//   - drift_worker.js from https://github.com/simolus3/drift/releases (drift-<version>)
// Re-download both whenever `drift` or `sqlite3` is upgraded.
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

AppDatabase openAppDatabase() => AppDatabase(
      driftDatabase(
        name: 'potha',
        web: DriftWebOptions(
          sqlite3Wasm: Uri.parse('sqlite3.wasm'),
          driftWorker: Uri.parse('drift_worker.js'),
        ),
      ),
    );

/// Overridden in tests with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = openAppDatabase();
  ref.onDispose(db.close);
  return db;
});
