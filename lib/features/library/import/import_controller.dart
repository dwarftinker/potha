// Runs imports for the UI and exposes their progress (FR-008, FR-009).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/document/pdf/pdf_document_format.dart';
import '../../../core/secure/password_store.dart';
import '../../../core/storage/book_file_store.dart';
import '../data/library_repository.dart';
import 'import_service.dart';
import 'import_source.dart';

/// Whether the app runs in a browser. Overridden in tests.
final isWebProvider = Provider<bool>((ref) => kIsWeb);

/// Completes when startup storage cleanup has finished; imports wait for it so cleanup
/// never removes a file that is being imported.
final startupCleanupProvider = Provider<Future<void>>((ref) => Future<void>.value());

final importServiceProvider = Provider<ImportService>((ref) => ImportService(
      formats: ref.watch(documentFormatsProvider),
      store: ref.watch(bookFileStoreProvider),
      passwords: ref.watch(passwordStoreProvider),
      repository: ref.watch(libraryRepositoryProvider),
      isWeb: ref.watch(isWebProvider),
    ));

@immutable
class ImportState {
  const ImportState({
    this.running = false,
    this.showProgress = false,
    this.fileName,
    this.index = 0,
    this.total = 0,
    this.fraction,
    this.results,
    this.waitingForPassword = false,
  });

  final bool running;

  /// True once the current import has run for more than [ImportController.progressDelay].
  final bool showProgress;
  final String? fileName;
  final int index;
  final int total;
  final double? fraction;

  /// Results of the last finished batch, until the UI has shown them.
  final List<ImportResult>? results;

  /// The user is being asked for a password; progress is hidden meanwhile.
  final bool waitingForPassword;

  ImportState copyWith({
    bool? running,
    bool? showProgress,
    String? fileName,
    int? index,
    int? total,
    double? fraction,
    List<ImportResult>? results,
    bool clearResults = false,
    bool? waitingForPassword,
  }) =>
      ImportState(
        running: running ?? this.running,
        showProgress: showProgress ?? this.showProgress,
        fileName: fileName ?? this.fileName,
        index: index ?? this.index,
        total: total ?? this.total,
        fraction: fraction ?? this.fraction,
        results: clearResults ? null : (results ?? this.results),
        waitingForPassword: waitingForPassword ?? this.waitingForPassword,
      );
}

class ImportController extends Notifier<ImportState> {
  /// FR-008: progress and Cancel appear only for imports longer than this.
  static const progressDelay = Duration(seconds: 1);

  Timer? _progressTimer;
  final _queue = <(List<ImportSource>, AskImportPassword)>[];

  @override
  ImportState build() {
    ref.onDispose(() => _progressTimer?.cancel());
    return const ImportState();
  }

  /// Imports [sources]. If an import is already running, these run after it.
  Future<void> importSources(List<ImportSource> sources,
      {required AskImportPassword askPassword}) async {
    if (sources.isEmpty) return;
    _queue.add((sources, askPassword));
    if (state.running) return;
    while (_queue.isNotEmpty) {
      final (batch, ask) = _queue.removeAt(0);
      await _run(batch, ask);
    }
  }

  Future<void> _run(List<ImportSource> sources, AskImportPassword askPassword) async {
    await ref.read(startupCleanupProvider);
    final service = ref.read(importServiceProvider);
    if (ref.read(isWebProvider)) unawaited(ref.read(bookFileStoreProvider).requestPersistence());

    state = ImportState(running: true, total: sources.length, fileName: sources.first.name);
    _progressTimer?.cancel();
    _progressTimer = Timer(progressDelay, () {
      if (state.running) state = state.copyWith(showProgress: true);
    });

    Future<String?> ask(String fileName, {required bool retry}) async {
      state = state.copyWith(waitingForPassword: true);
      try {
        return await askPassword(fileName, retry: retry);
      } finally {
        state = state.copyWith(waitingForPassword: false);
      }
    }

    await for (final event in service.importFiles(sources, askPassword: ask)) {
      switch (event) {
        case ImportStarted(:final index, :final total, :final fileName):
          state = ImportState(
            running: true,
            showProgress: state.showProgress,
            fileName: fileName,
            index: index,
            total: total,
          );
        case ImportProgress(:final fraction):
          state = state.copyWith(fraction: fraction);
        case ImportFinished(:final results):
          _progressTimer?.cancel();
          state = ImportState(results: results);
      }
    }
  }

  void cancel() => ref.read(importServiceProvider).cancel();

  /// Called by the UI after it has shown the results.
  void clearResults() => state = state.copyWith(clearResults: true);
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
