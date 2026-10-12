import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

/// Web drag and drop (FR-003): shows a drop overlay while files are dragged over
/// [child] and hands dropped files to [onDrop].
class DropZone extends StatefulWidget {
  const DropZone({super.key, required this.child, required this.onDrop, this.enabled = true});

  final Widget child;
  final void Function(List<DropItem> files) onDrop;
  final bool enabled;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        widget.onDrop(details.files);
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: Semantics(
                label: 'Drop PDF files to add them',
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.9),
                    border: Border.all(color: scheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_download_outlined, size: 48, color: scheme.onPrimaryContainer),
                      const SizedBox(height: 8),
                      Text('Drop PDF files to add them',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: scheme.onPrimaryContainer)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
