// Per-book actions, from the overflow menu or a long-press.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';
import 'remove_dialog.dart';

enum _BookAction { remove }

Future<void> _run(BuildContext context, WidgetRef ref, BookSummary book, _BookAction action) async {
  switch (action) {
    case _BookAction.remove:
      if (await confirmRemoveBook(context, book.title)) {
        await ref.read(libraryRepositoryProvider).remove(book.id);
      }
  }
}

/// The ⋮ button on a book. Built from an InkResponse rather than a PopupMenuButton:
/// one is built per tile while scrolling, and the Material button's tooltip, focus
/// and theme layers made new grid rows miss the frame budget (SC-003).
class BookMenuButton extends ConsumerWidget {
  const BookMenuButton({super.key, required this.book});

  final BookSummary book;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final button = context.findRenderObject()! as RenderBox;
    final overlay = Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final topLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final action = await showMenu<_BookAction>(
      context: context,
      position: RelativeRect.fromRect(topLeft & button.size, Offset.zero & overlay.size),
      items: const [
        PopupMenuItem(
          value: _BookAction.remove,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Remove from library'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
    if (action != null && context.mounted) await _run(context, ref, book, action);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
        container: true,
        button: true,
        label: 'More options for ${book.title}',
        onTap: () => _open(context, ref),
        excludeSemantics: true,
        child: InkResponse(
          onTap: () => _open(context, ref),
          radius: 20,
          child: const SizedBox.square(dimension: 48, child: Icon(Icons.more_vert)),
        ),
      );
}

/// The same actions as a bottom sheet, for long-press.
Future<void> showBookActions(BuildContext context, WidgetRef ref, BookSummary book) async {
  final action = await showModalBottomSheet<_BookAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(book.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Remove from library'),
            onTap: () => Navigator.of(context).pop(_BookAction.remove),
          ),
        ],
      ),
    ),
  );
  if (action != null && context.mounted) await _run(context, ref, book, action);
}
