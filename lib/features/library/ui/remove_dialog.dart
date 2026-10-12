import 'package:flutter/material.dart';

/// Asks before removing a book (FR-020). Returns true if the reader confirmed.
Future<bool> confirmRemoveBook(BuildContext context, String title) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        title: const Text('Remove book?'),
        content: Text('Remove “$title”? This deletes Potha’s copy and your reading progress. '
            'The original file is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
