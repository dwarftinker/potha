import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/book_file_store.dart';
import 'features/library/data/library_repository.dart';
import 'features/library/import/import_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cleanupDone = Completer<void>();
  final container = ProviderContainer(
    overrides: [startupCleanupProvider.overrideWithValue(cleanupDone.future)],
  );
  // Show the library right away; imports wait until cleanup has finished.
  runApp(UncontrolledProviderScope(container: container, child: const PothaApp()));
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
