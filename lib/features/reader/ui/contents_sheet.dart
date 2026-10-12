// Table of contents (FR-024).
import 'package:flutter/material.dart';

import '../../../core/document/document_format.dart';
import '../domain/outline.dart';

/// Shows the contents; returns the chosen page, or null.
Future<int?> showContentsSheet(
  BuildContext context, {
  required Future<List<OutlineEntry>> outline,
  required int currentPage,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.7,
    maxChildSize: 0.95,
    builder: (context, scroll) => FutureBuilder<List<OutlineEntry>>(
      future: outline,
      builder: (context, snapshot) {
        final entries = snapshot.data;
        if (entries == null) {
          return const Center(child: CircularProgressIndicator(semanticsLabel: 'Loading contents'));
        }
        if (entries.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('This book has no table of contents.', textAlign: TextAlign.center),
            ),
          );
        }
        final current = currentChapter(entries, currentPage);
        final rows = <(OutlineEntry, int)>[];
        void flatten(List<OutlineEntry> list, int depth) {
          for (final e in list) {
            rows.add((e, depth));
            flatten(e.children, depth + 1);
          }
        }

        flatten(entries, 0);
        return ListView.builder(
          controller: scroll,
          itemCount: rows.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text('Contents', style: Theme.of(context).textTheme.titleLarge),
              );
            }
            final (entry, depth) = rows[i - 1];
            final isCurrent = identical(entry, current);
            final page = entry.page;
            return Semantics(
              label:
                  '${entry.title}, page ${page ?? 'unknown'}'
                  '${isCurrent ? ', current chapter' : ''}',
              excludeSemantics: true,
              button: page != null,
              child: ListTile(
                contentPadding: EdgeInsets.only(left: 24.0 + depth * 20, right: 24),
                selected: isCurrent,
                enabled: page != null,
                leading: isCurrent ? const Icon(Icons.bookmark) : null,
                title: Text(
                  entry.title.isEmpty ? 'Untitled' : entry.title,
                  style: depth == 0 ? const TextStyle(fontWeight: FontWeight.w600) : null,
                ),
                trailing: page == null ? null : Text('$page'),
                onTap: page == null ? null : () => Navigator.of(context).pop(page),
              ),
            );
          },
        );
      },
    ),
  ),
);
