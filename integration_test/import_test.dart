// US1 on a device or in Chrome: flutter test integration_test/import_test.dart -d <device>
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/library/import/import_controller.dart';
import 'package:potha/features/library/import/import_source.dart';
import 'package:potha/main.dart' as app;

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('import adds a book once and rejects non-PDFs', (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    final importer = container.read(importControllerProvider.notifier);
    final repo = container.read(libraryRepositoryProvider);
    Future<String?> noPassword(String _, {required bool retry}) async => null;

    // Unique title so reruns on the same device don't collide.
    final title = 'Integration ${DateTime.now().microsecondsSinceEpoch}';
    final pdf = buildPdf(title: title, pages: 2);
    final before = (await repo.allBookIds()).length;

    await importer.importSources([
      sourceFromBytes('book.pdf', pdf),
    ], askPassword: noPassword);
    await pumpUntil(tester, find.text(title));
    expect((await repo.allBookIds()).length, before + 1);

    await importer.importSources([
      sourceFromBytes('copy.pdf', pdf),
    ], askPassword: noPassword);
    await pumpUntil(tester, find.text('Already in your library'));
    expect((await repo.allBookIds()).length, before + 1);

    await importer.importSources([
      sourceFromBytes('notes.pdf', buildPdf().sublist(5)),
    ], askPassword: noPassword);
    await pumpUntil(tester, find.text('This file is not a PDF.'));
    expect((await repo.allBookIds()).length, before + 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a file read from disk imports, as the file picker and Share to give it',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final importer = containerOf(tester).read(importControllerProvider.notifier);

    // The file picker and Open with / Share to hand over files on disk, read through
    // XFile (a Stream<Uint8List>), not bytes in memory.
    final title = 'From disk ${DateTime.now().microsecondsSinceEpoch}';
    final dir = await Directory.systemTemp.createTemp('potha_it');
    final file = File('${dir.path}/picked.pdf')..writeAsBytesSync(buildPdf(title: title));
    await importer.importSources([
      await ImportSource.fromXFile(XFile(file.path)),
    ], askPassword: (_, {required retry}) async => null);
    await pumpUntil(tester, find.text(title));
    await dir.delete(recursive: true);
  });

  testWidgets('Cancel on the progress bar stops a large import and leaves nothing (FR-008)',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    final container = containerOf(tester);
    final repo = container.read(libraryRepositoryProvider);
    final before = (await repo.allBookIds()).length;

    // A 64 MB PDF that arrives slowly, so the copy is still running when Cancel is
    // tapped however fast the device is.
    final pdf = buildPdf(title: 'Cancelled ${DateTime.now().microsecondsSinceEpoch}');
    const total = 64 << 20;
    final slow = ImportSource(
      name: 'slow.pdf',
      size: total,
      openRead: () async* {
        yield pdf;
        for (var sent = pdf.length; sent < total; sent += 1 << 20) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          yield Uint8List(1 << 20);
        }
      },
    );
    unawaited(container.read(importControllerProvider.notifier).importSources(
        [slow], askPassword: (_, {required retry}) async => null));

    await pumpUntil(tester, find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (container.read(importControllerProvider).running &&
        DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(importControllerProvider).running, isFalse,
        reason: 'the import kept running after Cancel');

    expect((await repo.allBookIds()).length, before);
    final staging = Directory('${(await getApplicationSupportDirectory()).path}/staging');
    expect(staging.existsSync() ? staging.listSync() : const [], isEmpty);
  });
}
