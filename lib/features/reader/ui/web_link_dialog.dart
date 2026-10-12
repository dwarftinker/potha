// A link to a website: show the address and open it only if the reader confirms
// (FR-025). Nothing leaves the device without that confirmation.
import 'package:flutter/material.dart';

Future<bool> confirmWebLink(BuildContext context, Uri uri) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open this link?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('It opens in your browser:'),
            const SizedBox(height: 8),
            SelectableText(uri.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Open')),
        ],
      ),
    ) ??
    false;
