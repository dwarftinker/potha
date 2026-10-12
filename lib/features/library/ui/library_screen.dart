import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../reader/reader.dart' deferred as reader;
import '../data/library_repository.dart';
import '../import/import_controller.dart';
import '../import/import_service.dart';
import '../import/import_source.dart';
import '../import/incoming_files.dart';
import 'book_actions.dart';
import 'book_row.dart';
import 'book_tile.dart';
import 'drop_zone.dart';
import 'empty_state.dart';
import 'import_progress.dart';
import 'import_summary.dart';
import 'password_dialog.dart';
import 'web_storage_notice.dart';

final libraryPreferencesProvider = StreamProvider<LibraryPreference>(
    (ref) => ref.watch(libraryRepositoryProvider).watchPreferences());

/// The current library search text (already debounced).
class SearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final searchQueryProvider = NotifierProvider<SearchQuery, String>(SearchQuery.new);

final booksProvider = StreamProvider<List<BookSummary>>((ref) {
  final sort = ref.watch(libraryPreferencesProvider).value?.sortOrder ?? SortOrder.recentlyOpened;
  return ref
      .watch(libraryRepositoryProvider)
      .watchBooks(sort: sort, query: ref.watch(searchQueryProvider));
});

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
  bool _searching = false;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  void _onSearchChanged(String text) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 150),
        () => ref.read(searchQueryProvider.notifier).set(text));
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).set('');
  }

  void _closeSearch() {
    _clearSearch();
    setState(() => _searching = false);
  }

  @override
  void initState() {
    super.initState();
    if (ref.read(incomingFilesEnabledProvider)) {
      _stopIncoming = listenForIncomingFiles(_import);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  /// Opens a book in the reader (FR-016, feature 002). The reader is a deferred library
  /// so the web library screen loads without it (research R10).
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
      MaterialPageRoute<void>(builder: (_) => reader.buildReader(bookId)),
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
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search title or author',
                  border: InputBorder.none,
                ),
              )
            : const Text('Library'),
        bottom: _openingReader
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2, semanticsLabel: 'Opening book'),
              )
            : null,
        actions: [
          if (_searching)
            IconButton(
              tooltip: 'Close search',
              icon: const Icon(Icons.close),
              onPressed: _closeSearch,
            )
          else
            IconButton(
              tooltip: 'Search library',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          _ViewToggle(
            mode: ref.watch(libraryPreferencesProvider).value?.viewMode ?? ViewMode.grid,
            onChanged: (mode) =>
                ref.read(libraryRepositoryProvider).updatePreferences(viewMode: mode),
          ),
          _SortMenu(
            selected: ref.watch(libraryPreferencesProvider).value?.sortOrder ??
                SortOrder.recentlyOpened,
            onSelected: (order) =>
                ref.read(libraryRepositoryProvider).updatePreferences(sortOrder: order),
          ),
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
          data: (list) => switch ((list.isEmpty, ref.watch(searchQueryProvider))) {
            (true, '') => EmptyLibrary(onAdd: _pickAndImport, isWeb: ref.watch(isWebProvider)),
            (true, final query) => _NoMatches(query: query, onClear: _clearSearch),
            _ => ref.watch(libraryPreferencesProvider).value?.viewMode == ViewMode.list
                ? _BookList(books: list, onOpen: _openBook)
                : _BookGrid(books: list, onOpen: _openBook),
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load the library: $e')),
        ),
      ),
    );
  }
}

/// Cover grid; the column count follows the screen width.
class _BookGrid extends ConsumerWidget {
  const _BookGrid({required this.books, required this.onOpen});

  final List<BookSummary> books;
  final void Function(String bookId) onOpen;

  static const _maxTileWidth = 180.0;
  static const _spacing = 8.0;
  static const _padding = 12.0;

  /// Height of a tile's text block (two-line title, author, progress) at the reader's
  /// text size, so tiles grow instead of overflowing (FR-025).
  static double _textHeight(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scaler = MediaQuery.textScalerOf(context);
    double line(TextStyle? style, int lines) {
      final size = style?.fontSize ?? 14;
      return scaler.scale(size) * (style?.height ?? 1.4) * lines;
    }

    return line(t.titleSmall, 2) + line(t.bodySmall, 1) + 2 + line(t.labelSmall, 1);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 2 * _padding;
          final columns = ((width + _spacing) / (_maxTileWidth + _spacing)).ceil().clamp(1, 12);
          final tileWidth = (width - _spacing * (columns - 1)) / columns;
          // Tile padding + cover (2:3) + gap + text, plus a little slack.
          final tileHeight = 12 + (tileWidth - 12) * 3 / 2 + 6 + _textHeight(context) + 8;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(_padding, _padding, _padding, 96),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: tileHeight,
              crossAxisSpacing: _spacing,
              mainAxisSpacing: _spacing,
            ),
            itemCount: books.length,
            itemBuilder: (context, i) => BookTile(
              key: ValueKey(books[i].id),
              book: books[i],
              width: tileWidth,
              onTap: () => onOpen(books[i].id),
              onLongPress: () => showBookActions(context, ref, books[i]),
              menu: BookMenuButton(book: books[i]),
            ),
          );
        },
      );
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.selected, required this.onSelected});

  final SortOrder selected;
  final ValueChanged<SortOrder> onSelected;

  static const _labels = {
    SortOrder.recentlyOpened: 'Recently opened',
    SortOrder.recentlyAdded: 'Recently added',
    SortOrder.title: 'Title',
  };

  @override
  Widget build(BuildContext context) => PopupMenuButton<SortOrder>(
        tooltip: 'Sort',
        icon: const Icon(Icons.sort),
        initialValue: selected,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final entry in _labels.entries)
            CheckedPopupMenuItem(
              value: entry.key,
              checked: entry.key == selected,
              child: Text(entry.value),
            ),
        ],
      );
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No books match “$query”',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextButton(onPressed: onClear, child: const Text('Clear search')),
            ],
          ),
        ),
      );
}

/// Compact list of books (FR-022).
class _BookList extends ConsumerWidget {
  const _BookList({required this.books, required this.onOpen});

  final List<BookSummary> books;
  final void Function(String bookId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: books.length,
        itemBuilder: (context, i) => BookRow(
          key: ValueKey(books[i].id),
          book: books[i],
          onTap: () => onOpen(books[i].id),
          onLongPress: () => showBookActions(context, ref, books[i]),
          menu: BookMenuButton(book: books[i]),
        ),
      );
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.mode, required this.onChanged});

  final ViewMode mode;
  final ValueChanged<ViewMode> onChanged;

  @override
  Widget build(BuildContext context) => mode == ViewMode.grid
      ? IconButton(
          tooltip: 'Show as list',
          icon: const Icon(Icons.view_list_outlined),
          onPressed: () => onChanged(ViewMode.list),
        )
      : IconButton(
          tooltip: 'Show as grid',
          icon: const Icon(Icons.grid_view_outlined),
          onPressed: () => onChanged(ViewMode.grid),
        );
}
