// Shared harness for widget tests: the real app shell with in-memory storage and fakes.
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:potha/app.dart';
import 'package:potha/core/db/app_database.dart';
import 'package:potha/core/db/connection.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/features/library/import/import_service.dart';
import 'package:potha/features/library/import/import_source.dart';
import 'package:potha/features/library/ui/library_screen.dart';

/// An ImportService whose behaviour each test scripts through [script].
class FakeImportService extends Fake implements ImportService {
  FakeImportService(this.script);

  /// Receives the event sink and the password callback; must add ImportFinished last.
  final Future<void> Function(
    void Function(ImportEvent) emit,
    AskImportPassword askPassword,
    Completer<void> cancelled,
  ) script;

  var cancelCalls = 0;
  Completer<void> _cancelled = Completer<void>();

  @override
  Stream<ImportEvent> importFiles(List<ImportSource> files,
      {required AskImportPassword askPassword}) {
    _cancelled = Completer<void>();
    final controller = StreamController<ImportEvent>();
    script(controller.add, askPassword, _cancelled).whenComplete(controller.close);
    return controller.stream;
  }

  @override
  void cancel() {
    cancelCalls++;
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

ImportSource fakeSource(String name) =>
    ImportSource(name: name, size: 10, openRead: () => const Stream.empty());

ImportResult added(String name, String title, {String id = 'b1'}) => ImportResult(
    fileName: name, outcome: ImportOutcome.added, bookId: id, title: title);

class TestApp {
  TestApp({
    ImportService? importService,
    bool isWeb = false,
    List<ImportSource> Function()? picked,
    List<Override> overrides = const [],
  }) : db = AppDatabase(NativeDatabase.memory()) {
    widget = ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        isWebProvider.overrideWithValue(isWeb),
        incomingFilesEnabledProvider.overrideWithValue(false),
        pickFilesProvider.overrideWithValue(
            () async => picked?.call() ?? [fakeSource('book.pdf')]),
        if (importService != null) importServiceProvider.overrideWithValue(importService),
        ...overrides,
      ],
      child: const PothaApp(),
    );
  }

  final AppDatabase db;
  late final Widget widget;

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(widget);
    await tester.pump();
  }

  /// Unmounts the app and closes the database so no drift timers stay pending.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    // Closing needs real async; it hangs inside the test's fake-async zone.
    await tester.runAsync(db.close);
  }
}

/// Taps the "Add book" app-bar action.
Future<void> tapAddBook(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Add book'));
  await tester.pump();
}
