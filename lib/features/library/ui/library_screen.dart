import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';

final booksProvider = StreamProvider<List<BookSummary>>(
    (ref) => ref.watch(libraryRepositoryProvider).watchBooks());

/// Placeholder list; replaced by the cover grid in user story 2.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final books = ref.watch(booksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: books.when(
        data: (list) => ListView(
          children: [for (final b in list) ListTile(title: Text(b.title))],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load the library: $e')),
      ),
    );
  }
}
