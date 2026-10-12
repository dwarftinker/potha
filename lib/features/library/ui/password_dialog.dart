import 'package:flutter/material.dart';

/// Asks for the password of a protected PDF (FR-006). Returns null if cancelled.
Future<String?> showPasswordDialog(BuildContext context,
        {required String fileName, required bool retry}) =>
    showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PasswordDialog(fileName: fileName, retry: retry),
    );

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.fileName, required this.retry});

  final String fileName;
  final bool retry;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Password needed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('“${widget.fileName}” is protected. Enter its password to add it.'),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: widget.retry ? 'Wrong password, try again' : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(textStyle: theme.textTheme.labelLarge),
          child: const Text('Open'),
        ),
      ],
    );
  }
}
