import 'package:flutter/material.dart';

import '../data/library_repository.dart';
import 'book_cover.dart';
import 'book_tile.dart';

/// One book in the compact list view (FR-022).
class BookRow extends StatelessWidget {
  const BookRow({super.key, required this.book, this.onTap, this.onLongPress, this.menu});

  final BookSummary book;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            label: bookSemanticsLabel(book),
            button: onTap != null,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: AspectRatio(
                        aspectRatio: 2 / 3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: BookCover(
                              bookId: book.id, title: book.title, hasCover: book.hasCover, width: 48),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium),
                          if (book.author != null)
                            Text(book.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(book.progressLabel,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        ),
        ?menu,
        const SizedBox(width: 4),
      ],
    );
  }
}
