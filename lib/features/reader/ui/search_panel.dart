// Search in the book (FR-030 to FR-034): a sheet with a field and results that stream
// in, plus a bar for stepping through matches once one is chosen.
import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/text_search.dart';

/// Search state that outlives the sheet, so Next and Previous work after it closes.
class SearchSession extends ChangeNotifier {
  SearchSession(this.search, {required this.currentPage});

  final TextSearch search;

  /// Where a new search starts (FR-031 lists from here).
  int Function() currentPage;

  SearchRun? run;

  /// The chosen match, as an index into run.results.
  int? active;

  /// null until checked; false if sampled pages have no text (FR-034).
  bool? hasText;
  bool searchAnyway = false;

  Future<void> checkText() async {
    if (hasText != null) return;
    hasText = await search.hasText();
    notifyListeners();
  }

  void start(String query) {
    run?.cancel();
    run?.removeListener(notifyListeners);
    active = null;
    final trimmed = query.trim();
    run = trimmed.isEmpty ? null : search.start(trimmed, fromPage: currentPage())
      ?..addListener(notifyListeners);
    notifyListeners();
  }

  void choose(int index) {
    active = index;
    notifyListeners();
  }

  /// Moves to the next or previous match, wrapping around (FR-032).
  void step(int delta) {
    final results = run?.results;
    if (results == null || results.isEmpty || active == null) return;
    active = (active! + delta) % results.length;
    notifyListeners();
  }

  SearchResult? get activeResult {
    final i = active;
    final results = run?.results;
    return i == null || results == null || i >= results.length ? null : results[i];
  }

  void clear() {
    run?.cancel();
    run?.removeListener(notifyListeners);
    run = null;
    active = null;
    notifyListeners();
  }

  @override
  void dispose() {
    run?.cancel();
    run?.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Shows the search sheet; returns the chosen result's index, or null.
Future<int?> showSearchSheet(BuildContext context, SearchSession session) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (context, scroll) => _SearchSheet(session: session, scroll: scroll),
        ),
      ),
    );

class _SearchSheet extends StatefulWidget {
  const _SearchSheet({required this.session, required this.scroll});

  final SearchSession session;
  final ScrollController scroll;

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final _text = TextEditingController(text: widget.session.run?.query ?? '');
  Timer? _typing;

  SearchSession get _s => widget.session;

  @override
  void initState() {
    super.initState();
    _s.checkText();
  }

  @override
  void dispose() {
    _typing?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _changed(String query) {
    _typing?.cancel();
    // Start when typing pauses; a new query cancels the old search (FR-033).
    _typing = Timer(const Duration(milliseconds: 300), () => _s.start(query));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _s,
    builder: (context, _) {
      final theme = Theme.of(context);
      final blocked = _s.hasText == false && !_s.searchAnyway;
      final run = _s.run;
      final results = run?.results ?? const <SearchResult>[];
      final noText = _s.hasText == false && (run == null || (run.isDone && !run.sawText));
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _text,
              autofocus: !blocked,
              enabled: !blocked,
              textInputAction: TextInputAction.search,
              onChanged: _changed,
              onSubmitted: _s.start,
              decoration: const InputDecoration(
                hintText: 'Search in book',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (noText)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Text('This book has no searchable text.', textAlign: TextAlign.center),
                  if (blocked) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        _s.searchAnyway = true;
                        setState(() {});
                      },
                      child: const Text('Search anyway'),
                    ),
                  ],
                ],
              ),
            )
          else if (run != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      run.isDone && results.isEmpty
                          ? 'No matches.'
                          : '${results.length} ${results.length == 1 ? 'match' : 'matches'}',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  if (!run.isDone)
                    const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: 'Searching'),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: widget.scroll,
              itemCount: results.length,
              itemBuilder: (context, i) {
                final r = results[i];
                return ListTile(
                  title: Text('Page ${r.page}'),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: r.snippet.substring(0, r.matchStart)),
                        TextSpan(
                          text: r.snippet.substring(r.matchStart, r.matchStart + r.matchLength),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: r.snippet.substring(r.matchStart + r.matchLength)),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => Navigator.of(context).pop(i),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

/// Shown over the page while a match is chosen: "Match X of Y", Previous, Next, close.
class SearchMatchBar extends StatelessWidget {
  const SearchMatchBar({
    super.key,
    required this.session,
    required this.onStep,
    required this.onClose,
    required this.onOpen,
  });

  final SearchSession session;
  final ValueChanged<int> onStep;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final active = session.active;
      final count = session.run?.results.length ?? 0;
      if (active == null || count == 0) return const SizedBox.shrink();
      return Material(
        elevation: 3,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close search',
                onPressed: onClose,
              ),
              TextButton(
                onPressed: onOpen,
                // Y may still grow while the search runs (FR-032).
                child: Text('Match ${active + 1} of $count'),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_up),
                tooltip: 'Previous match',
                onPressed: () => onStep(-1),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down),
                tooltip: 'Next match',
                onPressed: () => onStep(1),
              ),
            ],
          ),
        ),
      );
    },
  );
}
