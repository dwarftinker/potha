// The basic page view (FR-016a/b). Loaded as a deferred library on the web (R10).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';
import '../../core/document/document_format.dart';
import '../../core/document/pdf/pdf_document_format.dart';
import '../../core/document/pdf/pdf_document_view.dart';
import '../../core/secure/password_store.dart';
import '../../core/storage/book_file_store.dart';
import '../library/data/library_repository.dart';
import '../library/ui/password_dialog.dart';
import 'progress_saver.dart';

/// View builders per format id. Overridden in tests.
final documentViewFactoriesProvider = Provider<Map<String, DocumentViewFactory>>(
    (ref) => const {'pdf': PdfDocumentViewFactory()});

Widget buildBasicPageView(String bookId) => BasicPageView(bookId: bookId);

class BasicPageView extends ConsumerStatefulWidget {
  const BasicPageView({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<BasicPageView> createState() => _BasicPageViewState();
}

class _BasicPageViewState extends ConsumerState<BasicPageView> {
  Book? _book;
  ReaderDocument? _doc;
  ProgressSaver? _saver;
  int _page = 1;
  int _initialPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final repo = ref.read(libraryRepositoryProvider);
    final passwords = ref.read(passwordStoreProvider);
    try {
      final book = await repo.findById(widget.bookId);
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
      final page = ((await repo.currentPage(book.id)) ?? 1).clamp(1, doc.pageCount);
      setState(() {
        _doc = doc;
        _initialPage = page;
        _page = page;
        _saver = ProgressSaver(
          pageCount: doc.pageCount,
          save: (p) => repo.saveProgress(book.id, p),
        )
          // The viewer only reports changes; record the starting page too, so an opened
          // book is never shown as "New" again.
          ..pageChanged(page);
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
    _saver?.dispose();
    _doc?.close();
    super.dispose();
  }

  void _onPageChanged(int page) {
    _saver?.pageChanged(page);
    if (mounted && page != _page) setState(() => _page = page);
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final book = _book;
    return Scaffold(
      appBar: AppBar(
        title: Text(book?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (doc != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('Page $_page of ${doc.pageCount}')),
            ),
        ],
      ),
      body: switch ((doc, _error)) {
        (_, final String error) => _ErrorMessage(message: error),
        (final ReaderDocument doc, _) => ref
            .watch(documentViewFactoriesProvider)[book!.format]!
            .build(doc, initialPage: _initialPage, onPageChanged: _onPageChanged),
        _ => const Center(child: CircularProgressIndicator(semanticsLabel: 'Opening book')),
      },
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
