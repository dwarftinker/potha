import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/library_repository.dart';

/// Cover bytes for one book, loaded on demand and dropped when off screen.
final coverProvider = FutureProvider.autoDispose.family<Uint8List?, String>(
  (ref, bookId) => ref.watch(libraryRepositoryProvider).cover(bookId),
);

/// A book's cover image, or a placeholder with its title (FR-012).
class BookCover extends ConsumerWidget {
  const BookCover({
    super.key,
    required this.bookId,
    required this.title,
    required this.hasCover,
    required this.width,
  });

  final String bookId;
  final String title;
  final bool hasCover;

  /// Width the cover is drawn at, in logical pixels; images are decoded at this size.
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!hasCover) return CoverPlaceholder(title: title);
    final bytes = ref.watch(coverProvider(bookId)).value;
    if (bytes == null) return const _CoverBackground();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => CoverPlaceholder(title: title),
    );
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground();

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest);
}

/// The title on a tinted card, for books without a usable cover.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          child: ExcludeSemantics(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 6,
              overflow: TextOverflow.fade,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: scheme.onSecondaryContainer),
            ),
          ),
        ),
      ),
    );
  }
}
