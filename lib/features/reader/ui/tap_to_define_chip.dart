// Shows that tap-to-define is on, whether or not the controls are shown (003 FR-017).
// Tapping it offers to turn the mode off.
import 'package:flutter/material.dart';

class TapToDefineChip extends StatelessWidget {
  const TapToDefineChip({super.key, required this.onTurnOff, this.background, this.foreground});

  final VoidCallback onTurnOff;
  final Color? background;
  final Color? foreground;

  Future<void> _ask(BuildContext context) async {
    final off = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Turn off tap to define?'),
        content: const Text(
          'Taps will show and hide the controls again. Long-press still '
          'looks up a word.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (off ?? false) onTurnOff();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Tap to define is on. Turn it off',
    excludeSemantics: true,
    child: ActionChip(
      avatar: Icon(Icons.touch_app, size: 18, color: foreground),
      label: Text('Tap to define', style: TextStyle(color: foreground)),
      backgroundColor: background,
      visualDensity: VisualDensity.compact,
      // At least 48 dp to tap (WCAG / Material).
      materialTapTargetSize: MaterialTapTargetSize.padded,
      onPressed: () => _ask(context),
    ),
  );
}
