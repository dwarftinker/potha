// "Back to page N" after a jump (FR-026).
import 'package:flutter/material.dart';

class JumpBackChip extends StatelessWidget {
  const JumpBackChip({super.key, required this.page, required this.onPressed});

  final int page;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(Icons.undo, size: 18),
    label: Text('Back to page $page'),
    onPressed: onPressed,
    elevation: 3,
  );
}
