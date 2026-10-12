import 'package:flutter/material.dart';

/// One-time notice on the web that books live in this browser's storage (FR-027).
Future<void> showWebStorageNotice(BuildContext context) => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your books stay in this browser'),
        content: const Text(
          'Potha keeps your books in this browser’s storage on this device. '
          'If you clear this site’s data in your browser settings, your library '
          'and reading progress will be removed.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
