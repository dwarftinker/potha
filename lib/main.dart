import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/storage/book_file_store.dart';
import 'features/library/data/library_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await cleanUpStorage(container);
  runApp(UncontrolledProviderScope(container: container, child: const PothaApp()));
}

/// Removes leftovers of interrupted imports and files of books no longer in the
/// database (research R4), so nothing partial is ever shown.
Future<void> cleanUpStorage(ProviderContainer container) async {
  try {
    final ids = await container.read(libraryRepositoryProvider).allBookIds();
    await container.read(bookFileStoreProvider).cleanUp(ids);
  } catch (error, stack) {
    // Never block the library on cleanup; it runs again on the next launch.
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  }
}
