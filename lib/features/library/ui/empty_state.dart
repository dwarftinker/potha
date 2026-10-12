import 'package:flutter/material.dart';

/// Shown when the library has no books (FR-014).
class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({super.key, required this.onAdd, required this.isWeb});

  final VoidCallback onAdd;
  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Your library is empty. Add a PDF to start reading.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (isWeb) ...[
              const SizedBox(height: 4),
              Text('or drag a PDF here',
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add book'),
            ),
          ],
        ),
      ),
    );
  }
}
