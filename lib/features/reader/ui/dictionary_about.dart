// "About this dictionary" (003 FR-034, research R12): source, dump date and licence,
// with links that open only after the reader confirms (002 FR-025).
import 'package:flutter/material.dart';

import '../../../core/dictionary/lexicon.dart';

Future<void> showDictionaryAbout(
  BuildContext context,
  DictionaryInfo info, {
  required Future<void> Function(Uri uri) openLink,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('About this dictionary'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.source, style: text.bodyLarge),
            const SizedBox(height: 8),
            if (info.dumpDate.isNotEmpty) Text('Wiktionary dump of ${info.dumpDate}.'),
            const SizedBox(height: 8),
            Text(
              'Definitions are from Wiktionary, available under ${info.licence}. This '
              'dictionary is an adapted version and is shared under the same licence.',
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => openLink(Uri.parse(info.licenceUrl)),
              child: Text('Licence: ${info.licence}'),
            ),
            TextButton(
              onPressed: () => openLink(Uri.parse(info.sourceUrl)),
              child: const Text('Source: Wiktionary'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  },
);
