import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../reader/basic_page_view.dart' deferred as reader;
import '../data/library_repository.dart';
import '../import/import_controller.dart';
import '../import/import_service.dart';
import '../import/import_source.dart';
import '../import/incoming_files.dart';
import 'book_tile.dart';
import 'drop_zone.dart';
import 'empty_state.dart';
import 'import_progress.dart';
import 'import_summary.dart';
import 'password_dialog.dart';
import 'web_storage_notice.dart';

final booksProvider = StreamProvider<List<BookSummary>>(
    (ref) => ref.watch(libraryRepositoryProvider).watchBooks());

/// Open with / Share to is only available on Android and iOS. Overridden in tests.
final incomingFilesEnabledProvider = Provider<bool>((ref) =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS));

/// Picks PDFs with the system file picker. Overridden in tests.
final pickFilesProvider = Provider<Future<List<ImportSource>> Function()>((ref) => () async {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );
      return Future.wait(files.map(ImportSource.fromPlatformFile));
    });

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  void Function()? _stopIncoming;

  @override
  void initState() {
    super.initState();
    if (ref.read(incomingFilesEnabledProvider)) {
      _stopIncoming = listenForIncomingFiles(_import);
    }
  }

  @override
  void dispose() {
    _stopIncoming?.call();
    super.dispose();
  }

  Future<String?> _askPassword(String fileName, {required bool retry}) =>
      showPasswordDialog(context, fileName: fileName, retry: retry);

  void _import(List<ImportSource> sources) => ref
      .read(importControllerProvider.notifier)
      .importSources(sources, askPassword: _askPassword);

  Future<void> _pickAndImport() async {
    try {
      _import(await ref.read(pickFilesProvider)());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Couldn’t open the file picker.')));
    }
  }

  Future<void> _onDrop(List<DropItem> files) async =>
      _import(await Future.wait(files.map(ImportSource.fromXFile)));

  bool _openingReader = false;

  /// Opens a book in the basic page view (FR-016). The reader is a deferred library so
  /// the web library screen loads without it (research R10).
  Future<void> _openBook(String bookId) async {
    unawaited(ref.read(libraryRepositoryProvider).markOpened(bookId));
    setState(() => _openingReader = true);
    try {
      await reader.loadLibrary();
    } finally {
      if (mounted) setState(() => _openingReader = false);
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => reader.buildBasicPageView(bookId)),
    );
  }

  Future<void> _onImportFinished(List<ImportResult> results) async {
    ref.read(importControllerProvider.notifier).clearResults();
    showImportSummary(context, results, onOpen: _openBook);

    final added = results.any((r) => r.outcome == ImportOutcome.added);
    if (added && ref.read(isWebProvider)) {
      final repo = ref.read(libraryRepositoryProvider);
      if (!await repo.webStorageNoticeShown()) {
        if (!mounted) return;
        await showWebStorageNotice(context);
        await repo.markWebStorageNoticeShown();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(importControllerProvider.select((s) => s.results), (_, results) {
      if (results != null) _onImportFinished(results);
    });
    final books = ref.watch(booksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: _openingReader
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, semanticsLabel: 'Opening book'),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Add book',
            icon: const Icon(Icons.add),
            onPressed: _pickAndImport,
          ),
        ],
      ),
      floatingActionButton: (books.value?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: _pickAndImport,
              icon: const Icon(Icons.add),
              label: const Text('Add book'),
            )
          : null,
      bottomNavigationBar: const ImportProgressBar(),
      body: DropZone(
        enabled: ref.watch(isWebProvider),
        onDrop: _onDrop,
        child: books.when(
          data: (list) => list.isEmpty
              ? EmptyLibrary(onAdd: _pickAndImport, isWeb: ref.watch(isWebProvider))
              : _BookGrid(books: list, onOpen: _openBook),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load the library: $e')),
        ),
      ),
    );
  }
}

/// Cover grid; the column count follows the screen width.
class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, required this.onOpen});

  final List<BookSummary> books;
  final void Function(String bookId) onOpen;

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.48,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: books.length,
        itemBuilder: (context, i) => BookTile(
          key: ValueKey(books[i].id),
          book: books[i],
          onTap: () => onOpen(books[i].id),
        ),
      );
}
