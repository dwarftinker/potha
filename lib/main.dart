import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/dictionary/dictionary_warmup.dart';
import 'core/storage/book_file_store.dart';
import 'features/library/data/library_repository.dart';
import 'features/library/import/import_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerDictionaryLicence();
  final cleanupDone = Completer<void>();
  final container = ProviderContainer(
    overrides: [startupCleanupProvider.overrideWithValue(cleanupDone.future)],
  );
  // Show the library right away; imports wait until cleanup has finished.
  runApp(UncontrolledProviderScope(container: container, child: const PothaApp()));
  startDictionaryUnpack(container);
  await cleanUpStorage(container);
  cleanupDone.complete();
}

/// Removes leftovers of interrupted imports and files of books no longer in the
/// database (research R4), so nothing partial is ever shown.
Future<void> cleanUpStorage(ProviderContainer container) async {
  try {
    final ids = await container.read(libraryRepositoryProvider).allBookIds();
    await container.read(bookFileStoreProvider).cleanUp(ids);
  } catch (error, stack) {
    // Never block the app on cleanup; it runs again on the next launch.
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}

/// The dictionary's CC BY-SA licence on Flutter's licences page (003 FR-034). Read only
/// when that page opens.
void registerDictionaryLicence() => LicenseRegistry.addLicense(() async* {
  final text = await rootBundle.loadString('assets/dictionary/LICENSE.md');
  yield LicenseEntryWithLineBreaks(const ['Potha dictionary (English Wiktionary)'], text);
});
