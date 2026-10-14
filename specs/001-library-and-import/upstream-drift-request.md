# Draft issue for simolus3/drift (not posted)

Needs the user's approval before posting.

---

**Title:** Web (IndexedDB): schema version set after migrations isn't persisted until the next write

**Versions:** drift 2.35.0, drift_flutter 0.3.1, sqlite3 3.5.2, Chrome 14x
(`sharedIndexedDb` and `unsafeIndexedDb`).

**What happens**

On a fresh database with IndexedDB storage, the tables created in `onCreate` are saved,
but `user_version` stays 0 in IndexedDB. If the page is reloaded before the app writes
anything else, drift sees version 0 and runs `onCreate` again on the existing tables:

```
SqliteException(1): while executing, index books_last_opened_at already exists,
SQL logic error (code 1)
```

**Why**

`IndexedDbFileSystem` is opened with `writeAutomatically: false`, and
`WasmDatabase` flushes only after `runCustom`, `runInsert`, `runUpdate` and
`runBatched` outside a transaction. After migrations and `beforeOpen`,
`DelegatedDatabase._runMigrations` calls `versionDelegate.setSchemaVersion`, which
for `_SqliteVersionDelegate` sets `database.userVersion` directly, so nothing flushes it.

**Reproduce**

1. Open a database with `WasmStorageImplementation.unsafeIndexedDb` (or
   `sharedIndexedDb`) and a schema with `onCreate`; run one query; don't close it.
2. Read block 0 of `/database` from IndexedDB: `user_version` (offset 60) is 0.
3. Open a second connection with the same name and `unsafeIndexedDb`: `onCreate` runs
   again and fails.

**Workaround**

At the end of `beforeOpen`, when `details.wasCreated || details.hadUpgrade`:
`await customStatement('PRAGMA user_version = ${details.versionNow}');`

**Possible fix**

Flush after `setSchemaVersion` in the wasm delegate (or give `_SqliteVersionDelegate`
access to the flush).
