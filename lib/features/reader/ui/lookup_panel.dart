// The definition panel (003 contracts/lookup-ui.md "Panel", research R7): an overlay at
// the bottom, or at the top when the word is low, at most a third of the view at first,
// draggable to 85%. A swipe toward its edge closes it.
import 'package:flutter/material.dart';

import '../../../core/dictionary/lexicon.dart';
import '../domain/panel_placement.dart';
import '../lookup_controller.dart';

const lookupPanelKey = ValueKey('lookup-panel');
const lookupPanelHandleKey = ValueKey('lookup-panel-handle');

/// The largest share of the view the panel can be dragged to.
const maxPanelFraction = 0.85;

class LookupPanel extends StatefulWidget {
  const LookupPanel({
    super.key,
    required this.state,
    required this.placement,
    required this.viewHeight,
    required this.background,
    required this.foreground,
    required this.onClose,
    this.info,
    this.onAbout,
    this.onSearchOnline,
  });

  final LookupState state;
  final PanelPlacement placement;
  final double viewHeight;
  final Color background;
  final Color foreground;
  final VoidCallback onClose;
  final DictionaryInfo? info;
  final VoidCallback? onAbout;
  final VoidCallback? onSearchOnline;

  @override
  State<LookupPanel> createState() => _LookupPanelState();
}

class _LookupPanelState extends State<LookupPanel> {
  late double _height = widget.placement.height;

  bool get _atTop => widget.placement.edge == PanelEdge.top;

  @override
  void didUpdateWidget(LookupPanel old) {
    super.didUpdateWidget(old);
    if (old.placement != widget.placement) _height = widget.placement.height;
  }

  /// Dragging away from the edge makes it taller; toward the edge, shorter.
  void _drag(DragUpdateDetails d) {
    final grow = _atTop ? d.delta.dy : -d.delta.dy;
    setState(() {
      _height = (_height + grow).clamp(0.0, widget.viewHeight * maxPanelFraction);
    });
  }

  void _dragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final towardEdge = _atTop ? v < -700 : v > 700;
    if (towardEdge || _height < widget.placement.height * 0.6) {
      widget.onClose();
    } else if (_height < widget.placement.height) {
      setState(() => _height = widget.placement.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = widget.foreground;
    final radius = const Radius.circular(16);
    final handle = GestureDetector(
      key: lookupPanelHandleKey,
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _drag,
      onVerticalDragEnd: _dragEnd,
      child: SizedBox(
        height: 20,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: fg.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
    final word = _word(widget.state);
    final content = DefaultTextStyle.merge(
      style: TextStyle(color: fg),
      child: IconTheme.merge(
        data: IconThemeData(color: fg),
        child: _Content(
          state: widget.state,
          foreground: fg,
          info: widget.info,
          onClose: widget.onClose,
          onAbout: widget.onAbout,
          onSearchOnline: widget.onSearchOnline,
          // Drags on the header resize too, like the handle.
          onDrag: _drag,
          onDragEnd: _dragEnd,
        ),
      ),
    );
    return Semantics(
      key: lookupPanelKey,
      container: true,
      explicitChildNodes: true,
      label: word == null ? 'Dictionary' : 'Definition of $word',
      child: Material(
        color: widget.background,
        elevation: 8,
        shadowColor: Colors.black54,
        borderRadius: _atTop
            ? BorderRadius.only(bottomLeft: radius, bottomRight: radius)
            : BorderRadius.only(topLeft: radius, topRight: radius),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: _height,
          child: SafeArea(
            top: _atTop,
            bottom: !_atTop,
            child: Theme(
              data: theme.copyWith(
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: fg),
                ),
              ),
              child: Column(
                children: [
                  if (!_atTop) handle,
                  Expanded(child: content),
                  if (_atTop) handle,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The word the panel is about, for its label and header.
String? _word(LookupState state) => switch (state) {
  LookupShown(:final result) => result.headword ?? result.query.display,
  LookupNotFound(:final result) => _visible(result.query.display),
  LookupPreparing(:final selection) || LookupLoading(:final selection) => selection?.text,
  _ => null,
};

/// Control and private-use characters drawn as a visible replacement (FR-029).
String _visible(String text) => text.replaceAll(RegExp(r'[\x00-\x1F\uE000-\uF8FF]'), '\uFFFD');

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.foreground,
    required this.onClose,
    required this.onDrag,
    required this.onDragEnd,
    this.info,
    this.onAbout,
    this.onSearchOnline,
  });

  final LookupState state;
  final Color foreground;
  final VoidCallback onClose;
  final GestureDragUpdateCallback onDrag;
  final GestureDragEndCallback onDragEnd;
  final DictionaryInfo? info;
  final VoidCallback? onAbout;
  final VoidCallback? onSearchOnline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = foreground.withValues(alpha: 0.75);
    final word = _word(state) ?? '';
    final ipa = switch (state) {
      LookupShown(:final result) => result.sections.first.entry.ipa,
      _ => null,
    };
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: onDrag,
      onVerticalDragEnd: onDragEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: 12,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      word,
                      style: text.headlineSmall?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (ipa != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(ipa, style: text.bodyLarge?.copyWith(color: muted)),
                    ),
                ],
              ),
            ),
            IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: onClose),
          ],
        ),
      ),
    );
    final body = switch (state) {
      LookupShown(:final result) => _entries(context, result, muted),
      LookupNotFound(:final result, :final online) => [
        Text(
          'No definition found for “${_visible(result.phraseNotFound ?? result.query.display)}”',
          style: text.bodyLarge,
        ),
        const SizedBox(height: 12),
        ..._online(context, online, muted),
      ],
      LookupPreparing(:final status) => _preparing(context, status),
      LookupLoading() => [const _Waiting()],
      _ => const <Widget>[],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 12), children: body),
        ),
        if (info != null) _Footer(info: info!, color: muted, onAbout: onAbout),
      ],
    );
  }

  /// The "Search online" offer and its outcome (US6).
  List<Widget> _online(BuildContext context, OnlineSearch online, Color muted) {
    final text = Theme.of(context).textTheme.bodyMedium?.copyWith(color: muted);
    Widget button(String label) => Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.travel_explore),
        label: Text(label),
        onPressed: onSearchOnline,
      ),
    );
    return switch (online) {
      OnlineSearch.available => [button('Search online')],
      OnlineSearch.unavailable => [Text("Online search isn't available offline.", style: text)],
      OnlineSearch.searching => [const LinearProgressIndicator(semanticsLabel: 'Searching online')],
      OnlineSearch.nothingFound => [
        Text('Nothing found online', style: text),
        const SizedBox(height: 8),
        button('Try again'),
      ],
      OnlineSearch.failed => [
        Text("Couldn't reach Wiktionary", style: text),
        const SizedBox(height: 8),
        button('Try again'),
      ],
    };
  }

  List<Widget> _entries(BuildContext context, LookupResult result, Color muted) {
    final text = Theme.of(context).textTheme;
    final first = result.sections.first.entry.headword;
    final out = <Widget>[
      if (result.source == EntrySource.online)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text('From Wiktionary online', style: text.bodyMedium?.copyWith(color: muted)),
        ),
      if (result.phraseNotFound != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            'No entry for “${result.phraseNotFound}”',
            style: text.bodyMedium?.copyWith(color: muted),
          ),
        ),
    ];
    for (final section in result.sections) {
      final e = section.entry;
      if (section.note != null) {
        out.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(section.note!, style: text.bodyMedium?.copyWith(color: muted)),
          ),
        );
      }
      final pos = posLabel(e.pos);
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(
              e.headword == first ? pos : '${e.headword} · $pos',
              style: text.titleSmall?.copyWith(color: foreground, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
      for (var i = 0; i < e.senses.length; i++) {
        out.add(
          _SenseView(
            number: i + 1,
            pos: pos,
            sense: e.senses[i],
            foreground: foreground,
            muted: muted,
          ),
        );
      }
    }
    return out;
  }

  List<Widget> _preparing(BuildContext context, DictionaryStatus status) {
    final text = Theme.of(context).textTheme.bodyLarge;
    return switch (status) {
      DictionaryDownloading(:final fraction) => [
        Text(
          fraction == null
              ? 'Downloading the dictionary…'
              : 'Downloading the dictionary… ${(fraction * 100).round()}%',
          style: text,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: fraction, semanticsLabel: 'Dictionary download'),
      ],
      DictionaryFailed(reason: DictionaryFailure.offline) => [
        Text('The dictionary needs an internet connection once to download.', style: text),
      ],
      DictionaryFailed() => [
        Text("The dictionary couldn't be loaded. Look the word up again to retry.", style: text),
      ],
      _ => [Text('Preparing the dictionary…', style: text), const _Waiting()],
    };
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Center(
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5, semanticsLabel: 'Looking up'),
      ),
    ),
  );
}

class _SenseView extends StatelessWidget {
  const _SenseView({
    required this.number,
    required this.pos,
    required this.sense,
    required this.foreground,
    required this.muted,
  });

  final int number;
  final String pos;
  final Sense sense;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tags = sense.tags.isEmpty ? '' : '${sense.tags.join(', ')} ';
    return Semantics(
      container: true,
      label: '$pos, definition $number: ${sense.tags.isEmpty ? '' : '$tags, '}${sense.gloss}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$number. '),
                  if (tags.isNotEmpty)
                    TextSpan(
                      text: tags,
                      style: TextStyle(
                        color: muted,
                        fontSize: (text.bodySmall?.fontSize ?? 12),
                        letterSpacing: 0.6,
                        fontFeatures: const [FontFeature.enable('smcp')],
                      ),
                    ),
                  TextSpan(text: sense.gloss),
                ],
              ),
              style: text.bodyLarge?.copyWith(color: foreground),
            ),
            for (final x in sense.examples)
              Padding(
                padding: const EdgeInsets.only(left: 18, top: 2),
                child: Text(
                  x,
                  style: text.bodyMedium?.copyWith(color: muted, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.info, required this.color, this.onAbout});

  final DictionaryInfo info;
  final Color color;
  final VoidCallback? onAbout;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Wiktionary · ${info.licence}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
        TextButton(
          onPressed: onAbout,
          child: const Tooltip(message: 'About this dictionary', child: Text('About')),
        ),
      ],
    ),
  );
}

/// Wiktionary's part-of-speech names, as readers know them.
String posLabel(String pos) => switch (pos) {
  'noun' => 'Noun',
  'verb' => 'Verb',
  'adj' => 'Adjective',
  'adv' => 'Adverb',
  'name' => 'Proper noun',
  'phrase' => 'Phrase',
  'prep' => 'Preposition',
  'prep_phrase' => 'Prepositional phrase',
  'intj' => 'Interjection',
  'pron' => 'Pronoun',
  'conj' => 'Conjunction',
  'det' => 'Determiner',
  'article' => 'Article',
  'num' => 'Numeral',
  'particle' => 'Particle',
  'contraction' => 'Contraction',
  'proverb' => 'Proverb',
  'prefix' => 'Prefix',
  'suffix' => 'Suffix',
  'abbrev' => 'Abbreviation',
  'symbol' => 'Symbol',
  _ => pos.isEmpty ? pos : '${pos[0].toUpperCase()}${pos.substring(1).replaceAll('_', ' ')}',
};
