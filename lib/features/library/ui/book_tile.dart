import 'package:flutter/material.dart';

import '../data/library_repository.dart';
import 'book_cover.dart';

/// Screen-reader label for a book: title, "by" author, and progress.
String bookSemanticsLabel(BookSummary book) => [
      book.title,
      if (book.author != null) 'by ${book.author}',
      book.progressLabel,
    ].join(', ');

/// One book in the cover grid.
class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.onTap, this.menu});

  final BookSummary book;
  final VoidCallback? onTap;

  /// Optional trailing menu (e.g. remove), added by later stories.
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: bookSemanticsLabel(book),
      button: onTap != null,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: BookCover(bookId: book.id, title: book.title, hasCover: book.hasCover),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall),
                        if (book.author != null)
                          Text(book.author!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text(book.progressLabel,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                  ?menu,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
