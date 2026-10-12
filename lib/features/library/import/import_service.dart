// Imports books one file at a time (contracts/storage-and-import.md, research R4/R5).
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';

import '../../../core/db/app_database.dart';
import '../../../core/document/document_format.dart';
import '../../../core/secure/password_store.dart';
import '../../../core/storage/book_file_store.dart';
import '../data/library_repository.dart';
import '../domain/text_fold.dart';
import '../domain/title_resolver.dart';
import 'import_source.dart';

enum ImportOutcome { added, alreadyInLibrary, failed }

enum ImportFailure {
  notAPdf,
  damaged,
  passwordCancelled,
  tooLargeForWeb,
  storageFull,
  cancelled,
  unknown,
}

@immutable
class ImportResult {
  const ImportResult({
    required this.fileName,
    required this.outcome,
    this.bookId,
    this.title,
    this.failure,
  });

  final String fileName;
  final ImportOutcome outcome;

  /// The new book, or the existing one for [ImportOutcome.alreadyInLibrary].
  final String? bookId;
  final String? title;
  final ImportFailure? failure;

  @override
  String toString() => 'ImportResult($fileName, $outcome, $bookId, $failure)';
}

sealed class ImportEvent {
  const ImportEvent();
}

class ImportStarted extends ImportEvent {
  const ImportStarted(this.index, this.total, this.fileName);
  final int index;
  final int total;
  final String fileName;
}

class ImportProgress extends ImportEvent {
  const ImportProgress(this.index, this.written, this.totalBytes);
  final int index;
  final int written;
  final int? totalBytes;

  double? get fraction =>
      totalBytes == null || totalBytes == 0 ? null : (written / totalBytes!).clamp(0, 1);
}

class ImportFinished extends ImportEvent {
  const ImportFinished(this.results);
  final List<ImportResult> results;
}

/// Asks for the password of [fileName]; null means the user cancelled.
typedef AskImportPassword = Future<String?> Function(String fileName, {required bool retry});

class ImportService {
  ImportService({
    required this.formats,
    required this.store,
    required this.passwords,
    required this.repository,
    required this.isWeb,
    DateTime Function()? clock,
    String Function(DateTime)? formatDate,
    String Function()? newId,
  })  : _clock = clock ?? DateTime.now,
        _formatDate = formatDate ?? _isoDate,
        _newId = newId ?? uuidV4;

  /// FR-008a: 100 MB.
  static const webSizeLimit = 104857600;
  static const coverWidth = 360;

  final List<DocumentFormat> formats;
  final BookFileStore store;
  final PasswordStore passwords;
  final LibraryRepository repository;
  final bool isWeb;
  final DateTime Function() _clock;
  final String Function(DateTime) _formatDate;
  final String Function() _newId;

  Completer<void>? _cancel;

  /// Imports [files] one after another. A failure in one does not stop the rest. The
  /// last event is always [ImportFinished] with one result per file, in order.
  Stream<ImportEvent> importFiles(List<ImportSource> files,
      {required AskImportPassword askPassword}) {
    final controller = StreamController<ImportEvent>();
    final cancel = _cancel = Completer<void>();
    () async {
      final results = <ImportResult>[];
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        if (cancel.isCompleted) {
          results.add(_failed(file.name, ImportFailure.cancelled));
          continue;
        }
        controller.add(ImportStarted(i, files.length, file.name));
        results.add(await _importOne(
          file,
          cancel: cancel,
          askPassword: askPassword,
          onProgress: (written) => controller.add(ImportProgress(i, written, file.size)),
        ));
      }
      controller.add(ImportFinished(results));
      await controller.close();
    }();
    return controller.stream;
  }

  /// Cancels the file being imported and skips the rest of the batch.
  void cancel() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  static ImportResult _failed(String name, ImportFailure failure) =>
      ImportResult(fileName: name, outcome: ImportOutcome.failed, failure: failure);

  Future<ImportResult> _importOne(
    ImportSource file, {
    required Completer<void> cancel,
    required AskImportPassword askPassword,
    required void Function(int) onProgress,
  }) async {
    // Rule 1: web size limit, before any copying.
    if (isWeb && file.size != null && file.size! > webSizeLimit) {
      return _failed(file.name, ImportFailure.tooLargeForWeb);
    }

    // Copy into staging while hashing and checking the header and size.
    final digest = _DigestSink();
    final hasher = sha256.startChunkedConversion(digest);
    final header = BytesBuilder(copy: false);
    DocumentFormat? format;
    var total = 0;

    void checkHeader() {
      final bytes = header.toBytes();
      format = formats.where((f) => f.sniff(bytes)).firstOrNull;
      if (format == null) throw const _NotADocument();
    }

    final checked = file.openRead().transform(
          StreamTransformer<List<int>, List<int>>.fromHandlers(
            handleData: (chunk, sink) {
              total += chunk.length;
              if (isWeb && total > webSizeLimit) {
                sink.addError(const _TooLarge());
                return;
              }
              if (format == null && header.length < 1024) {
                header.add(chunk.length > 1024 ? chunk.sublist(0, 1024) : chunk);
                if (header.length >= 1024) {
                  try {
                    checkHeader();
                  } catch (e) {
                    sink.addError(e);
                    return;
                  }
                }
              }
              hasher.add(chunk);
              sink.add(chunk);
            },
            handleDone: (sink) {
              if (format == null) {
                try {
                  checkHeader();
                } catch (e) {
                  sink.addError(e);
                }
              }
              sink.close();
            },
          ),
        );

    final StagedFile staged;
    try {
      staged = await store.stage(checked,
          totalBytes: file.size, onProgress: onProgress, cancel: cancel.future);
    } on StagingCancelledException {
      return _failed(file.name, ImportFailure.cancelled);
    } on _NotADocument {
      return _failed(file.name, ImportFailure.notAPdf);
    } on _TooLarge {
      return _failed(file.name, ImportFailure.tooLargeForWeb);
    } on StorageFullException {
      return _failed(file.name, ImportFailure.storageFull);
    } catch (_) {
      return _failed(file.name, ImportFailure.unknown);
    }
    hasher.close();
    final hash = digest.value.toString();

    var committed = false;
    ReaderDocument? doc;
    try {
      if (cancel.isCompleted) return _failed(file.name, ImportFailure.cancelled);

      // Rule 3: duplicates by content.
      final existing = await repository.findByHash(hash);
      if (existing != null) {
        return ImportResult(
          fileName: file.name,
          outcome: ImportOutcome.alreadyInLibrary,
          bookId: existing.id,
          title: existing.title,
        );
      }

      try {
        doc = await format!.open(staged.ref,
            askPassword: ({required retry}) => askPassword(file.name, retry: retry));
      } on DocumentOpenException catch (e) {
        return _failed(file.name, switch (e.kind) {
          DocumentOpenFailure.passwordCancelled => ImportFailure.passwordCancelled,
          DocumentOpenFailure.damaged => ImportFailure.damaged,
          DocumentOpenFailure.unsupported => ImportFailure.notAPdf,
        });
      }
      if (cancel.isCompleted) return _failed(file.name, ImportFailure.cancelled);

      final metadata = await doc.readMetadata();
      final cover = await doc.renderPagePng(1, width: coverWidth);
      final now = _clock().toUtc();
      final id = _newId();
      final title = resolveTitle(
        metadataTitle: metadata.title,
        fileName: file.name,
        addedAt: now.toLocal(),
        formatDate: _formatDate,
      );
      final usedPassword = doc.usedPassword;

      // Rule 4: one transaction; the file move happens inside it.
      await repository.insertBook(
        BooksCompanion.insert(
          id: id,
          format: format!.id,
          title: title,
          author: Value(metadata.author),
          sortTitle: sortTitle(title),
          searchKey: searchKey(title, metadata.author),
          originalFileName: file.name,
          contentHash: hash,
          sizeBytes: staged.ref.sizeBytes,
          pageCount: doc.pageCount,
          isPasswordProtected: usedPassword != null,
          addedAt: now,
        ),
        cover: cover,
        beforeCommit: () => store.commit(staged, id),
      );
      committed = true;
      if (usedPassword != null) await passwords.write(id, usedPassword);
      return ImportResult(
          fileName: file.name, outcome: ImportOutcome.added, bookId: id, title: title);
    } on StorageFullException {
      return _failed(file.name, ImportFailure.storageFull);
    } catch (_) {
      return _failed(file.name, ImportFailure.unknown);
    } finally {
      await doc?.close();
      if (!committed) await store.discard(staged); // Rule 5
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _NotADocument implements Exception {
  const _NotADocument();
}

class _TooLarge implements Exception {
  const _TooLarge();
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

final _secureRandom = Random.secure();

/// Random UUID version 4.
String uuidV4() {
  final b = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-'
      '${h.substring(16, 20)}-${h.substring(20)}';
}
