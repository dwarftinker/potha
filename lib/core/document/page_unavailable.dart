import 'package:flutter/material.dart';

/// Shown in place of a page that can't be rendered (002 FR-037).
class PageUnavailable extends StatelessWidget {
  const PageUnavailable({super.key});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_outlined, color: Color(0xFF616161), size: 40),
                const SizedBox(height: 8),
                Text(
                  "This page can't be shown",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFF424242)),
                ),
              ],
            ),
          ),
        ),
      );
}
