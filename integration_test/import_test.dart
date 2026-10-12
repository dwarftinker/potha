// US1 on a device or in Chrome: flutter test integration_test/import_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:potha/features/library/data/library_repository.dart';
import 'package:potha/features/library/import/import_controller.dart';
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

    await importer.importSources([sourceFromBytes('book.pdf', pdf)], askPassword: noPassword);
    await pumpUntil(tester, find.text(title));
    expect((await repo.allBookIds()).length, before + 1);

    await importer.importSources([sourceFromBytes('copy.pdf', pdf)], askPassword: noPassword);
    await pumpUntil(tester, find.text('Already in your library'));
    expect((await repo.allBookIds()).length, before + 1);

    await importer.importSources(
        [sourceFromBytes('notes.pdf', buildPdf().sublist(5))], askPassword: noPassword);
    await pumpUntil(tester, find.text('This file is not a PDF.'));
    expect((await repo.allBookIds()).length, before + 1);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
