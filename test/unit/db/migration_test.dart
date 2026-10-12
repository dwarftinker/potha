// Guards data across app updates (FR-024, SC-006).
//
// After changing a table: bump AppDatabase.schemaVersion, write the migration, then run
//   dart run drift_dev make-migrations
//   dart run drift_dev schema generate drift_schemas/app_database/ test/unit/db/generated/
// and add a test below that migrates from the previous version and checks the data.
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/core/db/app_database.dart';

import 'generated/schema.dart';

void main() {
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('current schema matches the saved v1 snapshot', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    await verifier.migrateAndValidate(db, 1);
    await db.close();
  });
}
