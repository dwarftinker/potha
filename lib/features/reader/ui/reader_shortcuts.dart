// Keys on the reading screen (FR-008, FR-016; contracts/reader-ui.md "Keys").
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NextIntent extends Intent {
  const NextIntent();
}

class PreviousIntent extends Intent {
  const PreviousIntent();
}

class FirstPageIntent extends Intent {
  const FirstPageIntent();
}

class LastPageIntent extends Intent {
  const LastPageIntent();
}

class ScrollStepIntent extends Intent {
  const ScrollStepIntent(this.fraction);
  final double fraction;
}

class ZoomInIntent extends Intent {
  const ZoomInIntent();
}

class ZoomOutIntent extends Intent {
  const ZoomOutIntent();
}

class LeaveReaderIntent extends Intent {
  const LeaveReaderIntent();
}

/// What the keys do; the reader screen supplies the behaviour.
class ReaderKeyHandlers {
  const ReaderKeyHandlers({
    required this.next,
    required this.previous,
    required this.first,
    required this.last,
    required this.scrollStep,
    required this.zoomIn,
    required this.zoomOut,
    required this.leave,
  });

  final VoidCallback next;
  final VoidCallback previous;
  final VoidCallback first;
  final VoidCallback last;
  final ValueChanged<double> scrollStep;
  final VoidCallback zoomIn;
  final VoidCallback zoomOut;
  final VoidCallback leave;
}

/// Scroll step for Up / Down Arrow in continuous mode: a tenth of the view.
const arrowScrollFraction = 0.1;

class ReaderShortcuts extends StatelessWidget {
  const ReaderShortcuts({
    super.key,
    required this.handlers,
    required this.continuous,
    required this.child,
  });

  final ReaderKeyHandlers handlers;

  /// Up / Down Arrow only scroll in continuous mode.
  final bool continuous;
  final Widget child;

  static const _shortcuts = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowRight): NextIntent(),
    SingleActivator(LogicalKeyboardKey.pageDown): NextIntent(),
    SingleActivator(LogicalKeyboardKey.space): NextIntent(),
    SingleActivator(LogicalKeyboardKey.arrowLeft): PreviousIntent(),
    SingleActivator(LogicalKeyboardKey.pageUp): PreviousIntent(),
    SingleActivator(LogicalKeyboardKey.space, shift: true): PreviousIntent(),
    SingleActivator(LogicalKeyboardKey.home): FirstPageIntent(),
    SingleActivator(LogicalKeyboardKey.end): LastPageIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown): ScrollStepIntent(arrowScrollFraction),
    SingleActivator(LogicalKeyboardKey.arrowUp): ScrollStepIntent(-arrowScrollFraction),
    SingleActivator(LogicalKeyboardKey.equal, control: true): ZoomInIntent(),
    SingleActivator(LogicalKeyboardKey.equal, meta: true): ZoomInIntent(),
    SingleActivator(LogicalKeyboardKey.add, control: true): ZoomInIntent(),
    SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): ZoomInIntent(),
    SingleActivator(LogicalKeyboardKey.minus, control: true): ZoomOutIntent(),
    SingleActivator(LogicalKeyboardKey.minus, meta: true): ZoomOutIntent(),
    SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): ZoomOutIntent(),
    SingleActivator(LogicalKeyboardKey.escape): LeaveReaderIntent(),
  };

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: {
            NextIntent: _ReaderAction<NextIntent>((_) => handlers.next()),
            PreviousIntent: _ReaderAction<PreviousIntent>((_) => handlers.previous()),
            FirstPageIntent: _ReaderAction<FirstPageIntent>((_) => handlers.first()),
            LastPageIntent: _ReaderAction<LastPageIntent>((_) => handlers.last()),
            ScrollStepIntent: _ReaderAction<ScrollStepIntent>(
                (i) => handlers.scrollStep(i.fraction),
                enabled: () => continuous),
            ZoomInIntent: _ReaderAction<ZoomInIntent>((_) => handlers.zoomIn()),
            ZoomOutIntent: _ReaderAction<ZoomOutIntent>((_) => handlers.zoomOut()),
            LeaveReaderIntent: _ReaderAction<LeaveReaderIntent>((_) => handlers.leave()),
          },
          child: Focus(autofocus: true, child: child),
        ),
      );
}

/// An action that steps aside while the reader types in a text field (search, Go to
/// page), so Space and the arrows edit the text instead.
class _ReaderAction<T extends Intent> extends Action<T> {
  _ReaderAction(this.onInvoke, {this.enabled});

  final void Function(T intent) onInvoke;
  final bool Function()? enabled;

  @override
  bool isEnabled(T intent) => !_typing() && (enabled?.call() ?? true);

  @override
  Object? invoke(T intent) {
    onInvoke(intent);
    return null;
  }

  static bool _typing() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return false;
    return context.widget is EditableText ||
        context.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}
