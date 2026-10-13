// Reader settings (FR-005): page mode for this book; fit and theme for all books.
import 'package:flutter/material.dart';

import '../../../core/db/app_database.dart';

class ReaderSettings {
  const ReaderSettings({
    required this.mode,
    required this.fit,
    required this.theme,
    this.tapToDefine = false,
  });

  final PageMode mode;
  final PageFit fit;
  final ReadingTheme theme;

  /// 003 FR-015.
  final bool tapToDefine;
}

/// Shows the settings sheet; each change is applied at once through the callbacks.
Future<void> showReaderSettings(
  BuildContext context, {
  required ReaderSettings initial,
  required ValueChanged<PageMode> onMode,
  ValueChanged<PageFit>? onFit,
  ValueChanged<ReadingTheme>? onTheme,
  ValueChanged<bool>? onTapToDefine,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => _SettingsSheet(
    initial: initial,
    onMode: onMode,
    onFit: onFit,
    onTheme: onTheme,
    onTapToDefine: onTapToDefine,
  ),
);

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({
    required this.initial,
    required this.onMode,
    this.onFit,
    this.onTheme,
    this.onTapToDefine,
  });

  final ReaderSettings initial;
  final ValueChanged<PageMode> onMode;
  final ValueChanged<PageFit>? onFit;
  final ValueChanged<ReadingTheme>? onTheme;
  final ValueChanged<bool>? onTapToDefine;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  late var _mode = widget.initial.mode;
  late var _fit = widget.initial.fit;
  late var _theme = widget.initial.theme;
  late var _tapToDefine = widget.initial.tapToDefine;

  Widget _section(String title, String? note, Widget choice) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        if (note != null) Text(note, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: choice),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _section(
            'Page layout',
            'For this book',
            SegmentedButton<PageMode>(
              segments: const [
                ButtonSegment(value: PageMode.paged, label: Text('Paged')),
                ButtonSegment(value: PageMode.continuous, label: Text('Continuous')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() => _mode = s.single);
                widget.onMode(s.single);
              },
            ),
          ),
          if (widget.onFit != null)
            _section(
              'Page size',
              'For all books',
              SegmentedButton<PageFit>(
                segments: const [
                  ButtonSegment(value: PageFit.fitWidth, label: Text('Fit width')),
                  ButtonSegment(value: PageFit.fitPage, label: Text('Fit page')),
                ],
                selected: {_fit},
                onSelectionChanged: (s) {
                  setState(() => _fit = s.single);
                  widget.onFit!(s.single);
                },
              ),
            ),
          if (widget.onTheme != null)
            _section(
              'Theme',
              'For all books',
              SegmentedButton<ReadingTheme>(
                segments: const [
                  ButtonSegment(value: ReadingTheme.light, label: Text('Light')),
                  ButtonSegment(value: ReadingTheme.dark, label: Text('Dark')),
                  ButtonSegment(value: ReadingTheme.sepia, label: Text('Sepia')),
                ],
                selected: {_theme},
                onSelectionChanged: (s) {
                  setState(() => _theme = s.single);
                  widget.onTheme!(s.single);
                },
              ),
            ),
          if (widget.onTapToDefine != null)
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              title: const Text('Tap to define'),
              subtitle: const Text('Tap a word to look it up'),
              value: _tapToDefine,
              onChanged: (on) {
                setState(() => _tapToDefine = on);
                widget.onTapToDefine!(on);
              },
            ),
        ],
      ),
    ),
  );
}
