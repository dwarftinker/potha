// The reader's top and bottom bars (FR-002, contracts/reader-ui.md "Controls").
import 'package:flutter/material.dart';

/// Colours for the bars; the reading theme supplies them.
class BarColors {
  const BarColors({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

class ReaderTopBar extends StatelessWidget {
  const ReaderTopBar({
    super.key,
    required this.title,
    required this.colors,
    required this.onBack,
    this.actions = const [],
  });

  final String title;
  final BarColors colors;
  final VoidCallback onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Material(
        color: colors.background,
        elevation: 2,
        child: SafeArea(
          bottom: false,
          child: IconTheme.merge(
            data: IconThemeData(color: colors.foreground),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back to library',
                    onPressed: onBack,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: colors.foreground),
                    ),
                  ),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      );
}

class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.colors,
    required this.onSliderStart,
    required this.onSliderEnd,
    this.onPageLabelTap,
    this.leading = const [],
    this.trailing = const [],
  });

  final int page;
  final int pageCount;
  final BarColors colors;
  final VoidCallback onSliderStart;

  /// The page chosen with the slider (FR-022: jump on release only).
  final ValueChanged<int> onSliderEnd;
  final VoidCallback? onPageLabelTap;
  final List<Widget> leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      'Page $page of $pageCount',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.foreground),
    );
    return Material(
      color: colors.background,
      elevation: 2,
      child: SafeArea(
        top: false,
        child: IconTheme.merge(
          data: IconThemeData(color: colors.foreground),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pageCount > 1)
                  PageSlider(
                    page: page,
                    pageCount: pageCount,
                    color: colors.foreground,
                    onStart: onSliderStart,
                    onEnd: onSliderEnd,
                  ),
                Row(
                  children: [
                    ...leading,
                    Expanded(
                      child: Center(
                        child: onPageLabelTap == null
                            ? label
                            : TextButton(
                                onPressed: onPageLabelTap,
                                style: TextButton.styleFrom(foregroundColor: colors.foreground),
                                child: label,
                              ),
                      ),
                    ),
                    ...trailing,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The page slider: shows the target page while dragging and reports it on release.
class PageSlider extends StatefulWidget {
  const PageSlider({
    super.key,
    required this.page,
    required this.pageCount,
    required this.color,
    required this.onStart,
    required this.onEnd,
  });

  final int page;
  final int pageCount;
  final Color color;
  final VoidCallback onStart;
  final ValueChanged<int> onEnd;

  @override
  State<PageSlider> createState() => _PageSliderState();
}

class _PageSliderState extends State<PageSlider> {
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final value = (_dragging ?? widget.page.toDouble()).clamp(1.0, widget.pageCount.toDouble());
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: widget.color,
        thumbColor: widget.color,
        inactiveTrackColor: widget.color.withValues(alpha: 0.3),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      child: Slider(
        value: value,
        min: 1,
        max: widget.pageCount.toDouble(),
        divisions: widget.pageCount - 1,
        label: 'Page ${value.round()}',
        semanticFormatterCallback: (v) => 'Page ${v.round()} of ${widget.pageCount}',
        onChangeStart: (v) {
          widget.onStart();
          setState(() => _dragging = v);
        },
        onChanged: (v) => setState(() => _dragging = v),
        onChangeEnd: (v) {
          setState(() => _dragging = null);
          widget.onEnd(v.round());
        },
      ),
    );
  }
}
