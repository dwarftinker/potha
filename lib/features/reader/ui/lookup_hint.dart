// The one-time hint on the first reader open (003 FR-006, research R11).
import 'package:flutter/material.dart';

class LookupHint extends StatelessWidget {
  const LookupHint({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.inverseSurface,
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Long-press a word to look it up (double-click with a mouse). Turn on '
              'Tap to define in settings to look up with one tap.',
              style: TextStyle(color: scheme.onInverseSurface),
            ),
            TextButton(
              onPressed: onDismiss,
              style: TextButton.styleFrom(foregroundColor: scheme.inversePrimary),
              child: const Text('Got it'),
            ),
          ],
        ),
      ),
    );
  }
}
