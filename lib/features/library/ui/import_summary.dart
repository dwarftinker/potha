import 'package:flutter/material.dart';

import '../import/import_service.dart';

/// Human-readable reason for a failed import.
String failureMessage(ImportFailure failure) => switch (failure) {
      ImportFailure.notAPdf => 'This file is not a PDF.',
      ImportFailure.damaged => 'This PDF is damaged and can’t be opened.',
      ImportFailure.passwordCancelled => 'No password was entered.',
      ImportFailure.tooLargeForWeb =>
        'Too large for the web version (max 100 MB). Open it in the Potha mobile app.',
      ImportFailure.storageFull => 'There isn’t enough storage space left.',
      ImportFailure.cancelled => 'Cancelled.',
      ImportFailure.unknown => 'Something went wrong while adding this file.',
    };

/// Shows the outcome of an import (FR-007, FR-009): a snackbar for one file, a sheet
/// listing every file for several.
void showImportSummary(BuildContext context, List<ImportResult> results,
    {required void Function(String bookId) onOpen}) {
  if (results.isEmpty) return;
  if (results.length == 1) {
    final r = results.single;
    if (r.failure == ImportFailure.cancelled) return;
    final (String text, bool canOpen) = switch (r.outcome) {
      ImportOutcome.added => ('Added “${r.title}”', true),
      ImportOutcome.alreadyInLibrary => ('Already in your library', true),
      ImportOutcome.failed => (failureMessage(r.failure!), false),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: canOpen && r.bookId != null
            ? SnackBarAction(label: 'Open', onPressed: () => onOpen(r.bookId!))
            : null,
      ));
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ImportSummarySheet(results: results, onOpen: onOpen),
  );
}

class ImportSummarySheet extends StatelessWidget {
  const ImportSummarySheet({super.key, required this.results, required this.onOpen});

  final List<ImportResult> results;
  final void Function(String bookId) onOpen;

  @override
  Widget build(BuildContext context) {
    final added = results.where((r) => r.outcome == ImportOutcome.added).toList();
    final existing = results.where((r) => r.outcome == ImportOutcome.alreadyInLibrary).toList();
    final failed = results.where((r) => r.outcome == ImportOutcome.failed).toList();
    final theme = Theme.of(context);

    Widget section(String title, List<ImportResult> items, Widget Function(ImportResult) row) =>
        items.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text('$title (${items.length})', style: theme.textTheme.titleSmall),
                  ),
                  for (final r in items) row(r),
                ],
              );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Import finished', style: theme.textTheme.titleLarge),
            ),
            section('Added', added, (r) => ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(r.title ?? r.fileName),
                )),
            section('Already in your library', existing, (r) => ListTile(
                  leading: const Icon(Icons.library_books_outlined),
                  title: Text(r.fileName),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onOpen(r.bookId!);
                    },
                    child: const Text('Open'),
                  ),
                )),
            section('Not added', failed, (r) => ListTile(
                  leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                  title: Text(r.fileName),
                  subtitle: Text(failureMessage(r.failure!)),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
