// Go to page (FR-023).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/page_number_input.dart';

/// Asks for a page number; null if cancelled.
Future<int?> showGoToPageDialog(BuildContext context, {required int pageCount}) => showDialog<int>(
  context: context,
  builder: (_) => _GoToPageDialog(pageCount: pageCount),
);

class _GoToPageDialog extends StatefulWidget {
  const _GoToPageDialog({required this.pageCount});
  final int pageCount;

  @override
  State<_GoToPageDialog> createState() => _GoToPageDialogState();
}

class _GoToPageDialogState extends State<_GoToPageDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    switch (parsePageNumber(_text.text, widget.pageCount)) {
      case PageNumberOk(:final page):
        Navigator.of(context).pop(page);
      case PageNumberError(:final message):
        setState(() => _error = message);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Go to page'),
    content: TextField(
      controller: _text,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textInputAction: TextInputAction.go,
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(labelText: 'Page (1–${widget.pageCount})', errorText: _error),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
      FilledButton(onPressed: _submit, child: const Text('Go')),
    ],
  );
}
