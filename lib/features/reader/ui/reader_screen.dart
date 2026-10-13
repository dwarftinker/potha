// The reading screen (feature 002). Replaces 001's basic page view.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/dictionary/dictionary_store.dart';
import '../../../core/document/document_format.dart';
import '../../../core/document/pdf/pdf_document_format.dart';
import '../../../core/document/pdf/pdf_document_view.dart';
import '../../../core/platform/keep_awake.dart';
import '../../../core/platform/link_opener.dart';
import '../../../core/secure/password_store.dart';
import '../../../core/storage/book_file_store.dart';
import '../../library/data/library_repository.dart';
import '../../library/ui/password_dialog.dart';
import '../data/page_text_cache.dart';
import '../data/reader_repository.dart';
import '../data/thumbnail_cache.dart';
import '../domain/auto_hide.dart';
import '../domain/jump_back.dart';
import '../domain/panel_placement.dart';
import '../domain/reader_theme.dart';
import '../domain/text_search.dart';
import '../domain/tap_zones.dart';
import '../lookup_controller.dart';
import '../progress_saver.dart';
import 'contents_sheet.dart';
import 'dictionary_about.dart';
import 'go_to_page_dialog.dart';
import 'jump_back_chip.dart';
import 'lookup_hint.dart';
import 'lookup_panel.dart';
import 'reader_bars.dart';
import 'reader_shortcuts.dart';
import 'search_panel.dart';
import 'settings_sheet.dart';
import 'tap_detector.dart';
import 'thumbnails_sheet.dart';
import 'web_link_dialog.dart';

/// View builders per format id. Overridden in tests.
final documentViewFactoriesProvider = Provider<Map<String, DocumentViewFactory>>(
  (ref) => const {'pdf': PdfDocumentViewFactory()},
);

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.bookId});

  final String bookId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  Book? _book;
  ReaderDocument? _doc;
  DocumentViewFactory? _factory;
  DocumentViewController? _view;
  ProgressSaver? _saver;
  String? _error;

  /// Where the view opens; changes only when the view is rebuilt from scratch.
  ReadingPosition _start = const ReadingPosition(1, 0);

  /// The latest position the view reported.
  ReadingPosition _position = const ReadingPosition(1, 0);
  PageMode _mode = PageMode.paged;
  ReaderPreference _prefs = const ReaderPreference(
    id: 1,
    theme: ReadingTheme.light,
    fit: PageFit.fitWidth,
    tapToDefine: false,
    // Until the saved row loads, so the one-time hint never flashes (003 FR-006).
    lookupHintShown: true,
  );
  StreamSubscription<ReaderPreference>? _prefsSub;
  final _controls = AutoHide();
  final _jumpBack = JumpBack();

  /// Links per page, loaded as pages come into view, so a tap can follow one at once.
  final _links = <int, List<DocumentLink>>{};
  Future<List<OutlineEntry>>? _outline;
  SearchSession? _search;
  ThumbnailCache? _thumbnails;

  /// Dictionary lookup (003): page text for hit tests, and the panel's state.
  PageTextCache? _pageText;
  LookupController? _lookup;
  WordSelection? _placedFor;
  PanelPlacement? _placement;

  /// Bars just shown by a mouse click let pointers through for a moment, so the second
  /// click of a double-click on a word under them still reaches the page (FR-001).
  bool _barsSettling = false;
  Timer? _barsSettle;
  PointerDeviceKind? _lastPointerKind;

  /// Loads the visible pages' text once the view has been still for 300 ms, so a
  /// long-press rarely waits for extraction (research R4, R8).
  Timer? _prefetch;
  late final AppLifecycleListener _lifecycle;

  // Read once: the saver still writes while the screen is being disposed.
  late final ReaderRepository _repo = ref.read(readerRepositoryProvider);
  late final KeepAwake _keepAwake = ref.read(keepAwakeProvider);

  /// A context below the reader's theme, for its sheets and dialogs.
  BuildContext? _themed;
  BuildContext get _ui => _themed ?? context;

  @override
  void initState() {
    super.initState();
    _repo;
    // The screen stays on while a book is open in the foreground (FR-029).
    _keepAwake.enable();
    _controls.addListener(_controlsChanged);
    _jumpBack.addListener(_rebuild);
    _setSystemBars(visible: false);
    // A library snackbar ("Book added") would sit over the reader's bottom bar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
    _lifecycle = AppLifecycleListener(
      // The system may end the app while it is in the background (FR-011).
      onHide: () {
        _saver?.flush();
        _keepAwake.disable();
      },
      onPause: () => _saver?.flush(),
      onShow: _keepAwake.enable,
    );
    _open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controls.screenReaderOn = MediaQuery.accessibleNavigationOf(context);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _controlsChanged() {
    _setSystemBars(visible: _controls.visible);
    setState(() {});
  }

  /// On phones and tablets the system bars come and go with the reader's (FR-004).
  void _setSystemBars({required bool visible}) => SystemChrome.setEnabledSystemUIMode(
    visible ? SystemUiMode.edgeToEdge : SystemUiMode.immersiveSticky,
  );

  Future<void> _open() async {
    final library = ref.read(libraryRepositoryProvider);
    final passwords = ref.read(passwordStoreProvider);
    try {
      final book = await library.findById(widget.bookId);
      if (book == null) return _fail('This book is no longer in your library.');
      if (mounted) setState(() => _book = book);

      final file = await ref.read(bookFileStoreProvider).find(book.id);
      if (file == null) {
        return _fail('This book’s file is missing. Remove it from the library and add it again.');
      }
      final format = ref.read(documentFormatsProvider).firstWhere((f) => f.id == book.format);
      final stored = book.isPasswordProtected ? await passwords.read(book.id) : null;

      final doc = await format.open(
        file,
        knownPassword: stored,
        askPassword: ({required retry}) async {
          if (!mounted) return null;
          // A failed stored password counts as a wrong password.
          return showPasswordDialog(context, fileName: book.title, retry: retry || stored != null);
        },
      );
      if (!mounted) {
        await doc.close();
        return;
      }
      if (doc.usedPassword != null && doc.usedPassword != stored) {
        await passwords.write(book.id, doc.usedPassword!);
      }
      final saved = await _repo.loadPosition(book.id);
      final mode = await _repo.pageMode(book.id);
      final start = ReadingPosition.clamped(
        saved?.page ?? 1,
        saved?.offsetY ?? 0,
        pageCount: doc.pageCount,
      );
      _prefsSub = _repo.watchPreferences().listen((p) {
        if (mounted) setState(() => _prefs = p);
      });
      final factory = ref.read(documentViewFactoriesProvider)[book.format]!;
      if (!mounted) {
        await doc.close();
        return;
      }
      setState(() {
        _doc = doc;
        _factory = factory;
        _view = factory.createController();
        _mode = mode;
        _start = _position = start;
        _saver =
            ProgressSaver(pageCount: doc.pageCount, save: (p) => _repo.savePosition(book.id, p))
              // The view only reports changes; record the starting position too, so an
              // opened book is never shown as "New" again.
              ..positionChanged(start);
      });
      _loadLinksNear(start.page);
      _search = SearchSession(TextSearch(doc), currentPage: () => _position.page)
        ..addListener(_rebuild);
      final store = ref.read(dictionaryStoreProvider);
      _pageText = PageTextCache(doc.loadPageText);
      _lookup = LookupController(store: store, pageText: _pageText!)..addListener(_lookupChanged);
      // The web downloads the dictionary on the first book open (FR-022); on mobile the
      // unpack has usually finished by now.
      store.ensureStarted();
      _schedulePrefetch();
    } on DocumentOpenException catch (e) {
      _fail(
        e.kind == DocumentOpenFailure.passwordCancelled
            ? 'This book needs its password to open.'
            : 'This book could not be opened. The file may be damaged.',
      );
    } catch (_) {
      _fail('This book could not be opened.');
    }
  }

  void _fail(String message) {
    if (mounted) setState(() => _error = message);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _barsSettle?.cancel();
    _prefetch?.cancel();
    _keepAwake.disable();
    _jumpBack.dispose();
    _search?.dispose();
    _thumbnails?.dispose();
    _lookup
      ?..removeListener(_lookupChanged)
      ..dispose();
    _controls
      ..removeListener(_controlsChanged)
      ..dispose();
    _setSystemBars(visible: true);
    _prefsSub?.cancel();
    _saver?.dispose();
    _view?.dispose();
    _doc?.close();
    super.dispose();
  }

  void _onPositionChanged(ReadingPosition position) {
    final pageChanged = position.page != _position.page;
    _position = position;
    _saver?.positionChanged(position);
    _schedulePrefetch();
    // A page turn closes the panel (FR-004).
    if (pageChanged && (_lookup?.state.isOpen ?? false)) _lookup!.close();
    if (pageChanged && mounted) {
      setState(() {});
      _loadLinksNear(position.page);
      // FR-040: screen-reader users hear where they are.
      SemanticsService.sendAnnouncement(
        View.of(context),
        'Page ${position.page} of ${_doc!.pageCount}',
        Directionality.of(context),
      );
    }
  }

  void _schedulePrefetch() {
    _prefetch?.cancel();
    _prefetch = Timer(const Duration(milliseconds: 300), () {
      final doc = _doc;
      if (doc == null || !mounted) return;
      final page = _position.page;
      _pageText?.prefetch([page, if (page < doc.pageCount) page + 1]);
    });
  }

  void _loadLinksNear(int page) {
    final doc = _doc;
    if (doc == null) return;
    for (final p in [page, page + 1]) {
      if (p > doc.pageCount || _links.containsKey(p)) continue;
      _links[p] = const [];
      doc.loadLinks(p).then((links) => _links[p] = links);
    }
  }

  void _onTap(Offset global, Offset local, double viewWidth) {
    final view = _view!;
    // With the panel open, a tap outside it closes it (FR-004).
    if (_lookup?.state.isOpen ?? false) {
      _lookup!.close();
      return;
    }
    final point = view.pagePointAt(global);
    final action = classifyTap(
      x: local.dx,
      viewWidth: viewWidth,
      pagePoint: point,
      linksOnPage: point == null ? const [] : _links[point.page] ?? const [],
    );
    switch (action) {
      case ToggleControls():
        _controls.toggle();
        if (_controls.visible && _lastPointerKind == PointerDeviceKind.mouse) {
          _barsSettling = true;
          _barsSettle?.cancel();
          _barsSettle = Timer(const Duration(milliseconds: 300), () {
            if (mounted) setState(() => _barsSettling = false);
          });
        }
      case PreviousPage():
        view.previous();
      case NextPage():
        view.next();
      case FollowLink(:final link):
        _followLink(link);
    }
  }

  /// Long-press, double-click: select the word under [global] and look it up (FR-001).
  void _lookUpAt(Offset global, {bool lock = false}) {
    final view = _view!;
    final point = view.pagePointAt(global);
    if (point == null) return;
    // Pans and zooms stop until the pointer is lifted (research R6).
    if (lock) view.setInteractionLocked(true);
    _lookup?.lookUpAt(point);
  }

  void _lookupChanged() {
    final state = _lookup!.state;
    if (state is LookupNoText) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('This page has no selectable text'),
            duration: Duration(seconds: 3),
          ),
        );
    }
    if (state is LookupShown || state is LookupNotFound) {
      // The hint's job is done once the reader has looked a word up (data-model.md).
      if (!_prefs.lookupHintShown) _repo.markLookupHintShown();
      final word = state is LookupShown ? state.result.headword : null;
      SemanticsService.sendAnnouncement(
        View.of(context),
        word == null ? 'No definition found' : 'Definition of $word',
        Directionality.of(context),
      );
    }
    _rebuild();
  }

  /// Where the panel opens, chosen once per selection (FR-003).
  PanelPlacement _placementFor(LookupState state, Size screen) {
    final selection = state.selection;
    if (_placement != null && identical(_placedFor, selection)) return _placement!;
    Rect? word;
    if (selection != null && selection.rects.isNotEmpty) {
      final union = selection.rects.reduce((a, b) => a.expandToInclude(b));
      word = _view!.pageRectToGlobal(selection.page, union);
    }
    _placedFor = selection;
    return _placement = word == null
        ? (edge: PanelEdge.bottom, height: screen.height / 3)
        : panelPlacement(view: screen, word: word);
  }

  Future<void> _openDictionaryAbout() async {
    final info = _lookup?.info;
    if (info == null) return;
    await showDictionaryAbout(
      _ui,
      info,
      openLink: (uri) async {
        if (await confirmWebLink(_ui, uri)) await ref.read(linkOpenerProvider).open(uri);
      },
    );
  }

  Future<void> _followLink(DocumentLink link) async {
    switch (link) {
      case PageLink(:final page):
        await _jump(ReadingPosition(page, 0));
      case WebLink(:final uri):
        var open = false;
        await _withControlsHeld(() async => open = await confirmWebLink(_ui, uri));
        if (open) await ref.read(linkOpenerProvider).open(uri);
    }
  }

  /// A jump the reader can undo once with "Back to page N" (FR-026).
  Future<void> _jump(ReadingPosition to) async {
    _jumpBack.recordJump(from: _position);
    await _view!.goTo(to);
  }

  Future<void> _goBack() async {
    final target = _jumpBack.use();
    if (target != null) await _view!.goTo(target);
  }

  Future<void> _openGoToPage() => _withControlsHeld(() async {
    final page = await showGoToPageDialog(_ui, pageCount: _doc!.pageCount);
    if (page != null) await _jump(ReadingPosition(page, 0));
  });

  Future<void> _openSearch() => _withControlsHeld(() async {
    final index = await showSearchSheet(_ui, _search!);
    if (index == null) return;
    _search!.choose(index);
    await _showMatch(jump: true);
  });

  /// Shows the chosen match a little below the top of the view (FR-032).
  Future<void> _showMatch({required bool jump}) async {
    final r = _search?.activeResult;
    if (r == null) return;
    final top = r.rects.isEmpty ? 0.0 : (r.rects.first.top - 0.15).clamp(0.0, 1.0);
    final to = ReadingPosition(r.page, top);
    jump ? await _jump(to) : await _view!.goTo(to);
  }

  void _stepMatch(int delta) {
    _search?.step(delta);
    _showMatch(jump: false);
  }

  /// Every match, grouped by page; the chosen one marked (FR-032).
  List<PageHighlight> get _highlights {
    final s = _search;
    final run = s?.run;
    if (s == null || run == null || s.active == null) return const [];
    final byPage = <int, List<Rect>>{};
    final active = s.activeResult;
    final out = <PageHighlight>[];
    for (final r in run.results) {
      if (identical(r, active)) {
        out.add(PageHighlight(r.page, r.rects, kind: HighlightKind.activeMatch));
      } else {
        (byPage[r.page] ??= []).addAll(r.rects);
      }
    }
    return [for (final e in byPage.entries) PageHighlight(e.key, e.value), ...out];
  }

  /// Search matches, and the word selected for lookup (FR-002).
  List<PageHighlight> get _allHighlights {
    final selection = _lookup?.selection;
    if (selection == null) return _highlights;
    return [
      ..._highlights,
      PageHighlight(selection.page, selection.rects, kind: HighlightKind.selection),
    ];
  }

  Future<void> _openThumbnails() => _withControlsHeld(() async {
    final doc = _doc!;
    // Tiles are about 110 px wide; render them sharp for this screen (research R11).
    final width = (110 * MediaQuery.devicePixelRatioOf(context)).round();
    final page = await showThumbnailsSheet(
      _ui,
      doc: doc,
      cache: _thumbnails ??= ThumbnailCache(doc, width: width),
      currentPage: _position.page,
    );
    if (page != null) await _jump(ReadingPosition(page, 0));
  });

  Future<void> _openContents() => _withControlsHeld(() async {
    final page = await showContentsSheet(
      _ui,
      outline: _outline ??= _doc!.loadOutline(),
      currentPage: _position.page,
    );
    if (page != null) await _jump(ReadingPosition(page, 0));
  });

  void _back() => Navigator.of(context).maybePop();

  Future<void> _setMode(PageMode mode) async {
    if (mode == _mode) return;
    setState(() => _mode = mode);
    await _repo.setPageMode(widget.bookId, mode);
  }

  /// Opens a sheet or dialog with the controls held up until it closes (FR-003).
  Future<void> _withControlsHeld(Future<void> Function() show) async {
    _controls.hold();
    try {
      await show();
    } finally {
      _controls.release();
    }
  }

  void _openSettings() => _withControlsHeld(
    () => showReaderSettings(
      _ui,
      initial: ReaderSettings(mode: _mode, fit: _prefs.fit, theme: _prefs.theme),
      onMode: _setMode,
      onFit: _repo.setFit,
      onTheme: _repo.setTheme,
    ),
  );

  ReaderKeyHandlers get _keys => ReaderKeyHandlers(
    next: () => _view!.next(),
    previous: () => _view!.previous(),
    first: () => _view!.goTo(const ReadingPosition(1, 0)),
    last: () => _view!.goTo(ReadingPosition(_doc!.pageCount, 0)),
    scrollStep: (f) => _view!.scrollBy(f),
    zoomIn: () => _view!.zoomIn(),
    zoomOut: () => _view!.zoomOut(),
    leave: _back,
  );

  ReaderTheme get _theme => ReaderTheme.of(_prefs.theme);

  BarColors get _barColors =>
      BarColors(background: _theme.barBackground, foreground: _theme.barForeground);

  /// Sheets and dialogs follow the reading theme too.
  ThemeData _themeData(ThemeData app) => switch (_prefs.theme) {
    ReadingTheme.light => app,
    ReadingTheme.dark => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: app.colorScheme.primary,
        brightness: Brightness.dark,
      ),
    ),
    ReadingTheme.sepia => app.copyWith(
      colorScheme: app.colorScheme.copyWith(
        brightness: Brightness.light,
        surface: _theme.barBackground,
        surfaceContainerLow: _theme.barBackground,
        onSurface: _theme.barForeground,
      ),
    ),
  };

  ReaderViewConfig _config() {
    final theme = _theme;
    return ReaderViewConfig(
      mode: _mode,
      fit: _prefs.fit,
      initialPosition: _start,
      onPositionChanged: _onPositionChanged,
      pageFilter: theme.pageFilter,
      backgroundColor: theme.background,
      highlightColor: theme.highlightPaintColor,
      activeHighlightColor: theme.activeHighlightPaintColor,
      selectionColor: theme.selectionPaintColor,
      highlights: _allHighlights,
    );
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final error = _error;
    if (error != null) return Scaffold(body: _ErrorMessage(message: error));
    if (doc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(semanticsLabel: 'Opening book')),
      );
    }
    final colors = _barColors;
    final view = _view!;
    final lookup = _lookup!.state;
    // Back and Esc close the panel before they leave the reader (FR-004).
    return PopScope(
      canPop: !lookup.isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _lookup!.close();
      },
      child: Theme(
        data: _themeData(Theme.of(context)),
        child: Builder(
          builder: (context) {
            _themed = context;
            return Scaffold(
              backgroundColor: _theme.background,
              body: ReaderShortcuts(
                handlers: _keys,
                continuous: _mode == PageMode.continuous,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        key: const ValueKey('reader-page-view'),
                        container: true,
                        label: 'Page ${_position.page} of ${doc.pageCount}',
                        // Screen-reader users turn pages without the edge zones (FR-040).
                        customSemanticsActions: {
                          const CustomSemanticsAction(label: 'Next page'): view.next,
                          const CustomSemanticsAction(label: 'Previous page'): view.previous,
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) => Listener(
                            onPointerDown: (e) => _lastPointerKind = e.kind,
                            child: TapDetector(
                              movement: view,
                              onTap: (global, local) => _onTap(global, local, constraints.maxWidth),
                              onLongPress: (global, _) => _lookUpAt(global, lock: true),
                              onLongPressEnd: () => view.setInteractionLocked(false),
                              onDoubleClick: (global, _) => _lookUpAt(global),
                              child: _factory!.build(doc, controller: view, config: _config()),
                            ),
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      key: const ValueKey('reader-controls'),
                      ignoring: !_controls.visible || _barsSettling,
                      child: ExcludeSemantics(
                        excluding: !_controls.visible,
                        child: AnimatedOpacity(
                          opacity: _controls.visible ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: Listener(
                            // Any touch on the bars counts as using them (FR-003).
                            onPointerDown: (_) => _controls.interacted(),
                            behavior: HitTestBehavior.translucent,
                            child: Column(
                              children: [
                                ReaderTopBar(
                                  title: _book?.title ?? '',
                                  colors: colors,
                                  onBack: _back,
                                  actions: [
                                    IconButton(
                                      icon: const Icon(Icons.search),
                                      tooltip: 'Search in book',
                                      onPressed: _openSearch,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.toc),
                                      tooltip: 'Table of contents',
                                      onPressed: _openContents,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.grid_view),
                                      tooltip: 'Page thumbnails',
                                      onPressed: _openThumbnails,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.tune),
                                      tooltip: 'Reader settings',
                                      onPressed: _openSettings,
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                ReaderBottomBar(
                                  page: _position.page,
                                  pageCount: doc.pageCount,
                                  colors: colors,
                                  leading: [
                                    IconButton(
                                      icon: const Icon(Icons.zoom_out),
                                      tooltip: 'Zoom out',
                                      onPressed: view.zoomOut,
                                    ),
                                  ],
                                  trailing: [
                                    IconButton(
                                      icon: const Icon(Icons.zoom_in),
                                      tooltip: 'Zoom in',
                                      onPressed: view.zoomIn,
                                    ),
                                  ],
                                  onPageLabelTap: _openGoToPage,
                                  onSliderStart: _controls.hold,
                                  onSliderEnd: (page) {
                                    _controls.release();
                                    _jump(ReadingPosition(page, 0));
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_search case final search?)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: MediaQuery.paddingOf(context).top + (_controls.visible ? 64 : 12),
                        child: Center(
                          child: SearchMatchBar(
                            session: search,
                            onStep: _stepMatch,
                            onClose: search.clear,
                            onOpen: _openSearch,
                          ),
                        ),
                      ),
                    if (_jumpBack.target case final target?)
                      Positioned(
                        left: 0,
                        right: 0,
                        // Above the bottom bar when it shows; near the edge otherwise.
                        bottom:
                            MediaQuery.paddingOf(context).bottom + (_controls.visible ? 120 : 24),
                        child: Center(
                          child: JumpBackChip(page: target.page, onPressed: _goBack),
                        ),
                      ),
                    if (!_prefs.lookupHintShown && !lookup.isOpen)
                      Positioned(
                        left: 16,
                        right: 16,
                        // Above the bottom bar, and above the "Back to page" chip if it shows.
                        bottom:
                            MediaQuery.paddingOf(context).bottom +
                            (_controls.visible ? 120 : 24) +
                            (_jumpBack.target != null ? 56 : 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: LookupHint(onDismiss: _repo.markLookupHintShown),
                          ),
                        ),
                      ),
                    if (lookup.isOpen) _panel(context, lookup),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, LookupState state) {
    final screen = MediaQuery.sizeOf(context);
    final placement = _placementFor(state, screen);
    final top = placement.edge == PanelEdge.top;
    return Positioned(
      left: 0,
      right: 0,
      top: top ? 0 : null,
      bottom: top ? null : 0,
      child: Align(
        alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: LookupPanel(
            state: state,
            placement: placement,
            viewHeight: screen.height,
            background: _theme.barBackground,
            foreground: _theme.barForeground,
            info: _lookup!.info,
            onClose: _lookup!.close,
            onAbout: _openDictionaryAbout,
          ),
        ),
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to library'),
          ),
        ],
      ),
    ),
  );
}
