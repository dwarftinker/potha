import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/import_controller.dart';

/// Progress bar with Cancel, shown only after an import has run for 1 s (FR-008).
class ImportProgressBar extends ConsumerWidget {
  const ImportProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importControllerProvider);
    if (!state.running || !state.showProgress || state.waitingForPassword) {
      return const SizedBox.shrink();
    }
    final count = state.total > 1 ? ' (${state.index + 1} of ${state.total})' : '';
    return Material(
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Adding “${state.fileName ?? ''}”$count',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: state.fraction,
                      semanticsLabel: 'Import progress',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: ref.read(importControllerProvider.notifier).cancel,
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
