// The lookup history sheet (003 US8, contracts/lookup-ui.md "History sheet"): this book
// or all books, newest first; a row opens its definition; Clear asks first.
import 'package:flutter/material.dart';

import '../data/history_repository.dart';

/// Returns the line chosen, or null.
Future<HistoryLine?> showHistorySheet(
  BuildContext context, {
  required HistoryRepository repo,
  required String bookId,
}) => showModalBottomSheet<HistoryLine>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (context) => FractionallySizedBox(
    heightFactor: 0.75,
    child: DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'This book'),
              Tab(text: 'All books'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _HistoryList(
                  lines: repo.watchBook(bookId),
                  question: 'Clear lookup history for this book?',
                  onClear: () => repo.clearBook(bookId),
                ),
                _HistoryList(
                  lines: repo.watchAll(),
                  question: 'Clear lookup history for all books?',
                  onClear: repo.clearAll,
                  showTitles: true,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);

class _HistoryList extends StatelessWidget {
  const _HistoryList({
    required this.lines,
    required this.question,
    required this.onClear,
    this.showTitles = false,
  });

  final Stream<List<HistoryLine>> lines;
  final String question;
  final Future<void> Function() onClear;
  final bool showTitles;

  Future<void> _confirmClear(BuildContext context) async {
    final clear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (clear ?? false) await onClear();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<HistoryLine>>(
    stream: lines,
    builder: (context, snapshot) {
      final items = snapshot.data;
      if (items == null) return const SizedBox.shrink();
      if (items.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Words you look up will appear here.', textAlign: TextAlign.center),
          ),
        );
      }
      return Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _confirmClear(context), child: const Text('Clear')),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _Row(line: items[i], showTitle: showTitles),
            ),
          ),
        ],
      );
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.line, required this.showTitle});

  final HistoryLine line;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final head = line.headword;
    final details = [
      if (showTitle && line.bookTitle != null) line.bookTitle!,
      'Page ${line.page}',
      formatDay(line.lookedUpAt.toLocal()),
    ].join(' · ');
    return ListTile(
      title: Row(
        children: [
          Flexible(child: Text(line.word, overflow: TextOverflow.ellipsis)),
          if (head != null && head.toLowerCase() != line.word.toLowerCase())
            Flexible(
              child: Text(
                '  → $head',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
        ],
      ),
      subtitle: Text(details),
      trailing: line.count > 1
          ? Semantics(label: 'Looked up ${line.count} times', child: Text('×${line.count}'))
          : null,
      onTap: () => Navigator.of(context).pop(line),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "13 Oct 2026".
String formatDay(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
