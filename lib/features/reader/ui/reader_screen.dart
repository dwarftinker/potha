// The reading screen (feature 002). Replaces 001's basic page view.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/document/document_format.dart';
import '../../../core/document/pdf/pdf_document_format.dart';
import '../../../core/document/pdf/pdf_document_view.dart';
import '../../../core/secure/password_store.dart';
import '../../../core/storage/book_file_store.dart';
import '../../library/data/library_repository.dart';
import '../../library/ui/password_dialog.dart';
import '../data/reader_repository.dart';
import '../progress_saver.dart';

/// View builders per format id. Overridden in tests.
final documentViewFactoriesProvider = Provider<Map<String, DocumentViewFactory>>(
    (ref) => const {'pdf': PdfDocumentViewFactory()});

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Book? _book;
  ReaderDocument? _doc;
  DocumentViewFactory? _factory;
  DocumentViewController? _view;
  ProgressSaver? _saver;
  String? _error;

  /// Where the view opens; changes only when the view is rebuilt from scratch.
  ReadingPosition _start = const ReadingPosition(1, 0);

  /// The latest position the view reported.
  ReadingPosition _position = const ReadingPosition(1, 0);
  PageMode _mode = PageMode.paged;
  ReaderPreference _prefs =
      const ReaderPreference(id: 1, theme: ReadingTheme.light, fit: PageFit.fitWidth);
  StreamSubscription<ReaderPreference>? _prefsSub;

  // Read once: the saver still writes while the screen is being disposed.
  late final ReaderRepository _repo = ref.read(readerRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _repo;
    _open();
  }

  Future<void> _open() async {
    final library = ref.read(libraryRepositoryProvider);
    final passwords = ref.read(passwordStoreProvider);
    try {
      final book = await library.findById(widget.bookId);
      if (book == null) return _fail('This book is no longer in your library.');
      if (mounted) setState(() => _book = book);

      final file = await ref.read(bookFileStoreProvider).find(book.id);
      if (file == null) {
        return _fail('This book’s file is missing. Remove it from the library and add it again.');
      }
      final format = ref.read(documentFormatsProvider).firstWhere((f) => f.id == book.format);
      final stored = book.isPasswordProtected ? await passwords.read(book.id) : null;

      final doc = await format.open(
        file,
        knownPassword: stored,
        askPassword: ({required retry}) async {
          if (!mounted) return null;
          // A failed stored password counts as a wrong password.
          return showPasswordDialog(context,
              fileName: book.title, retry: retry || stored != null);
        },
      );
      if (!mounted) {
        await doc.close();
        return;
      }
      if (doc.usedPassword != null && doc.usedPassword != stored) {
        await passwords.write(book.id, doc.usedPassword!);
      }
      final saved = await _repo.loadPosition(book.id);
      final mode = await _repo.pageMode(book.id);
      final start = ReadingPosition.clamped(saved?.page ?? 1, saved?.offsetY ?? 0,
          pageCount: doc.pageCount);
      _prefsSub = _repo.watchPreferences().listen((p) {
        if (mounted) setState(() => _prefs = p);
      });
      final factory = ref.read(documentViewFactoriesProvider)[book.format]!;
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() {
        _doc = doc;
        _factory = factory;
        _view = factory.createController();
        _mode = mode;
        _start = _position = start;
        _saver = ProgressSaver(
          pageCount: doc.pageCount,
          save: (p) => _repo.savePosition(book.id, p),
        )
          // The view only reports changes; record the starting position too, so an
          // opened book is never shown as "New" again.
          ..positionChanged(start);
      });
    } on DocumentOpenException catch (e) {
      _fail(e.kind == DocumentOpenFailure.passwordCancelled
          ? 'This book needs its password to open.'
          : 'This book could not be opened. The file may be damaged.');
    } catch (_) {
      _fail('This book could not be opened.');
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  void dispose() {
    _prefsSub?.cancel();
    _saver?.dispose();
    _view?.dispose();
    _doc?.close();
    super.dispose();
  }

  void _onPositionChanged(ReadingPosition position) {
    final pageChanged = position.page != _position.page;
    _position = position;
    _saver?.positionChanged(position);
    if (pageChanged && mounted) setState(() {});
  }

  ReaderViewConfig _config() => ReaderViewConfig(
        mode: _mode,
        fit: _prefs.fit,
        initialPosition: _start,
        onPositionChanged: _onPositionChanged,
      );

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final error = _error;
    if (error != null) return Scaffold(body: _ErrorMessage(message: error));
    if (doc == null) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(semanticsLabel: 'Opening book')));
    }
    return Scaffold(
      body: _factory!.build(doc, controller: _view!, config: _config()),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to library'),
              ),
            ],
          ),
        ),
      );
}
