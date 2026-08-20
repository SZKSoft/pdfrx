// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';
import 'package:synchronized/extension.dart';
import 'package:vector_math/vector_math_64.dart' as vec;

import '../../pdfrx.dart';
import '../utils/edge_insets_extensions.dart';
import '../utils/platform.dart';
import 'interactive_viewer.dart' as iv;
import 'internals/pdf_error_widget.dart';
import 'internals/pdf_viewer_key_handler.dart';
import 'internals/widget_size_sniffer.dart';
import 'pdf_page_links_overlay.dart';

/// A widget to display PDF document.
///
/// To create a [PdfViewer] widget, use one of the following constructors:
/// - [PdfDocument] with [PdfViewer.documentRef]
/// - [PdfViewer.asset] with an asset name
/// - [PdfViewer.file] with a file path
/// - [PdfViewer.uri] with a URI
///
/// Or otherwise, you can pass [PdfDocumentRef] to [PdfViewer] constructor.
class PdfViewer extends StatefulWidget {
  /// Create [PdfViewer] from a [PdfDocumentRef].
  ///
  /// - [documentRef] is the [PdfDocumentRef].
  /// - [controller] is the controller to control the viewer.
  /// - [params] is the parameters to customize the viewer.
  /// - [initialPageNumber] is the page number to show initially.
  const PdfViewer(
    this.documentRef, {
    super.key,
    this.controller,
    this.params = const PdfViewerParams(),
    this.initialPageNumber = 1,
  });

  /// Create [PdfViewer] from an asset.
  ///
  /// - [assetName] is the asset name.
  /// - [passwordProvider] is used to provide password for encrypted PDF. See [PdfPasswordProvider] for more info.
  /// - [firstAttemptByEmptyPassword] is used to determine whether the first attempt to open the PDF is by empty password
  /// or not. For more info, see [PdfPasswordProvider].
  /// - [controller] is the controller to control the viewer.
  /// - [params] is the parameters to customize the viewer.
  /// - [initialPageNumber] is the page number to show initially.
  PdfViewer.asset(
    String assetName, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = true,
    super.key,
    this.controller,
    this.params = const PdfViewerParams(),
    this.initialPageNumber = 1,
  }) : documentRef = PdfDocumentRefAsset(
         assetName,
         passwordProvider: passwordProvider,
         firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
         useProgressiveLoading: useProgressiveLoading,
       );

  /// Create [PdfViewer] from a file.
  ///
  /// - [path] is the file path.
  /// - [passwordProvider] is used to provide password for encrypted PDF. See [PdfPasswordProvider] for more info.
  /// - [firstAttemptByEmptyPassword] is used to determine whether the first attempt to open the PDF is by empty password
  /// or not. For more info, see [PdfPasswordProvider].
  /// - [controller] is the controller to control the viewer.
  /// - [params] is the parameters to customize the viewer.
  /// - [initialPageNumber] is the page number to show initially.
  PdfViewer.file(
    String path, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = true,
    super.key,
    this.controller,
    this.params = const PdfViewerParams(),
    this.initialPageNumber = 1,
  }) : documentRef = PdfDocumentRefFile(
         path,
         passwordProvider: passwordProvider,
         firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
         useProgressiveLoading: useProgressiveLoading,
       );

  /// Create [PdfViewer] from a URI.
  ///
  /// - [uri] is the URI.
  /// - [passwordProvider] is used to provide password for encrypted PDF. See [PdfPasswordProvider] for more info.
  /// - [firstAttemptByEmptyPassword] is used to determine whether the first attempt to open the PDF is by empty password
  /// or not. For more info, see [PdfPasswordProvider].
  /// - [controller] is the controller to control the viewer.
  /// - [params] is the parameters to customize the viewer.
  /// - [initialPageNumber] is the page number to show initially.
  /// - [preferRangeAccess] to prefer range access to download the PDF. The default is false. (Not supported on Web).
  /// - [headers] is used to specify additional HTTP headers especially for authentication/authorization.
  /// - [withCredentials] is used to specify whether to include credentials in the request (Only supported on Web).
  /// - [timeout] is the timeout duration for loading the document. (Only supported on non-Web platforms).
  PdfViewer.uri(
    Uri uri, {
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = true,
    super.key,
    this.controller,
    this.params = const PdfViewerParams(),
    this.initialPageNumber = 1,
    bool preferRangeAccess = false,
    Map<String, String>? headers,
    bool withCredentials = false,
    Duration? timeout,
  }) : documentRef = PdfDocumentRefUri(
         uri,
         passwordProvider: passwordProvider,
         firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
         useProgressiveLoading: useProgressiveLoading,
         preferRangeAccess: preferRangeAccess,
         headers: headers,
         withCredentials: withCredentials,
         timeout: timeout,
       );

  /// Create [PdfViewer] from a byte data.
  ///
  /// - [data] is the byte data.
  /// - [sourceName] must be some ID, e.g., file name or URL, to identify the source of the PDF. If [sourceName] is not
  /// unique for each source, the viewer may not work correctly.
  /// - [passwordProvider] is used to provide password for encrypted PDF. See [PdfPasswordProvider] for more info.
  /// - [firstAttemptByEmptyPassword] is used to determine whether the first attempt to open the PDF is by empty password
  /// or not. For more info, see [PdfPasswordProvider].
  /// - [controller] is the controller to control the viewer.
  /// - [params] is the parameters to customize the viewer.
  /// - [initialPageNumber] is the page number to show initially.
  PdfViewer.data(
    Uint8List data, {
    required String sourceName,
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = true,
    super.key,
    this.controller,
    this.params = const PdfViewerParams(),
    this.initialPageNumber = 1,
  }) : documentRef = PdfDocumentRefData(
         data,
         sourceName: sourceName,
         passwordProvider: passwordProvider,
         firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
         useProgressiveLoading: useProgressiveLoading,
       );

  /// Create [PdfViewer] from a custom source.
  ///
  /// - [fileSize] is the size of the PDF file.
  /// - [read] is the function to read the PDF file.
  /// - [sourceName] must be some ID, e.g., file name or URL, to identify the source of the PDF. If [sourceName] is not
  /// unique for each source, the viewer may not work correctly.
  /// - [passwordProvider] is used to provide password for encrypted PDF. See [PdfPasswordProvider] for more info.
  /// - [firstAttemptByEmptyPassword] is used to determine whether the first attempt to open the PDF is by empty password
  /// or not. For more info, see [PdfPasswordProvider].
  /// - [controller] is the controller to control the viewer.
  /// - [params] is the parameters to customize the viewer.
  /// - [initialPageNumber] is the page number to show initially.
  PdfViewer.custom({
    required int fileSize,
    required FutureOr<int> Function(Uint8List buffer, int position, int size) read,
    required String sourceName,
    PdfPasswordProvider? passwordProvider,
    bool firstAttemptByEmptyPassword = true,
    bool useProgressiveLoading = true,
    super.key,
    this.controller,
    this.params = const PdfViewerParams(),
    this.initialPageNumber = 1,
  }) : documentRef = PdfDocumentRefCustom(
         fileSize: fileSize,
         read: read,
         sourceName: sourceName,
         passwordProvider: passwordProvider,
         firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
         useProgressiveLoading: useProgressiveLoading,
       );

  /// [PdfDocumentRef] that represents the PDF document.
  final PdfDocumentRef documentRef;

  /// Controller to control the viewer.
  final PdfViewerController? controller;

  /// Parameters to customize the display of the PDF document.
  final PdfViewerParams params;

  /// Page number to show initially.
  final int initialPageNumber;

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

class _PdfViewerState extends State<PdfViewer>
    with SingleTickerProviderStateMixin
    implements PdfTextSelectionDelegate, PdfViewerCoordinateConverter {
  PdfViewerController? _controller;
  late final _txController = _PdfViewerTransformationController(this);
  late final AnimationController _animController;
  Animation<Matrix4>? _animGoTo;
  int _animationResettingGuard = 0;

  PdfDocument? _document;
  PdfPageLayout? _layout;
  Size? _viewSize;
  double? _coverScale;
  double? _alternativeFitScale;
  static const _defaultMinScale = 0.1;
  double _minScale = _defaultMinScale;
  int? _pageNumber;
  bool _initialized = false;
  bool _usingScrollPercentageMode = false;

  StreamSubscription<PdfDocumentEvent>? _documentSubscription;
  final _interactiveViewerKey = GlobalKey<iv.InteractiveViewerState>();

  final List<double> _zoomStops = [1.0];

  final _imageCache = _PdfPageImageCache();
  final _magnifierImageCache = _PdfPageImageCache();

  late final _canvasLinkPainter = _CanvasLinkPainter(this);

  // Changes to the stream rebuilds the viewer
  final _updateStream = BehaviorSubject<Matrix4>();

  /// page-number keyed cache of extracted text
  final _textCache = <int, PdfPageText?>{};
  Timer? _textSelectionChangedDebounceTimer;
  final double _hitTestMargin = 3.0;

  /// The starting/ending point of the text selection.
  PdfTextSelectionPoint? _selA, _selB;
  Offset? _textSelectAnchor;

  /// [_textSelA] is the rectangle of the first character in the selected paragraph and
  PdfTextSelectionAnchor? _textSelA;

  /// [_textSelB] is the rectangle of the last character in the selected paragraph.
  PdfTextSelectionAnchor? _textSelB;

  _TextSelectionPart _selPartMoving = _TextSelectionPart.none;

  _TextSelectionPart _selPartLastMoved = _TextSelectionPart.none;

  bool _isSelectingAllText = false;
  bool _isSelectingAWord = false;
  PointerDeviceKind? _selectionPointerDeviceKind;

  Offset? _contextMenuDocumentPosition;
  PdfViewerPart _contextMenuFor = PdfViewerPart.background;

  Timer? _interactionEndedTimer;
  bool _isInteractionGoingOn = false;

  BuildContext? _contextForFocusNode;

  /// last pointer location in viewer local coordinates
  Offset _pointerOffset = Offset.zero;

  /// last pointer device kind to differentiate between mouse and touch
  PointerDeviceKind? _pointerDeviceKind;

  // boundary margins adjusted to center content that's smaller than
  // the viewport
  EdgeInsets _adjustedBoundaryMargins = EdgeInsets.zero;

  @override
  void initState() {
    super.initState();
    pdfrxFlutterInitialize();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _widgetUpdated(null);
  }

  @override
  void didUpdateWidget(covariant PdfViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _widgetUpdated(oldWidget);
  }

  Future<void> _widgetUpdated(PdfViewer? oldWidget) async {
    if (widget == oldWidget) {
      return;
    }

    if (oldWidget?.documentRef.key == widget.documentRef.key) {
      if (widget.params.doChangesRequireReload(oldWidget?.params)) {
        if (widget.params.annotationRenderingMode != oldWidget?.params.annotationRenderingMode) {
          _imageCache.releaseAllImages();
          _magnifierImageCache.releaseAllImages();
        }
      }
      return;
    } else {
      oldWidget?.documentRef.resolveListenable().removeListener(_onDocumentChanged);
      widget.documentRef.resolveListenable()
        ..addListener(_onDocumentChanged)
        ..load();
    }

    _onDocumentChanged();
  }

  void _onDocumentChanged() async {
    // Cherry-pick of upstream PR #617 (merged 2026-05-08, ships in 2.3.x;
    // missing from 2.2.24 which is our fork base). The PdfDocumentRef
    // listenable fires for *every* state change including HTTP
    // download-progress events for `preferRangeAccess` PDFs — pre-patch
    // the body below would wipe the image cache + reset
    // `_initialized` on every chunk. Early-return when the underlying
    // document instance is unchanged so progress-only notifications
    // don't trigger a full viewer reset (white-flash reload loop on
    // 10+ MB PDFs). Not directly load-bearing for ARGUS's RAM-loaded
    // PDFs but cheap insurance if we switch sources later.
    final currentDoc = widget.documentRef.resolveListenable().document;
    if (currentDoc != null && currentDoc == _document) return;

    _layout = null;
    _documentSubscription?.cancel();
    _documentSubscription = null;
    _textSelectionChangedDebounceTimer?.cancel();
    _stopInteraction();
    _imageCache.releaseAllImages();
    _magnifierImageCache.releaseAllImages();
    _canvasLinkPainter.resetAll();
    _textCache.clear();
    _clearTextSelections(invalidate: false);
    _pageNumber = null;
    _gotoTargetPageNumber = null;
    _initialized = false;
    // ARGUS fork addition (B1): reset the on-demand load bookkeeping
    // so a swap to a fresh document doesn't inherit the previous doc's
    // already-loaded range.
    _eagerLoadedThroughPage = 0;
    _progressiveLoadInFlight = null;
    _txController.removeListener(_onMatrixChanged);
    _controller?._attach(null);

    final listenable = widget.documentRef.resolveListenable();
    final document = listenable.document;
    if (document == null) {
      _document = null;
      if (mounted) {
        setState(() {});
      }
      _notifyOnDocumentChanged();
      if (listenable.error != null) {
        _notifyDocumentLoadFinished(succeeded: false);
      }
      return;
    }

    _document = document;

    _controller ??= widget.controller ?? PdfViewerController();
    _controller!._attach(this);
    _txController.addListener(_onMatrixChanged);
    _documentSubscription = document.events.listen(_onDocumentEvent);

    if (mounted) {
      setState(() {});
    }

    _notifyOnDocumentChanged();
    _loadDelayed();
  }

  // 2026-05-14: `_kEagerPageLookahead` constant removed — the
  // contiguous "ensure pages up through N" path was retired in
  // favour of `_ensurePageLoadedSparse`, which uses a fixed ±2
  // radius around the target page. The contiguous loader saw a
  // ~300 MB RSS spike on long jumps because it dragged PDFium
  // through every intermediate page (see
  // `_ensurePageLoadedSparse` docstring for the full rationale).
  /// Highest page number whose PDFium metadata has been resolved to real
  /// dimensions. Pages beyond this index still appear in
  /// `_document.pages` but with placeholder (last-loaded-page) sizes,
  /// AND `PdfPage.render()` returns `null` for them — so the paint loop
  /// shows the white fallback rect until the underlying batch tick
  /// flips `isLoaded` to true.
  int _eagerLoadedThroughPage = 0;

  /// In-flight progressive load future, or null when idle. Used to
  /// serialise [_ensurePagesLoadedThrough] callers: a second invocation
  /// while a load is running awaits the first and re-checks whether
  /// further loading is needed.
  Future<void>? _progressiveLoadInFlight;

  Future<void> _loadDelayed() async {
    // To make the page image loading more smooth, delay the loading of pages
    await Future.delayed(widget.params.behaviorControlParams.trailingPageLoadingDelay);
    if (!mounted) return;
    // ARGUS fork — Phase Y1 (2026-05-14). Bounded initial page-metadata
    // load.
    //
    // **Why bounded**: Phase E1 used to load every page in the document
    // (`target: 1 << 30`) to dodge the "page renders blank when
    // `!isLoaded`" symptom. The cost was hidden — every `FPDF_LoadPage`
    // call inside `_loadPagesInLimitedTime` (see pdfrx_pdfium.dart:~740)
    // triggers PDFium to parse the page's resource dictionary; the
    // document-level CPDF cache then holds onto every decoded shading
    // dict / X-Object form / font resource for the life of the
    // document. On a 270-page textbook whose source PDF is 47%
    // shading info (~85 MB compressed, 200-400 MB decoded), pre-loading
    // every page is the dominant unaccounted RAM cost on a 4 GB smart
    // board.
    //
    // **The fix**: cap the initial sweep at the first window
    // (initialPage ± 10, min 30). Pages beyond that stay
    // `!isLoaded` until the user navigates near them
    // (`_setCurrentPageNumber` extends the window) OR a render call
    // explicitly waits for them (`_cachePagePreviewImage` now does an
    // `_ensurePagePageLoadedSync` hop before calling `page.render`,
    // which means cold-jumps to far pages incur ~250-500 ms instead
    // of being silently blank).
    //
    // **A2 vs B1**: the B1 attempt did the same kind of cap and failed
    // because it didn't pair with a render-time await. A2's frame
    // coalescer is independent and remains in effect either way, so
    // there's no invalidate-storm risk in the bounded path.
    final int initialTarget = max(30, widget.initialPageNumber + 10);
    await _ensurePagesLoadedThrough(initialTarget);
  }

  /// ARGUS fork helper (2026-05-14). Sparse counterpart to
  /// [_ensurePagesLoadedThrough]. Loads metadata for `[pageNumber-
  /// radius .. pageNumber+radius]` only — clamped to the document
  /// bounds and de-duped against already-loaded pages by the engine.
  ///
  /// Why this matters: the contiguous version walked PDFium through
  /// every page between the last-loaded index and the target, which
  /// on a "Sayfaya Git" jump from page 1 to page 270 fired 240
  /// `FPDF_LoadPage` calls back-to-back. Each call let PDFium add the
  /// referenced page's resource dictionary entries into its
  /// document-level cache, so process RSS climbed from ~500 MB to
  /// ~800 MB just from the jump. The sparse loader touches at most
  /// `2 * radius + 1` pages regardless of the navigation distance.
  Future<void> _ensurePageLoadedSparse(int pageNumber, {int radius = 2}) async {
    final doc = _document;
    if (doc == null) return;
    if (pageNumber < 1 || pageNumber > doc.pages.length) return;
    final int lo = max(1, pageNumber - radius);
    final int hi = min(doc.pages.length, pageNumber + radius);
    final List<int> wanted = <int>[];
    for (int p = lo; p <= hi; p++) {
      if (!doc.pages[p - 1].isLoaded) wanted.add(p - 1);
    }
    if (wanted.isEmpty) return;

    // Serialise with the contiguous loader (and other sparse calls)
    // through the same in-flight gate so PDFium's `BackgroundWorker`
    // never gets two concurrent page-load batches.
    final pending = _progressiveLoadInFlight;
    if (pending != null) {
      await pending;
      if (!mounted || _document != doc) return;
      // Re-check after the wait: previous loader may have covered us.
      final bool stillNeeded =
          wanted.any((int i) => !doc.pages[i].isLoaded);
      if (!stillNeeded) return;
    }
    final completer = Completer<void>();
    _progressiveLoadInFlight = completer.future;
    try {
      await doc.loadPagesAt(wanted);
      // Track the highest contiguous index that's now loaded so
      // subsequent _ensurePagesLoadedThrough callers still benefit
      // from the bookkeeping. We deliberately DON'T claim full
      // coverage up to `pageNumber + radius` because intermediate
      // pages may still be unloaded — the marker is a forward-only
      // hint, not a strict invariant.
      if (pageNumber + radius > _eagerLoadedThroughPage) {
        // Only advance if pages 1..(pageNumber+radius) are actually
        // all loaded — otherwise leave the marker where it was.
        bool contiguous = true;
        for (int p = 1; p <= pageNumber + radius; p++) {
          if (p - 1 >= doc.pages.length) break;
          if (!doc.pages[p - 1].isLoaded) {
            contiguous = false;
            break;
          }
        }
        if (contiguous) {
          _eagerLoadedThroughPage = pageNumber + radius;
        }
      }
    } finally {
      if (_progressiveLoadInFlight == completer.future) {
        _progressiveLoadInFlight = null;
      }
      completer.complete();
    }
  }

  /// Ensure PDFium metadata is resolved for pages 1..[target] (1-based,
  /// inclusive). Safe to call concurrently — overlapping invocations are
  /// serialised through [_progressiveLoadInFlight].
  ///
  /// ARGUS fork helper (2026-05-13, revised 2026-05-14). Caller flow:
  ///
  /// - [_loadDelayed]: pulls the initial window into memory.
  /// - [_setCurrentPageNumber]: extends the window when the user
  ///   navigates near the unloaded tail.
  Future<void> _ensurePagesLoadedThrough(int target) async {
    final doc = _document;
    if (doc == null) return;
    if (target <= _eagerLoadedThroughPage) return;

    // Serialise with any in-flight load. Re-check the threshold after
    // awaiting in case the prior load already covered our range.
    final pending = _progressiveLoadInFlight;
    if (pending != null) {
      await pending;
      if (target <= _eagerLoadedThroughPage) return;
      if (!mounted || _document != doc) return;
    }

    final completer = Completer<void>();
    _progressiveLoadInFlight = completer.future;
    try {
      await doc.loadPagesProgressively<PdfDocument>(
        data: doc,
        onPageLoadProgress: (pageCountLoadedTotal, totalPageCount, callbackDoc) {
          if (!mounted || _document != callbackDoc) return false;
          if (pageCountLoadedTotal > _eagerLoadedThroughPage) {
            _eagerLoadedThroughPage = pageCountLoadedTotal;
          }
          // Stop once we've covered the requested range OR the entire
          // document is loaded.
          if (pageCountLoadedTotal >= target) return false;
          if (pageCountLoadedTotal >= totalPageCount) return false;
          return true;
        },
      );
    } finally {
      if (_progressiveLoadInFlight == completer.future) {
        _progressiveLoadInFlight = null;
      }
      completer.complete();
    }
  }

  void _notifyOnDocumentChanged() {
    if (widget.params.onDocumentChanged != null) {
      Future.microtask(() => widget.params.onDocumentChanged?.call(_document));
    }
  }

  @override
  void dispose() {
    focusReportForPreventingContextMenuWeb(this, false);
    _documentSubscription?.cancel();
    _textSelectionChangedDebounceTimer?.cancel();
    _interactionEndedTimer?.cancel();
    _imageCache.cancelAllPendingRenderings();
    _magnifierImageCache.cancelAllPendingRenderings();
    _animController.dispose();
    widget.documentRef.resolveListenable().removeListener(_onDocumentChanged);
    _imageCache.releaseAllImages();
    _magnifierImageCache.releaseAllImages();
    _canvasLinkPainter.resetAll();
    _txController.removeListener(_onMatrixChanged);
    _controller?._attach(null);
    _txController.dispose();
    super.dispose();
  }

  void _onMatrixChanged() => _invalidate();

  void _onDocumentEvent(PdfDocumentEvent event) {
    if (event is PdfDocumentPageStatusChangedEvent) {
      // FIXME: We can handle the event more efficiently by only updating the affected pages.
      for (final change in event.changes.entries) {
        _imageCache.makeCacheImageForPageDirty(change.key);
        _magnifierImageCache.makeCacheImageForPageDirty(change.key);
        _canvasLinkPainter.releaseLinksForPage(change.key);
        _textCache.remove(change.key);
      }
      _clearTextSelections(invalidate: false);
      _invalidate();
    } else if (event is PdfDocumentLoadCompleteEvent) {
      _notifyDocumentLoadFinished(succeeded: true);
    }
  }

  Future<void> _notifyDocumentLoadFinished({required bool succeeded}) async {
    if (succeeded) {
      // FIXME: This is a temporary workaround to wait until the initial page is loaded.
      while (mounted) {
        if (_imageCache.pageImages.containsKey(widget.initialPageNumber)) break;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    Future.microtask(() async {
      if (mounted) {
        widget.params.onDocumentLoadFinished?.call(widget.documentRef, succeeded);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.documentRef.resolveListenable();
    if (listenable.error != null) {
      return Container(
        color: widget.params.backgroundColor,
        child: (widget.params.errorBannerBuilder ?? _defaultErrorBannerBuilder)(
          context,
          listenable.error!,
          listenable.stackTrace,
          widget.documentRef,
        ),
      );
    }
    if (_document == null) {
      return Container(
        color: widget.params.backgroundColor,
        child: widget.params.loadingBannerBuilder?.call(context, listenable.bytesDownloaded, listenable.totalBytes),
      );
    }

    return Container(
      color: widget.params.backgroundColor,
      child: PdfViewerKeyHandler(
        onKeyRepeat: _onKey,
        // NOTE: When the PdfViewer gets focus, we report it to prevent the default context menu on Web browser.
        onFocusChange: (hasFocus) => focusReportForPreventingContextMenuWeb(this, hasFocus),
        params: widget.params.keyHandlerParams,
        child: StreamBuilder(
          stream: _updateStream,
          builder: (context, snapshot) {
            _contextForFocusNode = context;
            return LayoutBuilder(
              builder: (context, constraints) {
                final isCopyTextEnabled = _document!.permissions?.allowsCopying != false;
                final viewSize = Size(constraints.maxWidth, constraints.maxHeight);

                _updateLayout(viewSize);

                return Listener(
                  onPointerDown: (details) => _handlePointerEvent(details, details.localPosition, details.kind),
                  onPointerMove: (details) => _handlePointerEvent(details, details.localPosition, details.kind),
                  onPointerUp: (details) => _handlePointerEvent(details, details.localPosition, details.kind),
                  onPointerHover: (event) => _handlePointerEvent(event, event.localPosition, event.kind),
                  child: Stack(
                    children: [
                      iv.InteractiveViewer(
                        key: _interactiveViewerKey,
                        transformationController: _txController,
                        constrained: false,
                        boundaryMargin: widget.params.scrollPhysics == null
                            ? const EdgeInsets.all(double.infinity) // NOTE: boundaryMargin is handled manually
                            : _adjustedBoundaryMargins,
                        maxScale: widget.params.maxScale,
                        minScale: minScale,
                        panAxis: widget.params.panAxis,
                        panEnabled: widget.params.panEnabled,
                        scaleEnabled: widget.params.scaleEnabled,
                        onInteractionEnd: _onInteractionEnd,
                        onInteractionStart: _onInteractionStart,
                        onInteractionUpdate: widget.params.onInteractionUpdate,
                        interactionEndFrictionCoefficient: widget.params.interactionEndFrictionCoefficient,
                        onWheelDelta: widget.params.scrollByMouseWheel != null ? _onWheelDelta : null,
                        scrollPhysics: widget.params.scrollPhysics,
                        scrollPhysicsScale: widget.params.scrollPhysicsScale,
                        scrollPhysicsAutoAdjustBoundaries: false,
                        // PDF pages
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => _handleGeneralTap(d.globalPosition, PdfViewerGeneralTapType.tap),
                          onDoubleTapDown: (d) =>
                              _handleGeneralTap(d.globalPosition, PdfViewerGeneralTapType.doubleTap),
                          onLongPressStart: (d) =>
                              _handleGeneralTap(d.globalPosition, PdfViewerGeneralTapType.longPress),
                          onSecondaryTapUp: (d) =>
                              _handleGeneralTap(d.globalPosition, PdfViewerGeneralTapType.secondaryTap),
                          child: !isTextSelectionEnabled
                              // show PDF pages without text selection
                              ? CustomPaint(
                                  foregroundPainter: _CustomPainter.fromFunctions(_paintPages),
                                  size: _layout!.documentSize,
                                )
                              // show PDF pages with text selection
                              : MouseRegion(
                                  cursor: SystemMouseCursors.text,
                                  hitTestBehavior: HitTestBehavior.deferToChild,
                                  child: GestureDetector(
                                    onPanStart: enableSelectionHandles ? null : _onTextPanStart,
                                    onPanUpdate: enableSelectionHandles ? null : _onTextPanUpdate,
                                    onPanEnd: enableSelectionHandles ? null : _onTextPanEnd,
                                    supportedDevices: {
                                      // PointerDeviceKind.trackpad is intentionally not included here
                                      PointerDeviceKind.mouse,
                                      PointerDeviceKind.stylus,
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.invertedStylus,
                                    },
                                    child: CustomPaint(
                                      painter: _CustomPainter.fromFunctions(
                                        _paintPages,
                                        hitTestFunction: _hitTestForTextSelection,
                                      ),
                                      size: _layout!.documentSize,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (_initialized && _canvasLinkPainter.isLaidUnderPageOverlays)
                        _canvasLinkPainter.linkHandlingOverlay(viewSize),
                      if (_initialized) ..._buildPageOverlayWidgets(context),
                      if (_initialized && _canvasLinkPainter.isLaidOverPageOverlays)
                        _canvasLinkPainter.linkHandlingOverlay(viewSize),
                      if (_initialized && widget.params.viewerOverlayBuilder != null)
                        ...widget.params.viewerOverlayBuilder!(context, viewSize, _canvasLinkPainter._handleTapUp),
                      if (_initialized) ..._placeTextSelectionWidgets(context, viewSize, isCopyTextEnabled),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Offset _calcOverscroll(Matrix4 m, {required Size viewSize}) {
    final boundaryMargin = _adjustedBoundaryMargins;
    if (boundaryMargin.containsInfinite) {
      return Offset.zero;
    }

    final layout = _layout!;
    final visible = m.calcVisibleRect(viewSize);
    var dxDoc = 0.0;
    var dyDoc = 0.0;

    final leftBoundary = -boundaryMargin.left; // negative margin reduces allowed leftward scroll
    final rightBoundary =
        layout.documentSize.width + boundaryMargin.right; // negative margin reduces allowed rightward scroll
    final topBoundary = -boundaryMargin.top; // negative margin reduces allowed upward scroll
    final bottomBoundary =
        layout.documentSize.height + boundaryMargin.bottom; // negative margin reduces allowed downward scroll

    if (visible.left < leftBoundary) {
      dxDoc = leftBoundary - visible.left;
    } else if (visible.right > rightBoundary) {
      dxDoc = rightBoundary - visible.right;
    }

    if (visible.top < topBoundary) {
      dyDoc = topBoundary - visible.top;
    } else if (visible.bottom > bottomBoundary) {
      dyDoc = bottomBoundary - visible.bottom;
    }
    return Offset(dxDoc, dyDoc);
  }

  Matrix4 _calcMatrixForClampedToNearestBoundary(Matrix4 candidate, {required Size viewSize}) {
    if (widget.params.scrollPhysics == null) {
      _adjustBoundaryMargins(_viewSize!, candidate.zoom);
    }
    final overScroll = _calcOverscroll(candidate, viewSize: viewSize);
    if (overScroll == Offset.zero) {
      return candidate;
    }
    return candidate.clone()..translateByDouble(-overScroll.dx, -overScroll.dy, 0, 1);
  }

  void _updateLayout(Size viewSize) {
    if (viewSize.height <= 0) return; // For fix blank pdf when restore window from minimize on Windows
    final currentPageNumber = _guessCurrentPageNumber();
    final oldVisibleRect = _initialized ? _visibleRect : Rect.zero;
    final oldLayout = _layout;
    final oldMinScale = _minScale;
    final oldSize = _viewSize;
    final isViewSizeChanged = oldSize != viewSize;
    _viewSize = viewSize;
    final isLayoutChanged = _relayoutPages();

    _calcCoverFitScale();
    _calcZoomStopTable();
    _adjustBoundaryMargins(viewSize, max(_minScale, _currentZoom));

    void callOnViewerSizeChanged() {
      if (isViewSizeChanged) {
        if (_controller != null && widget.params.onViewSizeChanged != null) {
          widget.params.onViewSizeChanged!(viewSize, oldSize, _controller!);
        }
      }
    }

    if (!_initialized && _layout != null && _coverScale != null) {
      _initialized = true;
      Future.microtask(() async {
        // forcibly calculate fit scale for the initial page
        _pageNumber = _gotoTargetPageNumber = _calcInitialPageNumber();
        _calcCoverFitScale();
        _calcZoomStopTable();
        final zoom =
            widget.params.calculateInitialZoom?.call(
              _document!,
              _controller!,
              _alternativeFitScale ?? _coverScale!,
              _coverScale!,
            ) ??
            _coverScale!;
        await _setZoom(Offset.zero, zoom, duration: Duration.zero);
        if (_pageNumber! <= _layout!.pageLayouts.length) {
          await _goToPage(pageNumber: _pageNumber!, duration: Duration.zero);
        }
        if (mounted && _document != null && _controller != null) {
          widget.params.onViewerReady?.call(_document!, _controller!);
        }
        callOnViewerSizeChanged();
      });
    } else if (isLayoutChanged || isViewSizeChanged) {
      Future.microtask(() async {
        if (mounted) {
          // preserve the current zoom whilst respecting the new minScale
          final zoomTo = _currentZoom < _minScale || _currentZoom == oldMinScale ? _minScale : _currentZoom;
          if (isLayoutChanged) {
            // if the layout changed, calculate the top-left position in the document
            // before the layout change and go to that position in the new layout

            if (oldLayout != null && currentPageNumber != null) {
              // The top-left position of the screen (oldVisibleRect.topLeft) may be
              // in the boundary margin, or a margin between pages, and it could be
              // the current page or one of the neighboring pages
              final hit = _getClosestPageHit(currentPageNumber, oldLayout, oldVisibleRect);
              final pageNumber = hit?.page.pageNumber ?? currentPageNumber;

              // Compute relative position within the old pageRect
              final oldPageRect = oldLayout.pageLayouts[pageNumber - 1];
              final newPageRect = _layout!.pageLayouts[pageNumber - 1];
              final oldOffset = oldVisibleRect.topLeft - oldPageRect.topLeft;
              final fracX = oldOffset.dx / oldPageRect.width;
              final fracY = oldOffset.dy / oldPageRect.height;

              // Map into new layoutRect
              final newOffset = Offset(
                newPageRect.left + fracX * newPageRect.width,
                newPageRect.top + fracY * newPageRect.height,
              );

              // preserve the position after a layout change
              await _goToPosition(documentOffset: newOffset, zoom: zoomTo);
            }
          } else {
            if (zoomTo != _currentZoom) {
              // layout hasn't changed, but size and zoom has
              final zoomChange = zoomTo / _currentZoom;
              final pivot = vec.Vector3(_txController.value.x, _txController.value.y, 0);

              final pivotScale = Matrix4.identity()
                ..translateByVector3(pivot)
                ..scaleByDouble(zoomChange, zoomChange, zoomChange, 1)
                ..translateByVector3(-pivot / zoomChange);

              final Matrix4 zoomPivoted = pivotScale * _txController.value;
              _adjustBoundaryMargins(viewSize, zoomTo);
              _clampToNearestBoundary(zoomPivoted, viewSize: viewSize);
            } else {
              // size changes (e.g. rotation) can still cause out-of-bounds matrices
              // so clamp here
              _clampToNearestBoundary(_txController.value, viewSize: viewSize);
            }
            callOnViewerSizeChanged();
          }
        }
      });
    } else if (currentPageNumber != null && _pageNumber != currentPageNumber) {
      _setCurrentPageNumber(currentPageNumber);
    }
  }

  /// Stop InteractiveViewer animations and apply boundary clamping
  void _clampToNearestBoundary(Matrix4 candidate, {required Size viewSize}) {
    if (_isInteractionGoingOn) return;

    _stopInteractiveViewerAnimation();

    // Apply the clamped matrix
    _txController.value = _calcMatrixForClampedToNearestBoundary(candidate, viewSize: viewSize);
  }

  /// Get the state of the internal [iv.InteractiveViewer].
  iv.InteractiveViewerState? get _interactiveViewerState => _interactiveViewerKey.currentState;

  /// Stop any active animations
  void _stopInteractiveViewerAnimation() {
    if (_interactiveViewerState?.hasActiveAnimations == true) {
      _interactiveViewerState?.stopAllAnimations();
    }
  }

  int _calcInitialPageNumber() {
    return widget.params.calculateInitialPageNumber?.call(_document!, _controller!) ?? widget.initialPageNumber;
  }

  PdfPageHitTestResult? _getClosestPageHit(int currentPageNumber, PdfPageLayout oldLayout, ui.Rect oldVisibleRect) {
    for (final pageIndex in <int>[currentPageNumber, currentPageNumber - 1, currentPageNumber + 1]) {
      if (pageIndex >= 1 && pageIndex <= oldLayout.pageLayouts.length) {
        final rec = _nudgeHitTest(oldVisibleRect.topLeft, layout: oldLayout, pageNumber: pageIndex);
        if (rec != null) {
          return rec.hit;
        }
      }
    }
    return null;
  }

  /// Hit-tests a point against a given layout and optional page number.
  PdfPageHitTestResult? _hitTestWithLayout({
    required Offset point,
    required PdfPageLayout layout,
    required int pageNumber,
  }) {
    final pages = _document?.pages;
    if (pages == null) return null;
    if (pageNumber >= layout.pageLayouts.length) {
      return null;
    }

    final rect = layout.pageLayouts[pageNumber];
    if (rect.contains(point)) {
      final page = pages[pageNumber];
      final local = point - rect.topLeft;
      final pdfOffset = local.toPdfPoint(page: page, scaledPageSize: rect.size);
      return PdfPageHitTestResult(page: page, offset: pdfOffset);
    } else {
      return null;
    }
  }

  // Attempts to nudge the point on the x axis until a valid page hit is found.
  ({Offset point, PdfPageHitTestResult hit})? _nudgeHitTest(Offset start, {PdfPageLayout? layout, int? pageNumber}) {
    const epsViewPx = 1.0;
    final epsDoc = epsViewPx / _currentZoom;

    var tryPoint = start;
    var tryOffset = Offset.zero;
    final useLayout = layout;
    for (var i = 0; i < 500; i++) {
      final result = useLayout != null && pageNumber != null
          ? _hitTestWithLayout(point: tryPoint, layout: useLayout, pageNumber: pageNumber)
          : _getPdfPageHitTestResult(tryPoint, useDocumentLayoutCoordinates: true);
      if (result != null) {
        return (point: tryOffset, hit: result);
      }
      tryOffset += Offset(epsDoc, 0);
      tryPoint = tryPoint.translate(epsDoc, 0);
    }
    return null;
  }

  void _startInteraction() {
    _interactionEndedTimer?.cancel();
    _interactionEndedTimer = null;
    _isInteractionGoingOn = true;
  }

  void _stopInteraction() {
    _interactionEndedTimer?.cancel();
    if (!mounted) return;
    _interactionEndedTimer = Timer(const Duration(milliseconds: 300), () {
      _isInteractionGoingOn = false;
      _invalidate();
    });
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    widget.params.onInteractionEnd?.call(details);
    _stopInteraction();
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _startInteraction();
    _requestFocus();
    widget.params.onInteractionStart?.call(details);
  }

  /// Last page number that is explicitly requested to go to.
  int? _gotoTargetPageNumber;

  bool _onKey(PdfViewerKeyHandlerParams params, LogicalKeyboardKey key, bool isRealKeyPress) {
    final result = widget.params.onKey?.call(params, key, isRealKeyPress);
    if (result != null) {
      return result;
    }
    // NOTE: repeatInterval should be shorter than the actual key repeat interval of the platform
    // because the animation should finish before the next key event.
    const repeatInterval = Duration(milliseconds: 100);
    switch (key) {
      case LogicalKeyboardKey.pageUp:
        _goToPage(pageNumber: (_gotoTargetPageNumber ?? _pageNumber!) - 1, duration: repeatInterval);
        return true;
      case LogicalKeyboardKey.pageDown:
        _goToPage(pageNumber: (_gotoTargetPageNumber ?? _pageNumber!) + 1, duration: repeatInterval);
        return true;
      case LogicalKeyboardKey.space:
        final move = HardwareKeyboard.instance.isShiftPressed ? -1 : 1;
        _goToPage(pageNumber: (_gotoTargetPageNumber ?? _pageNumber!) + move, duration: repeatInterval);
        return true;
      case LogicalKeyboardKey.home:
        _goToPage(pageNumber: 1, duration: repeatInterval);
        return true;
      case LogicalKeyboardKey.end:
        _goToPage(pageNumber: _document!.pages.length, anchor: widget.params.pageAnchorEnd, duration: repeatInterval);
        return true;
      case LogicalKeyboardKey.equal:
        if (isCommandKeyPressed) {
          _zoomUp(duration: repeatInterval);
          return true;
        }
      case LogicalKeyboardKey.minus:
        if (isCommandKeyPressed) {
          _zoomDown(duration: repeatInterval);
          return true;
        }
      case LogicalKeyboardKey.arrowDown:
        _goToManipulated((m) => m.translateByDouble(0.0, -widget.params.scrollByArrowKey, 0, 1));
        return true;
      case LogicalKeyboardKey.arrowUp:
        _goToManipulated((m) => m.translateByDouble(0.0, widget.params.scrollByArrowKey, 0, 1));
        return true;
      case LogicalKeyboardKey.arrowLeft:
        _goToManipulated((m) => m.translateByDouble(widget.params.scrollByArrowKey, 0.0, 0, 1));
        return true;
      case LogicalKeyboardKey.arrowRight:
        _goToManipulated((m) => m.translateByDouble(-widget.params.scrollByArrowKey, 0.0, 0, 1));
        return true;
      case LogicalKeyboardKey.keyA:
        if (isCommandKeyPressed) {
          selectAllText();
          return true;
        }
      case LogicalKeyboardKey.keyC:
        if (isCommandKeyPressed) {
          _copyTextSelection();
          return true;
        }
    }
    return false;
  }

  void _goToManipulated(void Function(Matrix4 m) manipulate) {
    final m = _txController.value.clone();
    manipulate(m);
    _txController.value = _makeMatrixInSafeRange(m, forceClamp: true);
  }

  Rect get _visibleRect => _txController.value.calcVisibleRect(_viewSize!);

  /// Set the current page number.
  ///
  /// Please note that the function does not scroll/zoom to the specified page but changes the current page number.
  void _setCurrentPageNumber(int? pageNumber, {bool doSetState = false}) {
    if (pageNumber != null && _pageNumber != pageNumber) {
      debugPrint('[ARGUS-DBG] _setCurrentPageNumber: $_pageNumber -> $pageNumber doSetState=$doSetState');
      _pageNumber = pageNumber;
      if (doSetState) {
        _invalidate();
      }
      if (widget.params.onPageChanged != null) {
        Future.microtask(() => widget.params.onPageChanged?.call(_pageNumber));
      }
      // ARGUS fork (revised 2026-05-14). Sparse pair-with: only the
      // target page and its ±2 neighbours are dragged through
      // `FPDF_LoadPage`, not every page between here and the last
      // contiguous-loaded marker. See `_ensurePageLoadedSparse` for
      // the rationale (a "Sayfaya Git" jump used to load 200+ pages
      // sequentially and balloon RSS by ~300 MB).
      unawaited(_ensurePageLoadedSparse(pageNumber));
      // ARGUS fork F2 (2026-05-14). Pre-render the ±2 neighbour
      // pages so they're warm in the in-memory cache (and, via the
      // E4 pipeline, on disk for next session) before the user
      // navigates to them. Critical for the viewer's 20 000 pt-gap
      // single-page layout where the cache-extent never reaches the
      // adjacent page on its own — without this, every nav button
      // press goes through a cold PDFium render.
      _prefetchNeighbourPages(pageNumber);
    }
  }

  /// ARGUS fork F2 (2026-05-14). Queue preview renders for the pages
  /// immediately around [currentPageNumber] (±1 then ±2 by priority)
  /// so navigating to them feels instant. Idempotent and cheap —
  /// `_cachePagePreviewImage` early-returns when the page is already
  /// cached at the same scale, and the disk-cache check on miss is
  /// the same fast path the paint loop uses.
  void _prefetchNeighbourPages(int currentPageNumber) {
    final doc = _document;
    if (doc == null) return;
    final maxPageNumber = doc.pages.length;
    // Priority order: nearest first. Out-of-bounds entries are
    // skipped, so the actual count depends on where the user is.
    const offsets = [1, -1, 2, -2];
    for (final delta in offsets) {
      final n = currentPageNumber + delta;
      if (n < 1 || n > maxPageNumber) continue;
      final page = doc.pages[n - 1];
      // Skip if metadata hasn't landed yet — `PdfPage.render()`
      // returns null for !isLoaded pages anyway. The eager loader
      // will catch up shortly, and the next page-change tick will
      // re-queue this prefetch.
      if (!page.isLoaded) continue;
      final scale = _estimatePreviewScaleForPrefetch(page);
      final width = page.width * scale;
      final height = page.height * scale;
      if (width < 1 || height < 1) continue;
      final existing = _imageCache.pageImages[n];
      if (existing != null && !existing.isDirty && existing.scale == scale) continue;
      // Fire-and-forget. `_cachePagePreviewImage` has its own
      // per-page synchronisation + cancellation token bookkeeping;
      // concurrent prefetches for different pages just queue up on
      // the PDFium background worker.
      unawaited(_cachePagePreviewImage(_imageCache, page, width, height, scale));
    }
  }

  /// ARGUS fork F2 helper. Computes the preview scale we'd render
  /// [page] at if the paint loop reached it — used for the prefetch
  /// path which doesn't run inside paint and so doesn't have the
  /// same captured-context closure the paint loop builds. Skips the
  /// host's `getPageRenderingScale` callback (which would need a
  /// BuildContext + controller in callback-context); the resulting
  /// prefetch may render at a slightly different scale than the
  /// paint loop ends up requesting, in which case paint just
  /// triggers a re-render — the prefetch was a hint, not a contract.
  double _estimatePreviewScaleForPrefetch(PdfPage page) {
    final maxSize = widget.params.onePassRenderingSizeThreshold;
    if (page.width > maxSize || page.height > maxSize) {
      return min(maxSize / page.width, maxSize / page.height);
    }
    return widget.params.onePassRenderingScaleThreshold;
  }

  double _calcPrimaryAxisVisibility(Rect pageRect, Rect viewportRect, bool isHorizontal) {
    if (isHorizontal) {
      if (pageRect.right <= viewportRect.left || pageRect.left >= viewportRect.right) return 0.0;
      final visibleLeft = pageRect.left < viewportRect.left ? viewportRect.left : pageRect.left;
      final visibleRight = pageRect.right > viewportRect.right ? viewportRect.right : pageRect.right;
      return ((visibleRight - visibleLeft) / pageRect.width).clamp(0.0, 1.0);
    } else {
      if (pageRect.bottom <= viewportRect.top || pageRect.top >= viewportRect.bottom) return 0.0;
      final visibleTop = pageRect.top < viewportRect.top ? viewportRect.top : pageRect.top;
      final visibleBottom = pageRect.bottom > viewportRect.bottom ? viewportRect.bottom : pageRect.bottom;
      return ((visibleBottom - visibleTop) / pageRect.height).clamp(0.0, 1.0);
    }
  }

  int? _guessCurrentPageNumber() {
    if (_layout == null || _viewSize == null) return null;
    // ARGUS fork — Phase H8 (2026-05-14). Single-page mode has at
    // most one non-zero rect in `_layout.pageLayouts`, so the regular
    // visibility-weighted scan would either spin uselessly over N
    // zero-rects or just confirm what we already know. Short-circuit.
    if (widget.params.singlePageMode) {
      return _pageNumber ?? _gotoTargetPageNumber ?? widget.initialPageNumber;
    }
    if (widget.params.calculateCurrentPageNumber != null) {
      return widget.params.calculateCurrentPageNumber!(_visibleRect, _layout!.pageLayouts, _controller!);
    }

    final visibleRect = _visibleRect;
    final layout = _layout!;
    final isHorizontal = layout.documentSize.width > layout.documentSize.height;
    final isSimple = _isSimpleLayout(layout.pageLayouts, isHorizontal);

    // Calculate primary axis visibility for all pages (map: page number -> visibility %)
    final visible = <int, double>{};
    for (var i = 0; i < layout.pageLayouts.length; i++) {
      final pct = _calcPrimaryAxisVisibility(layout.pageLayouts[i], visibleRect, isHorizontal);
      if (pct > 0) visible[i + 1] = pct;
    }

    if (visible.isEmpty) return _pageNumber ?? 1;

    final current = _pageNumber;
    final fullyVisiblePages = visible.entries.where((e) => e.value >= 1.0).map((e) => e.key).toList();

    // 3+ fully visible pages to enter scroll percentage mode, <2 to exit
    // to stop flapping between modes
    if (_usingScrollPercentageMode) {
      if (fullyVisiblePages.length < 2 && isSimple) _usingScrollPercentageMode = false;
    } else {
      if (fullyVisiblePages.length >= 3 || !isSimple) _usingScrollPercentageMode = true;
    }

    // Check goto target
    final gotoVisibility = visible[_gotoTargetPageNumber] ?? 0.0;
    if (gotoVisibility >= 0.5) return _gotoTargetPageNumber;
    if (_gotoTargetPageNumber != null && !_animController.isAnimating) _gotoTargetPageNumber = null;

    // Scroll percentage mode
    if (_usingScrollPercentageMode) {
      final scrollPosition = isHorizontal ? visibleRect.left : visibleRect.top;
      final scrollLength =
          (isHorizontal ? layout.documentSize.width : layout.documentSize.height) -
          (isHorizontal ? visibleRect.width : visibleRect.height);
      final scrollPercentage = scrollLength > 0 ? (scrollPosition / scrollLength).clamp(0.0, 1.0) : 0.0;
      return ((scrollPercentage * layout.pageLayouts.length).floor() + 1).clamp(1, layout.pageLayouts.length);
    }

    // Sticky mode - prefer current page if it is fully visible as long
    // as the first or last page is not fully visible also
    if (current != null) {
      final currentPercentage = visible[current] ?? 0.0;
      if (currentPercentage >= 1.0) {
        // Edge detection: prefer first/last page if also fully visible
        if (fullyVisiblePages.contains(1) && current != 1) return 1;
        if (fullyVisiblePages.contains(layout.pageLayouts.length) && current != layout.pageLayouts.length) {
          return layout.pageLayouts.length;
        }
        return current;
      }
      // Most visible with proximity tie-break
      var maxPercentage = 0.0, maxPage = visible.keys.first;
      for (final entry in visible.entries) {
        if (entry.value > maxPercentage ||
            (entry.value == maxPercentage && (current - entry.key).abs() < (current - maxPage).abs())) {
          maxPercentage = entry.value;
          maxPage = entry.key;
        }
      }
      return maxPage;
    }

    // Should not reach here, but fallback to most visible
    return visible.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Detect if layout is "simple" (sequential pages) vs "complex" (facing pages)
  /// In facing pages, multiple pages can share the same PRIMARY SCROLL axis coordinate
  bool _isSimpleLayout(List<Rect> pageLayouts, bool isHorizontalLayout) {
    if (pageLayouts.length <= 1) return true;

    // Check if any two consecutive pages overlap along the PRIMARY SCROLL axis
    // For horizontal layouts (scroll left-right), check if pages overlap horizontally (same x-range = facing)
    // For vertical layouts (scroll up-down), check if pages overlap vertically (same y-range = facing)
    for (var i = 0; i < pageLayouts.length - 1; i++) {
      final page1 = pageLayouts[i];
      final page2 = pageLayouts[i + 1];

      if (isHorizontalLayout) {
        // Horizontal scroll: pages are "complex" if they overlap horizontally (facing pages side-by-side)
        // In sequential horizontal, page2.left should be >= page1.right (no overlap)
        if (page2.left < page1.right - 1.0) {
          return false; // Overlap detected = facing pages
        }
      } else {
        // Vertical scroll: pages are "complex" if they overlap vertically (facing pages top-bottom)
        // In sequential vertical, page2.top should be >= page1.bottom (no overlap)
        if (page2.top < page1.bottom - 1.0) {
          return false; // Overlap detected = facing pages
        }
      }
    }

    return true;
  }

  /// Returns true if page layouts are changed.
  bool _relayoutPages() {
    if (_document == null) {
      _layout = null;
      return false;
    }
    // ARGUS fork — Phase H (2026-05-14). `singlePageMode` always wins
    // over both the user-supplied `params.layoutPages` and the
    // default multi-page layout — the whole point of the mode is to
    // bypass per-app workarounds like the "20 000 pt-gap fake
    // single-page" layout.
    final PdfPageLayoutFunction layoutFn = widget.params.singlePageMode
        ? _singlePageLayoutPages
        : (widget.params.layoutPages ?? _layoutPages);
    final newLayout = layoutFn(_document!.pages, widget.params);
    if (_layout == newLayout) {
      return false;
    }

    _layout = newLayout;
    return true;
  }

  /// ARGUS fork — Phase H2 (2026-05-14). Lays out every page at the
  /// shared canonical origin `(margin, margin)` with its own
  /// dimensions; `documentSize` is sized for the **target page**
  /// (current/goto-target/initial, whichever applies).
  ///
  /// **Why every page gets a real rect (not `Rect.zero`).** Earlier
  /// drafts of this function used `Rect.zero` for non-target pages so
  /// the existing `rect.intersect(viewport).isEmpty` check in the
  /// paint loop would auto-skip them. That worked for paint but broke
  /// host-app code that reads `pageLayouts[N-1]` directly to convert
  /// PDF coordinates ↔ doc coordinates (argus's focus/zoom regions,
  /// drawing overlay, aidf region targets — every one of those
  /// accessed `controller.layout.pageLayouts[N-1]` for pages OTHER
  /// than the current one). Returning a valid per-page rect at a
  /// shared origin gives those callers something sensible (the page's
  /// page-space → doc-space transform is identity-ish: doc = page +
  /// (margin, margin)) while we use the new paint-loop short-circuit
  /// (`widget.params.singlePageMode` branch in
  /// `_paintPagesCustom`/`_buildPageOverlayWidgets`) to enforce
  /// single-page visibility.
  ///
  /// **Trade-offs.**
  /// - `documentSize` reflects the TARGET page only; if pages vary in
  ///   size, navigating between them may visibly reflow on the
  ///   relayout boundary. Most textbooks are uniform so this is
  ///   barely noticeable.
  /// - All pages share centre coordinates, so the geometric
  ///   eviction-distance metric degenerates. The fork uses
  ///   `(pageNumber - currentPage.pageNumber).abs()` in single-page
  ///   mode instead — see `_evictionDistanceFor`.
  /// - `_isVerticallyMonotone` returns false (all `top == margin`),
  ///   so `visiblePageRange` falls back to linear scan. The paint
  ///   loop short-circuits before consulting that anyway.
  PdfPageLayout _singlePageLayoutPages(List<PdfPage> pages, PdfViewerParams params) {
    if (pages.isEmpty) {
      return PdfPageLayout(pageLayouts: const <Rect>[], documentSize: const Size(100, 100));
    }
    // While a `goToPage` animation is in flight (`_gotoTargetPageNumber`
    // set) we size `documentSize` for the DESTINATION so the matrix
    // can fit it; otherwise the live current page; otherwise the
    // configured initial page.
    final int rawTarget =
        _gotoTargetPageNumber ?? _pageNumber ?? widget.initialPageNumber;
    final int target = rawTarget.clamp(1, pages.length);
    final targetPage = pages[target - 1];
    final double margin = params.margin;
    final rects = List<Rect>.generate(
      pages.length,
      (i) => Rect.fromLTWH(margin, margin, pages[i].width, pages[i].height),
      growable: false,
    );
    return PdfPageLayout(
      pageLayouts: rects,
      documentSize: Size(
        targetPage.width + margin * 2,
        targetPage.height + margin * 2,
      ),
    );
  }

  void _calcCoverFitScale() {
    final params = widget.params;
    final bmh = params.boundaryMargin?.horizontal == double.infinity ? 0 : params.boundaryMargin?.horizontal ?? 0;
    final bmv = params.boundaryMargin?.vertical == double.infinity ? 0 : params.boundaryMargin?.vertical ?? 0;

    if (_viewSize != null) {
      final s1 = _viewSize!.width / (_layout!.documentSize.width + bmh);
      final s2 = _viewSize!.height / (_layout!.documentSize.height + bmv);
      _coverScale = max(s1, s2);
    }
    final pageNumber = _pageNumber ?? _gotoTargetPageNumber;
    if (pageNumber != null && pageNumber >= 1 && pageNumber <= _layout!.pageLayouts.length) {
      final rect = _layout!.pageLayouts[pageNumber - 1];
      final m2 = params.margin * 2;
      _alternativeFitScale = min(
        (_viewSize!.width) / (rect.width + bmh + m2),
        (_viewSize!.height) / (rect.height + bmv + m2),
      );
      if (_alternativeFitScale! <= 0) {
        _alternativeFitScale = null;
      }
    } else {
      _alternativeFitScale = null;
    }
    if (_coverScale == null) {
      _minScale = _defaultMinScale;
      return;
    }
    _minScale = !widget.params.useAlternativeFitScaleAsMinScale
        ? widget.params.minScale
        : _alternativeFitScale == null
        ? _coverScale!
        : min(_coverScale!, _alternativeFitScale!);
  }

  void _calcZoomStopTable() {
    _zoomStops.clear();
    double z;
    if (_alternativeFitScale != null && !_areZoomsAlmostIdentical(_alternativeFitScale!, _coverScale!)) {
      if (_alternativeFitScale! < _coverScale!) {
        _zoomStops.add(_alternativeFitScale!);
        z = _coverScale!;
      } else {
        _zoomStops.add(_coverScale!);
        z = _alternativeFitScale!;
      }
    } else {
      z = _coverScale!;
    }
    // in some case, z may be 0 and it causes infinite loop.
    if (z < 1 / 128) {
      _zoomStops.add(1.0);
      return;
    }
    while (z < widget.params.maxScale) {
      _zoomStops.add(z);
      z *= 2;
    }
    if (!_areZoomsAlmostIdentical(z, widget.params.maxScale)) {
      _zoomStops.add(widget.params.maxScale);
    }

    if (!widget.params.useAlternativeFitScaleAsMinScale) {
      z = _zoomStops.first;
      while (z > widget.params.minScale) {
        z /= 2;
        _zoomStops.insert(0, z);
      }
      if (!_areZoomsAlmostIdentical(z, widget.params.minScale)) {
        _zoomStops.insert(0, widget.params.minScale);
      }
    }
  }

  double _findNextZoomStop(double zoom, {required bool zoomUp, bool loop = true}) {
    if (zoomUp) {
      for (final z in _zoomStops) {
        if (z > zoom && !_areZoomsAlmostIdentical(z, zoom)) return z;
      }
      if (loop) {
        return _zoomStops.first;
      } else {
        return _zoomStops.last;
      }
    } else {
      for (var i = _zoomStops.length - 1; i >= 0; i--) {
        final z = _zoomStops[i];
        if (z < zoom && !_areZoomsAlmostIdentical(z, zoom)) return z;
      }
      if (loop) {
        return _zoomStops.last;
      } else {
        return _zoomStops.first;
      }
    }
  }

  static bool _areZoomsAlmostIdentical(double z1, double z2) => (z1 - z2).abs() < 0.01;

  // Auto-adjust boundaries when content is smaller than the view, centering
  // the content and ensuring InteractiveViewer's scrollPhysics works when specified
  void _adjustBoundaryMargins(Size viewSize, double zoom) {
    final boundaryMargin = widget.params.boundaryMargin ?? EdgeInsets.zero;

    if (boundaryMargin.containsInfinite) {
      _adjustedBoundaryMargins = boundaryMargin;
      return;
    }

    final currentDocumentSize = boundaryMargin.inflateSize(_layout!.documentSize);
    final effectiveWidth = currentDocumentSize.width * zoom;
    final effectiveHeight = currentDocumentSize.height * zoom;
    final extraWidth = effectiveWidth - viewSize.width;
    final extraBoundaryHorizontal = extraWidth < 0 ? (-extraWidth / 2) / zoom : 0.0;
    final extraHeight = effectiveHeight - viewSize.height;
    final extraBoundaryVertical = extraHeight < 0 ? (-extraHeight / 2) / zoom : 0.0;

    _adjustedBoundaryMargins =
        boundaryMargin +
        EdgeInsets.fromLTRB(
          extraBoundaryHorizontal,
          extraBoundaryVertical,
          extraBoundaryHorizontal,
          extraBoundaryVertical,
        );
  }

  List<Widget> _buildPageOverlayWidgets(BuildContext context) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return [];

    final linkWidgets = <Widget>[];
    final overlayWidgets = <Widget>[];
    final targetRect = _getCacheExtentRect();

    // ARGUS fork — Phase F1 (2026-05-14). See `_paintPagesCustom`
    // for the rationale; same trick here. Was O(N pages) per build,
    // now O(visible) thanks to the binary-searched visible range.
    //
    // Phase H short-circuit: in single-page mode the layout deliberately
    // places only one page at non-zero coords, so we know the visible
    // range a priori without consulting the binary search (which would
    // fall back to linear anyway because the layout isn't monotone).
    final ({int begin, int end}) visibleRange;
    if (widget.params.singlePageMode) {
      final int n = (_pageNumber ?? _gotoTargetPageNumber ?? widget.initialPageNumber)
          .clamp(1, _document!.pages.length);
      visibleRange = (begin: n - 1, end: n);
    } else {
      visibleRange = _layout!.visiblePageRange(targetRect);
    }
    for (var i = visibleRange.begin; i < visibleRange.end; i++) {
      final rect = _layout!.pageLayouts[i];
      final intersection = rect.intersect(targetRect);
      if (intersection.isEmpty) continue;

      final page = _document!.pages[i];
      final rectExternal = _documentToRenderBox(rect, renderBox);
      if (rectExternal != null) {
        if (widget.params.linkHandlerParams == null && widget.params.linkWidgetBuilder != null) {
          linkWidgets.add(
            PdfPageLinksOverlay(
              key: Key('#__pageLinks__:${page.pageNumber}'),
              page: page,
              pageRect: rectExternal,
              params: widget.params,
              // FIXME: workaround for link widget eats wheel events.
              wrapperBuilder: (child) => Listener(
                child: child,
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    _onWheelDelta(event);
                  }
                },
              ),
            ),
          );
        }

        final overlay = widget.params.pageOverlaysBuilder?.call(context, rectExternal, page);
        if (overlay != null && overlay.isNotEmpty) {
          overlayWidgets.add(
            Positioned(
              key: Key('#__pageOverlay__:${page.pageNumber}'),
              left: rectExternal.left,
              top: rectExternal.top,
              width: rectExternal.width,
              height: rectExternal.height,
              child: Stack(children: overlay),
            ),
          );
        }

        // ARGUS fork — Phase Y3 (2026-05-14). When a page is visible
        // but its preview image hasn't landed yet (lazy metadata load
        // still resolving, PDFium render still queued, or jump-to-page
        // from far away), `_paintPagesCustom` draws nothing in the
        // page rect (Phase N6 removed the white fallback). To avoid
        // leaving the user staring at an empty rectangle, drop a
        // small centered indeterminate `CircularProgressIndicator`
        // over the page. As soon as the preview cache fills, the
        // next invalidate-driven rebuild removes this overlay
        // automatically because the condition flips.
        final bool hasPreview =
            _imageCache.pageImages[page.pageNumber] != null ||
                _imageCache.pageImagesPartial[page.pageNumber] != null;
        if (!hasPreview) {
          final placeholder = widget.params.loadingPlaceholderBuilder?.call(
                context,
                page,
                rectExternal,
              ) ??
              _defaultLoadingPlaceholder(context, rectExternal);
          overlayWidgets.add(
            Positioned(
              key: Key('#__pageLoading__:${page.pageNumber}'),
              left: rectExternal.left,
              top: rectExternal.top,
              width: rectExternal.width,
              height: rectExternal.height,
              child: IgnorePointer(child: placeholder),
            ),
          );
        }
      }
    }

    return [...linkWidgets, ...overlayWidgets];
  }

  /// Default in-page loading indicator drawn by [_buildPageOverlayWidgets]
  /// when neither a preview nor a partial render is available yet for a
  /// visible page. A small centred [CircularProgressIndicator] scaled to
  /// the page footprint, so wide pages don't get giant spinners.
  Widget _defaultLoadingPlaceholder(BuildContext context, Rect pageRect) {
    final double minSide = pageRect.shortestSide;
    // Indicator is ~6% of the page's shortest side, clamped so it's
    // legible on thumbnails and not absurdly large on full-page renders.
    final double indicatorSize = minSide.clamp(40.0, 72.0) * 0.6;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: SizedBox(
        width: indicatorSize,
        height: indicatorSize,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
        ),
      ),
    );
  }

  void _onSelectionChange() {
    _textSelectionChangedDebounceTimer?.cancel();
    _textSelectionChangedDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      widget.params.textSelectionParams?.onTextSelectionChange?.call(this);
    });
  }

  Rect _getCacheExtentRect() {
    final visibleRect = _visibleRect;
    return visibleRect.inflateHV(
      horizontal: visibleRect.width * widget.params.horizontalCacheExtent,
      vertical: visibleRect.height * widget.params.verticalCacheExtent,
    );
  }

  Rect? _documentToRenderBox(Rect rect, RenderBox renderBox) {
    final tl = _documentToGlobal(rect.topLeft);
    if (tl == null) return null;
    final br = _documentToGlobal(rect.bottomRight);
    if (br == null) return null;
    return Rect.fromPoints(renderBox.globalToLocal(tl), renderBox.globalToLocal(br));
  }

  /// [_CustomPainter] calls the function to paint PDF pages.
  void _paintPages(ui.Canvas canvas, ui.Size size) {
    if (!_initialized) return;
    _paintPagesCustom(
      canvas,
      cache: _imageCache,
      maxImageCacheBytes: widget.params.maxImageBytesCachedOnMemory,
      targetRect: _visibleRect,
      cacheTargetRect: _getCacheExtentRect(),
      scale: _currentZoom * MediaQuery.of(context).devicePixelRatio,
      enableLowResolutionPagePreview: widget.params.behaviorControlParams.enableLowResolutionPagePreview,
      filterQuality: FilterQuality.low,
    );
  }

  void _paintPagesCustom(
    ui.Canvas canvas, {
    required _PdfPageImageCache cache,
    required int maxImageCacheBytes,
    required double scale,
    required Rect targetRect,
    Rect? cacheTargetRect,
    bool enableLowResolutionPagePreview = true,
    FilterQuality filterQuality = FilterQuality.high,
  }) {
    final unusedPageList = <int>[];
    final dropShadowPaint = widget.params.pageDropShadow?.toPaint()?..style = PaintingStyle.fill;
    cacheTargetRect ??= targetRect;

    // ARGUS fork — Phase F1 sparse paint loop (2026-05-14).
    //
    // The original implementation iterated EVERY page in the document
    // on every paint just to test `rect.intersect(cacheTargetRect)`.
    // For a 1000-page PDF at 60 fps that's 60 000 wasted intersect
    // tests per second of scroll. With the binary-search visible
    // range from [PdfPageLayout.visiblePageRange] (also a fork
    // addition) the inner loop becomes O(visible) ≈ 3-5 iterations.
    //
    // Off-screen pages still need their pending renders cancelled and
    // their stale cache entries marked unused — but only the ones
    // that actually HAVE pending renders or cache entries. We walk
    // those maps directly instead of probing every page.
    //
    // Phase H short-circuit: see `_buildPageOverlayWidgets` for the
    // same trick — single-page mode pins the range to one entry.
    final ({int begin, int end}) visibleRange;
    if (widget.params.singlePageMode) {
      final int n = (_pageNumber ?? _gotoTargetPageNumber ?? widget.initialPageNumber)
          .clamp(1, _document!.pages.length);
      visibleRange = (begin: n - 1, end: n);
    } else {
      visibleRange = _layout!.visiblePageRange(cacheTargetRect);
    }

    void handleOffScreenPage(int pageNumber) {
      final hadTokens = cache.cancellationTokens[pageNumber]?.isNotEmpty ?? false;
      cache.cancelPendingRenderings(pageNumber);
      if (cache.pageImages.containsKey(pageNumber)) {
        unusedPageList.add(pageNumber);
      }
      if (hadTokens) {
        debugPrint('[ARGUS-DBG] handleOffScreenPage cancelled tokens for page=$pageNumber (visible range was $visibleRange)');
      }
    }

    // ARGUS fork — Phase K1 (2026-05-14). The F2 neighbour-prefetch
    // hook fires `_cachePagePreviewImage` for pages N±1 / N±2 from
    // inside `_setCurrentPageNumber`, which registers a cancellation
    // token in `cancellationTokens` BEFORE the render's synchronized
    // block runs. The very next paint frame's off-screen walk used to
    // see those tokens as "outside the visible range" and cancel them
    // immediately — defeating F2 entirely (the prefetched pages
    // bailed out of the render at the cancellation check inside the
    // synchronized block, so only the current page ever rendered).
    //
    // The fix: skip BOTH the cancellation pass AND the unused-list
    // pass for pages within a small radius of the current page in
    // single-page mode. Those are exactly the pages F2 is intentionally
    // warming — cancelling their pending renders OR marking their
    // already-cached entries for byte-budget eviction is
    // counter-productive. Genuine off-screen pages (beyond ±2) still
    // get cancelled and eviction-eligible, keeping memory bounded.
    final int prefetchPreserveRadius = widget.params.singlePageMode ? 2 : 0;
    final int currentPageNumberForPreserve =
        _pageNumber ?? _gotoTargetPageNumber ?? widget.initialPageNumber;
    bool _isInPrefetchZone(int pageNumber) =>
        prefetchPreserveRadius > 0 &&
        (pageNumber - currentPageNumberForPreserve).abs() <= prefetchPreserveRadius;

    // Snapshot keys before mutating: `cancelPendingRenderings` /
    // `add` may modify the underlying maps.
    final cachedKeysSnapshot = cache.pageImages.keys.toList(growable: false);
    for (final pageNumber in cachedKeysSnapshot) {
      final i = pageNumber - 1;
      if (i < visibleRange.begin || i >= visibleRange.end) {
        if (_isInPrefetchZone(pageNumber)) continue;
        handleOffScreenPage(pageNumber);
      }
    }
    final pendingKeysSnapshot = cache.cancellationTokens.keys.toList(growable: false);
    for (final pageNumber in pendingKeysSnapshot) {
      final i = pageNumber - 1;
      if (i < visibleRange.begin || i >= visibleRange.end) {
        if (_isInPrefetchZone(pageNumber)) continue;
        // Skip log if list is already empty (recurring no-op when the
        // map keeps the empty key around forever).
        if ((cache.cancellationTokens[pageNumber]?.isEmpty ?? true)) continue;
        debugPrint('[ARGUS-DBG] cancelling pending render page=$pageNumber (visible range $visibleRange)');
        cache.cancelPendingRenderings(pageNumber);
      }
    }

    for (var i = visibleRange.begin; i < visibleRange.end; i++) {
      final rect = _layout!.pageLayouts[i];
      final intersection = rect.intersect(cacheTargetRect);
      if (intersection.isEmpty) {
        // Range-superset edge case: a page in the binary-search range
        // doesn't actually overlap the viewport (e.g. extreme x
        // offset on a custom layout). Treat as off-screen.
        //
        // ARGUS fork — Phase N (2026-05-13). EXCEPT in singlePageMode,
        // where every nav goes through a brief matrix-transition window
        // (`_goTo` with Duration.zero still routes through the
        // AnimationController's listener, so `_visibleRect` is stale
        // for the first paint frame after `_setCurrentPageNumber`).
        // During that window the just-navigated-to target page can be
        // misclassified as "off-screen", which used to cancel its
        // freshly-registered render token AND mark it for byte-budget
        // eviction. The K1 prefetch zone (±2 in single-page mode) was
        // already protecting the snapshot loops above; extend the same
        // protection to the inline path so the current page (and its
        // immediate prefetch neighbours) cannot be cancelled by a
        // transient intersect miss.
        if (_isInPrefetchZone(i + 1)) continue;
        handleOffScreenPage(i + 1);
        continue;
      }

      final page = _document!.pages[i];
      final previewImage = cache.pageImages[page.pageNumber];
      final partial = cache.pageImagesPartial[page.pageNumber];

      final getPageRenderingScale =
          widget.params.getPageRenderingScale ??
          (context, page, controller, estimatedScale) {
            final max = widget.params.onePassRenderingSizeThreshold;
            if (page.width > max || page.height > max) {
              return min(max / page.width, max / page.height);
            }
            return estimatedScale;
          };

      final previewScaleLimit = getPageRenderingScale(
        context,
        page,
        _controller!,
        widget.params.onePassRenderingScaleThreshold,
      );

      // ARGUS fork — Phase N7 (2026-05-13). The drop shadow used to draw
      // unconditionally, so a freshly-scrolled-to page that hadn't yet
      // rendered showed up as a hollow shadow-rect outline on the dark
      // editor background — visible "frame around nothing" effect the
      // user explicitly rejected ("transparan kalsın işte orta bölge").
      // Gate the shadow on the preview image existing: once there's
      // pixel content to surround, draw the shadow; until then the
      // entire page footprint stays transparent and the viewer's
      // backgroundColor shows through cleanly.
      if (dropShadowPaint != null && previewImage != null) {
        final offset = widget.params.pageDropShadow!.offset;
        final spread = widget.params.pageDropShadow!.spreadRadius;
        final shadowRect = rect.translate(offset.dx, offset.dy).inflateHV(horizontal: spread, vertical: spread);
        canvas.drawRect(shadowRect, dropShadowPaint);
      }

      if (widget.params.pageBackgroundPaintCallbacks != null) {
        for (final callback in widget.params.pageBackgroundPaintCallbacks!) {
          callback(canvas, rect, page);
        }
      }

      if (enableLowResolutionPagePreview && previewImage != null) {
        canvas.drawImageRect(
          previewImage.image,
          Rect.fromLTWH(0, 0, previewImage.image.width.toDouble(), previewImage.image.height.toDouble()),
          rect,
          Paint()..filterQuality = filterQuality,
        );
      }
      // ARGUS fork — Phase N6 (2026-05-13). The upstream `else` branch
      // here filled the page rect with `Colors.white` as a fallback so
      // the user could see "where the page will be" before its render
      // landed. On dark themes (argus editor uses a `0xFF26282E`
      // slate backgroundColor) this manifested as a ~500 ms white
      // flash whenever a page first scrolled into view — visually
      // jarring and conveys nothing meaningful (a featureless white
      // rectangle is no more informative than the bare background).
      // Dropping the fill makes the unrendered region transparent;
      // the viewer's `params.backgroundColor` shows through naturally
      // until the preview image arrives. The drop-shadow above (line
      // 1670) still draws so the page boundary is visually inferable.

      if (enableLowResolutionPagePreview &&
          (previewImage == null || previewImage.isDirty || previewImage.scale != previewScaleLimit)) {
        _requestPagePreviewImageCached(cache, page, previewScaleLimit);
      }

      final pageScale = scale * max(rect.width / page.width, rect.height / page.height);
      if (!enableLowResolutionPagePreview || pageScale > previewScaleLimit) {
        _requestRealSizePartialImage(cache, page, pageScale, targetRect);
      }

      if ((!enableLowResolutionPagePreview || pageScale > previewScaleLimit) && partial != null) {
        partial.draw(canvas, filterQuality);
      }

      final selectionColor =
          Theme.of(context).textSelectionTheme.selectionColor ?? DefaultSelectionStyle.of(context).selectionColor!;
      final text = _getCachedTextOrDelayLoadText(page.pageNumber);
      if (text != null) {
        final selectionInPage = _loadTextSelectionForPageNumber(page.pageNumber);
        if (selectionInPage != null) {
          for (final r in selectionInPage.enumerateFragmentBoundingRects()) {
            canvas.drawRect(
              r.bounds.toRectInDocument(page: page, pageRect: rect),
              Paint()
                ..color = selectionColor
                ..style = PaintingStyle.fill,
            );
          }
        }
      }

      if (_canvasLinkPainter.isEnabled) {
        _canvasLinkPainter.paintLinkHighlights(canvas, rect, page);
      }

      if (widget.params.pagePaintCallbacks != null) {
        for (final callback in widget.params.pagePaintCallbacks!) {
          callback(canvas, rect, page);
        }
      }

      if (unusedPageList.isNotEmpty) {
        final currentPageNumber = _pageNumber;
        if (currentPageNumber != null && currentPageNumber > 0) {
          final currentPage = _document!.pages[currentPageNumber - 1];
          cache.removeCacheImagesIfCacheBytesExceedsLimit(
            unusedPageList,
            maxImageCacheBytes,
            currentPage,
            dist: _evictionDistanceFor(currentPage),
          );
        }
      }
    }

    // ARGUS fork addition (2026-05-13): proactive hard page-count cap.
    //
    // The byte-budget eviction inside the loop above only fires when a
    // page actually leaves the cache-extent rect AND the byte total has
    // already overshot. On low-RAM smart-board hardware a fast
    // scroll-thumb drag can enqueue many pages before either condition is
    // tripped, causing the RAM spike documented in pdfrx issue #604
    // (300 MB → 1.7 GB on 500+ page PDFs). When
    // [PdfViewerParams.maxCachedPageCount] is set, we evict the farthest
    // cached pages (by document-coordinate distance from the current
    // page) at the end of every paint frame until the cache holds no
    // more than that many entries — a hard ceiling that's independent of
    // per-page render size.
    final maxPageCount = widget.params.maxCachedPageCount;
    if (maxPageCount != null && maxPageCount >= 1) {
      final currentPageNumber = _pageNumber;
      if (currentPageNumber != null && currentPageNumber > 0) {
        final currentPage = _document!.pages[currentPageNumber - 1];
        cache.removeCacheImagesIfPageCountExceedsLimit(
          maxPageCount,
          currentPage,
          dist: _evictionDistanceFor(currentPage),
        );
      }
    }
  }

  /// ARGUS fork — Phase H7 (2026-05-14). Eviction distance function
  /// shared between the byte-budget and page-count cap eviction paths.
  ///
  /// **Multi-page mode**: geometric distance between page-rect centres —
  /// preserves the original pdfrx behaviour where pages that are
  /// far away in document space evict first.
  ///
  /// **Single-page mode**: page-number distance instead, because the
  /// `Rect.zero` rects for non-current pages would make the geometric
  /// metric report identical distance for everything. Keeping the
  /// immediate neighbours (`N±1`, `N±2` warmed by the F2 prefetch)
  /// alive is what we want — they're the destinations the user is most
  /// likely to navigate to next.
  double Function(int pageNumber) _evictionDistanceFor(PdfPage currentPage) {
    if (widget.params.singlePageMode) {
      final currentNumber = currentPage.pageNumber;
      return (pageNumber) => (pageNumber - currentNumber).abs().toDouble();
    }
    return (pageNumber) =>
        (_layout!.pageLayouts[pageNumber - 1].center -
                _layout!.pageLayouts[currentPage.pageNumber - 1].center)
            .distanceSquared;
  }

  /// Loads text for the specified page number.
  ///
  /// If the text is not loaded yet, it will be loaded asynchronously
  /// and [onTextLoaded] callback will be called when the text is loaded.
  /// If [onTextLoaded] is not provided and [invalidate] is true, the widget will be rebuilt when the text is loaded.
  PdfPageText? _getCachedTextOrDelayLoadText(int pageNumber, {void Function()? onTextLoaded, bool invalidate = true}) {
    final page = _document!.pages[pageNumber - 1];
    if (!page.isLoaded) return null;
    if (_textCache.containsKey(pageNumber)) return _textCache[pageNumber];
    if (onTextLoaded == null && invalidate) {
      onTextLoaded = _invalidate;
    }
    _loadTextAsync(pageNumber, onTextLoaded: onTextLoaded);
    return null;
  }

  Future<PdfPageText?> _loadTextAsync(int pageNumber, {void Function()? onTextLoaded}) async {
    final page = _document!.pages[pageNumber - 1];
    if (!page.isLoaded) return null;
    if (_textCache.containsKey(pageNumber)) return _textCache[pageNumber]!;
    return await synchronized(() async {
      if (_textCache.containsKey(pageNumber)) return _textCache[pageNumber]!;
      final page = _document!.pages[pageNumber - 1];
      if (!page.isLoaded) return null;
      final text = await page.loadStructuredText();
      _textCache[pageNumber] = text;
      if (onTextLoaded != null) {
        onTextLoaded();
      }
      return text;
    });
  }

  bool _hitTestForTextSelection(ui.Offset position) {
    if (_selPartMoving != _TextSelectionPart.free && enableSelectionHandles) return false;
    if (_document == null || _layout == null) return false;
    // ARGUS fork — Phase F1 (2026-05-14). O(N) page scan → O(log N)
    // binary search via [PdfPageLayout.pageIndexContaining].
    final i = _layout!.pageIndexContaining(position);
    if (i < 0) return false;
    final pageRect = _layout!.pageLayouts[i];
    final page = _document!.pages[i];
    final text = _getCachedTextOrDelayLoadText(
      page.pageNumber,
      invalidate: false,
    ); // the routine may be called multiple times, we can ignore the chance
    if (text == null) return false;
    for (final f in text.fragments) {
      final rect = f.bounds.toRectInDocument(page: page, pageRect: pageRect).inflate(_hitTestMargin);
      if (rect.contains(position)) {
        return true;
      }
    }
    return false;
  }

  PdfPageLayout _layoutPages(List<PdfPage> pages, PdfViewerParams params) {
    final width = pages.fold(0.0, (w, p) => max(w, p.width)) + params.margin * 2;

    final pageLayout = <Rect>[];
    var y = params.margin;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final rect = Rect.fromLTWH((width - page.width) / 2, y, page.width, page.height);
      pageLayout.add(rect);
      y += page.height + params.margin;
    }

    return PdfPageLayout(pageLayouts: pageLayout, documentSize: Size(width, y));
  }

  /// Re-emit the current matrix on [_updateStream] so the `StreamBuilder`
  /// in [build] rebuilds. Coalesced via a post-frame callback so that a
  /// burst of invalidations within one frame produces a single rebuild.
  ///
  /// ARGUS fork addition (2026-05-13). The original implementation called
  /// `_updateStream.add(_txController.value)` synchronously on every
  /// invocation. For a 1000-page PDF, [PdfDocument.loadPagesProgressively]
  /// emits hundreds of `PdfDocumentPageStatusChangedEvent`s during the
  /// initial scan; each one calls [_invalidate] (see [_onDocumentEvent]
  /// FIXME). That used to mean hundreds of `StreamBuilder` rebuilds — each
  /// re-running [_relayoutPages] (O(N)) and [_paintPagesCustom] (O(N))
  /// during cold open. With this coalescer all invalidations that arrive
  /// before the next frame draws collapse into one rebuild, which alone
  /// removed multi-second cold-open jank on 500+ page docs.
  ///
  /// We pair `addPostFrameCallback` with `scheduleFrame` so that the
  /// callback still fires when the app is otherwise idle (e.g. document
  /// events arriving between user interactions).
  void _invalidate() {
    if (_invalidateScheduled || !mounted) return;
    _invalidateScheduled = true;
    final binding = WidgetsBinding.instance;
    binding.scheduleFrame();
    binding.addPostFrameCallback((_) {
      _invalidateScheduled = false;
      if (!mounted) return;
      _updateStream.add(_txController.value);
    });
  }

  bool _invalidateScheduled = false;

  Future<void> _requestPagePreviewImageCached(_PdfPageImageCache cache, PdfPage page, double scale) async {
    final width = page.width * scale;
    final height = page.height * scale;
    if (width < 1 || height < 1) return;

    // if this is the first time to render the page, render it immediately
    if (!cache.pageImages.containsKey(page.pageNumber)) {
      _cachePagePreviewImage(cache, page, width, height, scale);
      return;
    }

    cache.pageImageRenderingTimers[page.pageNumber]?.cancel();
    if (!mounted) return;
    cache.pageImageRenderingTimers[page.pageNumber] = Timer(
      widget.params.behaviorControlParams.pageImageCachingDelay,
      () => _cachePagePreviewImage(cache, page, width, height, scale),
    );
  }

  Future<void> _cachePagePreviewImage(
    _PdfPageImageCache cache,
    PdfPage page,
    double width,
    double height,
    double scale,
  ) async {
    if (!mounted) return;
    final prev = cache.pageImages[page.pageNumber];
    if (prev != null && !prev.isDirty && prev.scale == scale) {
      return;
    }

    // ARGUS fork — Phase Y2 (2026-05-14, revised same day to use the
    // sparse loader). When `_loadDelayed` no longer pre-loads every
    // page in the document, a navigation jump (e.g. page 1 → 100)
    // may arrive at this render path BEFORE the page's PDFium
    // metadata has been resolved. `page.render` returns null when
    // `!page.isLoaded` (see pdfrx_pdfium.dart:~1295), which the
    // paint loop then draws as a transparent / white fallback rect.
    // Block on the SPARSE loader (`_ensurePageLoadedSparse`) so the
    // worker populates THIS page (+ ±2 neighbours) — not every
    // intermediate page between the last contiguous marker and the
    // target. The contiguous variant added ~300 MB of RSS on a
    // 270-page textbook when the user jumped from page 1 to the
    // last page; the sparse variant touches at most 5 pages.
    if (!page.isLoaded) {
      await _ensurePageLoadedSparse(page.pageNumber);
      if (!mounted) return;
      // `_loadPagesInLimitedTime` rebuilds the document's `pages` list
      // with fresh PdfPage instances each batch, so the `page` we were
      // handed may now be a stale placeholder pointing at the old
      // `isLoaded: false` snapshot. Re-resolve from the document so the
      // render call below gets the live handle.
      final List<PdfPage> docPages = _document?.pages ?? const <PdfPage>[];
      if (page.pageNumber - 1 < docPages.length) {
        page = docPages[page.pageNumber - 1];
      }
      if (!page.isLoaded) {
        // Still not loaded (load was aborted, document swapped, etc.).
        // Drop the request quietly; the next paint frame will retry.
        return;
      }
    }

    // ARGUS fork — Phase M3+M5 REVERTED (2026-05-13). Going back to
    // upstream's `cache.synchronized` wrap.
    //
    // Why we reverted:
    // - M3 had removed the lock to fix a "page 2's synchronized
    //   callback never fires" bug, but with the lock gone the
    //   render path triggered an unbounded paint-loop render storm
    //   (60 fps × seconds = hundreds of duplicate render queue jobs
    //   per page).
    // - M5 added an explicit `pagesBeingRendered` Set as a paint-loop
    //   dedupe. After M5 the user reported even page 1 stopped
    //   rendering — symptoms got strictly worse, not better.
    //
    // The upstream lock provides dedupe naturally: callers that wait
    // on the lock re-check `cache.pageImages[N]` after acquiring it,
    // so a single synchronized callback renders, populates the cache,
    // and subsequent waiters bail via `BAIL_HAVE_PREV`. The "page 2
    // stuck on synchronized" symptom we attributed to the lock will
    // be re-investigated with a different hypothesis next pass
    // (likely F2 prefetch interaction or BackgroundWorker queue).
    //
    // M2 [ARGUS-DBG] debug prints kept — still load-bearing for the
    // next round of diagnosis.
    //
    // Disk cache lookup (E4 + L1) preserved structurally — `renderCache`
    // is null in argus apps (M1 disabled) so the block is dead code
    // there, but kept so a future re-enable doesn't need to re-derive
    // the disk-first-then-PDFium ordering.
    final renderCache = widget.params.renderCache;
    final doc = _document;
    if (renderCache != null && doc != null && prev == null) {
      try {
        final cachedPng = await renderCache
            .tryGet(
              document: doc,
              page: page,
              scale: scale,
            )
            .timeout(const Duration(milliseconds: 500), onTimeout: () => null);
        if (cachedPng != null && mounted) {
          try {
            final codec = await ui.instantiateImageCodec(cachedPng);
            final frame = await codec.getNextFrame();
            codec.dispose();
            if (mounted && cache.pageImages[page.pageNumber] == null) {
              cache.pageImages[page.pageNumber] = _PdfImageWithScale(frame.image, scale);
              _invalidate();
              return;
            }
            frame.image.dispose();
          } catch (_) {
            // PNG decode or instantiate failed — fall through to PDFium.
          }
        }
      } catch (_) {
        // Disk cache lookup itself failed — fall through silently.
      }
    }

    final cancellationToken = page.createCancellationToken();
    cache.addCancellationToken(page.pageNumber, cancellationToken);
    debugPrint('[ARGUS-DBG] _cachePagePreviewImage ENTER page=${page.pageNumber} scale=$scale w=$width h=$height isLoaded=${page.isLoaded}');
    await cache.synchronized(() async {
      if (!mounted || cancellationToken.isCanceled) {
        debugPrint('[ARGUS-DBG] _cachePagePreviewImage BAIL_PRE_RENDER page=${page.pageNumber}');
        return;
      }
      // Re-check inside the lock — a prior synchronized callback may
      // have rendered this page while we waited.
      final prevInLock = cache.pageImages[page.pageNumber];
      if (prevInLock != null && !prevInLock.isDirty && prevInLock.scale == scale) {
        debugPrint('[ARGUS-DBG] _cachePagePreviewImage BAIL_HAVE_PREV page=${page.pageNumber}');
        return;
      }
      debugPrint('[ARGUS-DBG] _cachePagePreviewImage rendering page=${page.pageNumber}');
      PdfImage? img;
      try {
        img = await page.render(
          fullWidth: width,
          fullHeight: height,
          backgroundColor: 0xffffffff,
          annotationRenderingMode: widget.params.annotationRenderingMode,
          flags: widget.params.limitRenderingCache ? PdfPageRenderFlags.limitedImageCache : PdfPageRenderFlags.none,
          cancellationToken: cancellationToken,
        );
        debugPrint('[ARGUS-DBG] _cachePagePreviewImage page.render returned page=${page.pageNumber} img=${img != null ? "ok(${img.width}x${img.height})" : "null"} cancelled=${cancellationToken.isCanceled}');
        if (img == null || !mounted || cancellationToken.isCanceled) return;

        final renderedImage = await img.createImage();
        final existing = cache.pageImages[page.pageNumber];
        if (existing != null && !existing.isDirty && existing.scale == scale) {
          renderedImage.dispose();
          debugPrint('[ARGUS-DBG] _cachePagePreviewImage RACED page=${page.pageNumber}');
          return;
        }
        existing?.dispose();
        cache.pageImages[page.pageNumber] = _PdfImageWithScale(renderedImage, scale);
        debugPrint('[ARGUS-DBG] _cachePagePreviewImage CACHED page=${page.pageNumber} image=${renderedImage.width}x${renderedImage.height}');
        _invalidate();

        if (renderCache != null && doc != null) {
          unawaited(
            _persistRenderToDiskCache(renderCache, doc, page, scale, renderedImage),
          );
        }
      } catch (e, st) {
        debugPrint('[ARGUS-DBG] _cachePagePreviewImage CAUGHT page=${page.pageNumber} error=$e\n$st');
        return;
      } finally {
        img?.dispose();
      }
    });
    debugPrint('[ARGUS-DBG] _cachePagePreviewImage EXIT page=${page.pageNumber}');
  }

  /// ARGUS fork helper (2026-05-14, E4 + L1). PNG-encodes a freshly
  /// rendered page bitmap and hands it to the host app's disk cache.
  /// Failure is silent. PNG encode AND the cache write are both
  /// capped at 5 s — on Windows we've seen `flutter_cache_manager`'s
  /// underlying sqflite layer hang indefinitely if its DB hasn't been
  /// set up, and an `unawaited` leak isn't a hang you can recover
  /// from on shutdown (`stopBackgroundWorker` waits for stragglers).
  /// 5 s is long enough that a real disk write on a slow USB stick
  /// still succeeds, short enough that a wedged cache layer doesn't
  /// strand the process.
  Future<void> _persistRenderToDiskCache(
    PdfPageRenderCache renderCache,
    PdfDocument doc,
    PdfPage page,
    double scale,
    ui.Image image,
  ) async {
    try {
      final byteData = await image
          .toByteData(format: ui.ImageByteFormat.png)
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (byteData == null) return;
      await renderCache
          .put(
            document: doc,
            page: page,
            scale: scale,
            pngBytes: byteData.buffer.asUint8List(),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Disk cache writes are best-effort — never raise.
    }
  }

  Future<void> _requestRealSizePartialImage(
    _PdfPageImageCache cache,
    PdfPage page,
    double scale,
    Rect targetRect,
  ) async {
    final pageRect = _layout!.pageLayouts[page.pageNumber - 1];
    final rect = pageRect.intersect(targetRect);
    final prev = cache.pageImagesPartial[page.pageNumber];
    if (prev != null && !prev.isDirty && prev.rect == rect && prev.scale == scale) return;
    if (rect.width < 1 || rect.height < 1) return;

    // ⚠⚠⚠ ARGUS fork (2026-08-20) — DO NOT RESTART AN IDENTICAL REQUEST.
    //
    // Field report: *"the first page opened, and the first shared-text
    // question, are blurry; later pages are fine. I can see it sharpen a
    // few ms later."*
    //
    // The sharp (real-size) pass is what removes that blur: until it
    // lands, the low-resolution preview is drawn UPSCALED, because the
    // displayed scale is `zoom * devicePixelRatio` while the preview is
    // capped at `onePassRenderingScaleThreshold` (2.0 in ARGUS).
    //
    // Upstream cancelled the pending request unconditionally on the next
    // line. `_paintPagesCustom` runs on EVERY repaint, and this viewer
    // repaints often (ink ticks, provider updates, the fit-retry loop at
    // open, focus animations). Each of those repaints killed the render
    // that was already in flight FOR THE VERY SAME rect and scale and
    // started it over — so the sharp pass was starved for as long as the
    // repaint burst lasted. On a freshly opened document that burst is
    // longest (fit retries + page-metadata sweep + status updates), which
    // is exactly why the FIRST page was the blurry one.
    //
    // ⚠ Cancelling is still correct when the request CHANGED (the user
    //   zoomed or panned) — that render's output is stale. The bug was
    //   cancelling an identical one.
    final pendingReq = cache.pageImagePartialRenderingRequests[page.pageNumber];
    // ⚠ `!isCanceled` IS LOAD-BEARING: if a request were cancelled from
    //   elsewhere and its bookkeeping entry stayed behind, this guard would
    //   block every future request and the page would NEVER sharpen — a
    //   worse failure than the bug being fixed. A cancelled entry is
    //   treated as absent.
    if (pendingReq != null &&
        !pendingReq.cancellationToken.isCanceled &&
        pendingReq.rect == rect &&
        pendingReq.scale == scale) {
      return; // already on its way for exactly this view — let it finish
    }
    pendingReq?.cancel();

    final cancellationToken = page.createCancellationToken();
    late final _PdfPartialImageRenderingRequest req;
    req = _PdfPartialImageRenderingRequest(
      Timer(widget.params.behaviorControlParams.partialImageLoadingDelay, () async {
        if (!mounted || cancellationToken.isCanceled) {
          if (identical(cache.pageImagePartialRenderingRequests[page.pageNumber], req)) {
            cache.pageImagePartialRenderingRequests.remove(page.pageNumber);
          }
          return;
        }
        final newImage = await _createRealSizePartialImage(cache, page, scale, rect, cancellationToken);
        if (newImage != null) {
          cache.pageImagesPartial.remove(page.pageNumber)?.dispose();
          cache.pageImagesPartial[page.pageNumber] = newImage;
          _invalidate();
        }
        // ⚠ Drop the bookkeeping entry once finished, otherwise the guard
        //   above would treat this completed request as "still pending"
        //   and a later genuine re-request (dirty cache, new page) would
        //   never be issued.
        if (identical(cache.pageImagePartialRenderingRequests[page.pageNumber], req)) {
          cache.pageImagePartialRenderingRequests.remove(page.pageNumber);
        }
      }),
      cancellationToken,
      rect,
      scale,
    );
    cache.pageImagePartialRenderingRequests[page.pageNumber] = req;
  }

  Future<_PdfImageWithScaleAndRect?> _createRealSizePartialImage(
    _PdfPageImageCache cache,
    PdfPage page,
    double scale,
    Rect rect,
    PdfPageRenderCancellationToken cancellationToken,
  ) async {
    if (!mounted || cancellationToken.isCanceled) return null;
    final pageRect = _layout!.pageLayouts[page.pageNumber - 1];
    final inPageRect = rect.translate(-pageRect.left, -pageRect.top);
    final x = (inPageRect.left * scale).toInt();
    final y = (inPageRect.top * scale).toInt();
    final width = (inPageRect.width * scale).toInt();
    final height = (inPageRect.height * scale).toInt();
    if (width < 1 || height < 1) return null;

    var flags = 0;
    if (widget.params.limitRenderingCache) flags |= PdfPageRenderFlags.limitedImageCache;

    PdfImage? img;
    try {
      img = await page.render(
        x: x,
        y: y,
        width: width,
        height: height,
        fullWidth: pageRect.width * scale,
        fullHeight: pageRect.height * scale,
        backgroundColor: 0xffffffff,
        annotationRenderingMode: widget.params.annotationRenderingMode,
        flags: flags,
        cancellationToken: cancellationToken,
      );
      if (img == null || !mounted || cancellationToken.isCanceled) return null;
      return _PdfImageWithScaleAndRect(await img.createImage(), scale, rect, x, y);
    } catch (e) {
      return null; // ignore error
    } finally {
      img?.dispose();
    }
  }

  void _onWheelDelta(PointerScrollEvent event) {
    _startInteraction();
    try {
      // Handle Ctrl+wheel for zooming
      // NOTE: On Flutter Web on Windows, Ctrl+wheel is handled by Flutter engine and it never gets here; and if
      // you set scrollPhysics to non-null, it causes layout issue on zooming out (see #547).
      if (HardwareKeyboard.instance.isControlPressed) {
        // NOTE: I believe that either only dx or dy is set, but I don't know which one is guaranteed to be set.
        // So, I just add both values.
        var zoomFactor = -(event.scrollDelta.dx + event.scrollDelta.dy) / 120.0;
        final newZoom = (_currentZoom * (pow(1.2, zoomFactor))).clamp(widget.params.minScale, widget.params.maxScale);
        if (_areZoomsAlmostIdentical(newZoom, _currentZoom)) return;
        // NOTE: _onWheelDelta may be called from other widget's context and localPosition may be incorrect.
        _controller!.zoomOnLocalPosition(
          localPosition: _controller!.globalToLocal(event.position)!,
          newZoom: newZoom,
          duration: Duration.zero,
        );
        return;
      }

      final dx = -event.scrollDelta.dx * widget.params.scrollByMouseWheel! / _currentZoom;
      final dy = -event.scrollDelta.dy * widget.params.scrollByMouseWheel! / _currentZoom;
      final m = _txController.value.clone();
      if (widget.params.scrollHorizontallyByMouseWheel) {
        m.translateByDouble(dy, dx, 0, 1);
      } else {
        m.translateByDouble(dx, dy, 0, 1);
      }
      _txController.value = _makeMatrixInSafeRange(m, forceClamp: true);
    } finally {
      _stopInteraction();
    }
  }

  /// Restrict matrix to the safe range.
  Matrix4 _makeMatrixInSafeRange(Matrix4 newValue, {bool forceClamp = false}) {
    if (!forceClamp && (_layout == null || _viewSize == null || widget.params.scrollPhysics != null)) return newValue;
    if (widget.params.normalizeMatrix != null) {
      return widget.params.normalizeMatrix!(newValue, _viewSize!, _layout!, _controller);
    }
    return _calcMatrixForClampedToNearestBoundary(newValue, viewSize: _viewSize!);
  }

  /// Calculate matrix to center the specified position.
  Matrix4 _calcMatrixFor(Offset position, {required double zoom, required Size viewSize}) {
    final hw = viewSize.width / 2;
    final hh = viewSize.height / 2;
    return Matrix4.compose(
      vec.Vector3(-position.dx * zoom + hw, -position.dy * zoom + hh, 0),
      vec.Quaternion.identity(),
      vec.Vector3(
        zoom,
        zoom,
        zoom, // setting zoom of 1 on z caused a call to Matrix4.getMaxScaleOnAxis() to return 1 even when x and y are < 1
      ),
    );
  }

  /// The minimum zoom ratio allowed.
  double get minScale => _minScale;

  Matrix4 _calcMatrixForRect(Rect rect, {double? zoomMax, double? margin}) {
    margin ??= 0;
    var zoom = min((_viewSize!.width - margin * 2) / rect.width, (_viewSize!.height - margin * 2) / rect.height);
    if (zoomMax != null && zoom > zoomMax) zoom = zoomMax;
    return _calcMatrixFor(rect.center, zoom: zoom, viewSize: _viewSize!);
  }

  Matrix4 _calcMatrixForArea({required Rect rect, double? zoomMax, double? margin, PdfPageAnchor? anchor}) =>
      _calcMatrixForRect(
        _calcRectForArea(rect: rect, anchor: anchor ?? widget.params.pageAnchor),
        zoomMax: zoomMax,
        margin: margin,
      );

  /// The function calculate the rectangle which should be shown in the view.
  Rect _calcRectForArea({required Rect rect, required PdfPageAnchor anchor}) {
    final viewSize = _visibleRect.size;
    final w = min(rect.width, viewSize.width);
    final h = min(rect.height, viewSize.height);
    switch (anchor) {
      case PdfPageAnchor.top:
        return Rect.fromLTWH(rect.left, rect.top, rect.width, h);
      case PdfPageAnchor.left:
        return Rect.fromLTWH(rect.left, rect.top, w, rect.height);
      case PdfPageAnchor.right:
        return Rect.fromLTWH(rect.right - w, rect.top, w, rect.height);
      case PdfPageAnchor.bottom:
        return Rect.fromLTWH(rect.left, rect.bottom - h, rect.width, h);
      case PdfPageAnchor.topLeft:
        return Rect.fromLTWH(rect.left, rect.top, viewSize.width, viewSize.height);
      case PdfPageAnchor.topCenter:
        return Rect.fromLTWH(rect.topCenter.dx - w / 2, rect.top, viewSize.width, viewSize.height);
      case PdfPageAnchor.topRight:
        return Rect.fromLTWH(rect.topRight.dx - w, rect.top, viewSize.width, viewSize.height);
      case PdfPageAnchor.centerLeft:
        return Rect.fromLTWH(rect.left, rect.center.dy - h / 2, viewSize.width, viewSize.height);
      case PdfPageAnchor.center:
        return Rect.fromLTWH(rect.center.dx - w / 2, rect.center.dy - h / 2, viewSize.width, viewSize.height);
      case PdfPageAnchor.centerRight:
        return Rect.fromLTWH(rect.right - w, rect.center.dy - h / 2, viewSize.width, viewSize.height);
      case PdfPageAnchor.bottomLeft:
        return Rect.fromLTWH(rect.left, rect.bottom - h, viewSize.width, viewSize.height);
      case PdfPageAnchor.bottomCenter:
        return Rect.fromLTWH(rect.center.dx - w / 2, rect.bottom - h, viewSize.width, viewSize.height);
      case PdfPageAnchor.bottomRight:
        return Rect.fromLTWH(rect.right - w, rect.bottom - h, viewSize.width, viewSize.height);
      case PdfPageAnchor.all:
        return rect;
    }
  }

  Matrix4 _calcMatrixForPage({required int pageNumber, PdfPageAnchor? anchor}) {
    final boundaryMargin = _adjustedBoundaryMargins;
    final Rect pageRect;
    if (widget.params.singlePageMode) {
      // ARGUS fork — Phase H5 (2026-05-14). In single-page mode the
      // layout only ever non-zeros ONE page rect, so
      // `_layout!.pageLayouts[pageNumber - 1]` may be `Rect.zero` if
      // `pageNumber` differs from what's currently laid out (e.g.
      // during a goToPage call that updates `_gotoTargetPageNumber`
      // before relayout). Compute the target page's rect at the
      // canonical single-page origin `(margin, margin)` directly from
      // its dimensions.
      final page = _document!.pages[pageNumber - 1];
      final double m = widget.params.margin;
      pageRect = Rect.fromLTWH(m, m, page.width, page.height).inflate(m);
    } else {
      pageRect = _layout!.pageLayouts[pageNumber - 1].inflate(widget.params.margin);
    }

    // If boundaryMargin is infinite, don't inflate the rect
    final targetRect = boundaryMargin.inflateRectIfFinite(pageRect);

    return _calcMatrixForArea(rect: targetRect, anchor: anchor, zoomMax: _currentZoom);
  }

  Rect _calcRectForRectInsidePage({required int pageNumber, required PdfRect rect}) {
    final page = _document!.pages[pageNumber - 1];
    final pageRect = _layout!.pageLayouts[pageNumber - 1];
    final area = rect.toRect(page: page, scaledPageSize: pageRect.size);
    return area.translate(pageRect.left, pageRect.top);
  }

  Matrix4 _calcMatrixForRectInsidePage({required int pageNumber, required PdfRect rect, PdfPageAnchor? anchor}) {
    return _calcMatrixForArea(
      rect: _calcRectForRectInsidePage(pageNumber: pageNumber, rect: rect),
      anchor: anchor,
    );
  }

  Matrix4? _calcMatrixForDest(PdfDest? dest) {
    if (dest == null) return null;
    final page = _document!.pages[dest.pageNumber - 1];
    final pageRect = _layout!.pageLayouts[dest.pageNumber - 1];
    double calcX(double? x) => (x ?? 0) / page.width * pageRect.width;
    double calcY(double? y) => (page.height - (y ?? 0)) / page.height * pageRect.height;
    final params = dest.params;
    switch (dest.command) {
      case PdfDestCommand.xyz:
        if (params != null && params.length >= 2) {
          final zoom = params.length >= 3
              ? params[2] != null && params[2] != 0.0
                    ? params[2]!
                    : _currentZoom
              : 1.0;
          final hw = _viewSize!.width / 2 / zoom;
          final hh = _viewSize!.height / 2 / zoom;
          return _calcMatrixFor(
            pageRect.topLeft.translate(calcX(params[0]) + hw, calcY(params[1]) + hh),
            zoom: zoom,
            viewSize: _viewSize!,
          );
        }
        break;
      case PdfDestCommand.fit:
      case PdfDestCommand.fitB:
        return _calcMatrixForPage(pageNumber: dest.pageNumber, anchor: PdfPageAnchor.all);

      case PdfDestCommand.fitH:
      case PdfDestCommand.fitBH:
        if (params != null && params.length == 1) {
          final hh = _viewSize!.height / 2 / _currentZoom;
          return _calcMatrixFor(
            pageRect.topLeft.translate(0, calcY(params[0]) + hh),
            zoom: _currentZoom,
            viewSize: _viewSize!,
          );
        }
        break;
      case PdfDestCommand.fitV:
      case PdfDestCommand.fitBV:
        if (params != null && params.length == 1) {
          final hw = _viewSize!.width / 2 / _currentZoom;
          return _calcMatrixFor(
            pageRect.topLeft.translate(calcX(params[0]) + hw, 0),
            zoom: _currentZoom,
            viewSize: _viewSize!,
          );
        }
        break;
      case PdfDestCommand.fitR:
        if (params != null && params.length == 4) {
          // page /FitR left bottom right top
          return _calcMatrixForArea(
            rect: Rect.fromLTRB(
              calcX(params[0]),
              calcY(params[3]),
              calcX(params[2]),
              calcY(params[1]),
            ).translate(pageRect.left, pageRect.top),
            anchor: PdfPageAnchor.all,
          );
        }
        break;
      default:
        return null;
    }
    return null;
  }

  Future<void> _goTo(Matrix4? destination, {Duration duration = const Duration(milliseconds: 200)}) async {
    void update() {
      if (_animationResettingGuard != 0) return;
      _txController.value = _animGoTo!.value;
    }

    try {
      if (destination == null) return; // do nothing
      _stopInteractiveViewerAnimation();
      _animationResettingGuard++;
      _animController.reset();
      _animationResettingGuard--;
      _animGoTo = Matrix4Tween(
        begin: _txController.value,
        end: _makeMatrixInSafeRange(destination, forceClamp: true),
      ).animate(_animController);
      _animGoTo!.addListener(update);
      await _animController.animateTo(1.0, duration: duration, curve: Curves.easeInOut);
    } finally {
      _animGoTo?.removeListener(update);
    }
  }

  Matrix4 _calcMatrixToEnsureRectVisible(Rect rect, {double margin = 0}) {
    final restrictedRect = _txController.value.calcVisibleRect(_viewSize!, margin: margin);
    if (restrictedRect.containsRect(rect)) {
      return _txController.value; // keep the current position
    }
    if (rect.width <= restrictedRect.width && rect.height < restrictedRect.height) {
      final intRect = Rect.fromLTWH(
        rect.left < restrictedRect.left
            ? rect.left
            : rect.right < restrictedRect.right
            ? restrictedRect.left
            : restrictedRect.left + rect.right - restrictedRect.right,
        rect.top < restrictedRect.top
            ? rect.top
            : rect.bottom < restrictedRect.bottom
            ? restrictedRect.top
            : restrictedRect.top + rect.bottom - restrictedRect.bottom,
        restrictedRect.width,
        restrictedRect.height,
      );
      final newRect = intRect.inflate(margin / _currentZoom);
      return _calcMatrixForRect(newRect);
    }
    return _calcMatrixForRect(rect, margin: margin);
  }

  Future<void> _ensureVisible(Rect rect, {Duration duration = const Duration(milliseconds: 200), double margin = 0}) =>
      _goTo(_calcMatrixToEnsureRectVisible(rect, margin: margin), duration: duration);

  Future<void> _goToArea({
    required Rect rect,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) => _goTo(
    _calcMatrixForArea(rect: rect, anchor: anchor),
    duration: duration,
  );

  Future<void> _goToPage({
    required int pageNumber,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    final pageCount = _document!.pages.length;
    final int targetPageNumber;
    if (pageNumber < 1) {
      targetPageNumber = 1;
    } else if (pageNumber != 1 && pageNumber >= pageCount) {
      targetPageNumber = pageNumber = pageCount;
      anchor ??= widget.params.pageAnchorEnd;
    } else {
      targetPageNumber = pageNumber;
    }
    _gotoTargetPageNumber = pageNumber;

    if (widget.params.singlePageMode) {
      // ARGUS fork — Phase H6 (2026-05-14).
      debugPrint('[ARGUS-DBG] _goToPage SINGLE_PAGE: target=$targetPageNumber, prev=_pageNumber=$_pageNumber');
      _setCurrentPageNumber(targetPageNumber, doSetState: true);
      _relayoutPages();
      _calcCoverFitScale();
      final synthMatrix = _calcMatrixForPage(pageNumber: targetPageNumber, anchor: anchor);
      final clampedMatrix = _calcMatrixForClampedToNearestBoundary(synthMatrix, viewSize: _viewSize!);
      debugPrint('[ARGUS-DBG] _goToPage matrix synth=$synthMatrix clamp=$clampedMatrix viewSize=$_viewSize docSize=${_layout?.documentSize}');
      await _goTo(clampedMatrix, duration: Duration.zero);
      debugPrint('[ARGUS-DBG] _goToPage _goTo returned. _pageNumber=$_pageNumber matrix=${_txController.value}');
      return;
    }

    await _goTo(
      _calcMatrixForClampedToNearestBoundary(
        _calcMatrixForPage(pageNumber: targetPageNumber, anchor: anchor),
        viewSize: _viewSize!,
      ),
      duration: duration,
    );
    _setCurrentPageNumber(targetPageNumber);
  }

  /// Scrolls/zooms so that the specified PDF document coordinate appears at
  /// the top-left corner of the viewport.
  Future<void> _goToPosition({
    required Offset documentOffset,
    Duration duration = const Duration(milliseconds: 0),
    double? zoom,
  }) async {
    // Clear any cached partial images to avoid stale tiles after
    // going to the new matrix
    _imageCache.releasePartialImages();

    zoom = zoom ?? _currentZoom;
    final tx = -documentOffset.dx * zoom;
    final ty = -documentOffset.dy * zoom;

    final m = Matrix4.compose(vec.Vector3(tx, ty, 0), vec.Quaternion.identity(), vec.Vector3(zoom, zoom, zoom));

    _adjustBoundaryMargins(_viewSize!, zoom);
    final clamped = _calcMatrixForClampedToNearestBoundary(m, viewSize: _viewSize!);
    await _goTo(clamped, duration: duration);
  }

  Future<void> _goToRectInsidePage({
    required int pageNumber,
    required PdfRect rect,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    _gotoTargetPageNumber = pageNumber;
    await _goTo(
      _calcMatrixForRectInsidePage(pageNumber: pageNumber, rect: rect, anchor: anchor),
      duration: duration,
    );
    _setCurrentPageNumber(pageNumber);
  }

  Future<bool> _goToDest(PdfDest? dest, {Duration duration = const Duration(milliseconds: 200)}) async {
    final m = _calcMatrixForDest(dest);
    if (m == null) return false;
    if (dest != null) {
      _gotoTargetPageNumber = dest.pageNumber;
    }
    await _goTo(m, duration: duration);
    if (dest != null) {
      _setCurrentPageNumber(dest.pageNumber);
    }
    return true;
  }

  double get _currentZoom => _txController.value.zoom;

  PdfPageHitTestResult? _getPdfPageHitTestResult(Offset offset, {required bool useDocumentLayoutCoordinates}) {
    final pages = _document?.pages;
    final pageLayouts = _layout?.pageLayouts;
    if (pages == null || pageLayouts == null) return null;
    if (!useDocumentLayoutCoordinates) {
      final r = Matrix4.inverted(_txController.value);
      offset = r.transformOffset(offset);
    }

    // ARGUS fork — Phase Q1 (2026-05-13). In singlePageMode every
    // entry of `pageLayouts` shares the canonical `(margin, margin)`
    // origin (`_singlePageLayoutPages` deliberately stacks them so
    // host code that reads `pageLayouts[N-1]` for any N gets a
    // sensible per-page rect). The naïve "iterate, first match wins"
    // walk below would always return PAGE 1 — every page rect
    // contains the same in-page hit point, and the loop short-circuits
    // at i=0. That made `drawing_overlay._resolvePage` commit pen
    // strokes to page 1 no matter which page the user was on; the
    // painter then read `state.pages[currentPage]` (≠ 1) and found
    // nothing to draw, so the stroke seemed to "disappear on mouse
    // release". Same shape as the editor's Phase N4 bug, but in the
    // shared pdfrx hit-test API used by both viewer drawing and
    // editor interaction. Short-circuit: only the visible page can be
    // hit in single-page presentation, so consult that one and skip
    // the loop entirely.
    if (widget.params.singlePageMode) {
      final int? n = _pageNumber ?? _gotoTargetPageNumber ?? widget.initialPageNumber;
      if (n == null || n < 1 || n > pages.length) return null;
      final page = pages[n - 1];
      final pageRect = pageLayouts[n - 1];
      if (!pageRect.contains(offset)) return null;
      return PdfPageHitTestResult(
        page: page,
        offset: offset.translate(-pageRect.left, -pageRect.top).toPdfPoint(page: page, scaledPageSize: pageRect.size),
      );
    }

    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final pageRect = pageLayouts[i];
      if (pageRect.contains(offset)) {
        return PdfPageHitTestResult(
          page: page,
          offset: offset.translate(-pageRect.left, -pageRect.top).toPdfPoint(page: page, scaledPageSize: pageRect.size),
        );
      }
    }
    return null;
  }

  double _getNextZoom({bool loop = true}) => _findNextZoomStop(_currentZoom, zoomUp: true, loop: loop);
  double _getPreviousZoom({bool loop = true}) => _findNextZoomStop(_currentZoom, zoomUp: false, loop: loop);

  Future<void> _setZoom(Offset position, double zoom, {Duration duration = const Duration(milliseconds: 200)}) {
    _adjustBoundaryMargins(_viewSize!, zoom);
    return _goTo(
      _calcMatrixFor(position, zoom: zoom, viewSize: _viewSize!),
      duration: duration,
    );
  }

  Offset _localPositionToZoomCenter(Offset localPosition, double newZoom) {
    final toCenter = (_viewSize!.center(Offset.zero) - localPosition) / newZoom;
    final zoomPosition = _controller!.globalToDocument(_controller!.localToGlobal(localPosition)!)!;
    return zoomPosition.translate(toCenter.dx, toCenter.dy);
  }

  Offset get _centerPosition => _txController.value.calcPosition(_viewSize!);

  Future<void> _zoomUp({
    bool loop = false,
    Offset? zoomCenter,
    Duration duration = const Duration(milliseconds: 200),
  }) => _setZoom(zoomCenter ?? _centerPosition, _getNextZoom(loop: loop), duration: duration);

  Future<void> _zoomDown({
    bool loop = false,
    Offset? zoomCenter,
    Duration duration = const Duration(milliseconds: 200),
  }) => _setZoom(zoomCenter ?? _centerPosition, _getPreviousZoom(loop: loop), duration: duration);

  RenderBox? get _renderBox {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return null;
    return renderBox;
  }

  /// Converts the global position to the local position in the widget.
  Offset? _globalToLocal(Offset global) {
    try {
      final renderBox = _renderBox;
      if (renderBox == null) return null;
      return renderBox.globalToLocal(global);
    } catch (e) {
      return null;
    }
  }

  /// Converts the local position to the global position in the widget.
  Offset? _localToGlobal(Offset local) {
    try {
      final renderBox = _renderBox;
      if (renderBox == null) return null;
      return renderBox.localToGlobal(local);
    } catch (e) {
      return null;
    }
  }

  /// Converts the global position to the local position in the PDF document structure.
  Offset? _globalToDocument(Offset global) {
    final local = _globalToLocal(global);
    if (local == null) return null;
    return _localToDocument(local);
  }

  /// Converts the local position in the PDF document structure to the global position.
  Offset? _documentToGlobal(Offset document) => _localToGlobal((_documentToLocal(document)));

  /// Converts the local position in the widget to the local position in the PDF document structure.
  Offset _localToDocument(Offset local) {
    final ratio = 1 / _currentZoom;
    return local.translate(-_txController.value.xZoomed, -_txController.value.yZoomed).scale(ratio, ratio);
  }

  /// Converts the local position in the PDF document structure to the local position in the widget.
  Offset _documentToLocal(Offset document) {
    return document
        .scale(_currentZoom, _currentZoom)
        .translate(_txController.value.xZoomed, _txController.value.yZoomed);
  }

  FocusNode? _getFocusNode() {
    return _contextForFocusNode != null ? Focus.maybeOf(_contextForFocusNode!) : null;
  }

  void _requestFocus() {
    _getFocusNode()?.requestFocus();
  }

  void _handlePointerEvent(PointerEvent event, Offset localPosition, PointerDeviceKind? deviceKind) {
    _pointerOffset = localPosition;
    if (_pointerDeviceKind != deviceKind) {
      _pointerDeviceKind = deviceKind;
      _invalidate();
    }
  }

  PdfViewerPart _onWhat(Offset localPosition) {
    final p = _findTextAndIndexForPoint(localPosition);
    if (p != null) {
      if (_selA != null && _selB != null && _selA! <= p && p <= _selB!) {
        return PdfViewerPart.selectedText;
      }
      return PdfViewerPart.nonSelectedText;
    }
    return PdfViewerPart.background;
  }

  void _handleGeneralTap(Offset globalPosition, PdfViewerGeneralTapType type) {
    final docPosition = _globalToDocument(globalPosition);
    final what = _onWhat(docPosition!);
    _requestFocus();

    if (widget.params.onGeneralTap != null) {
      final localPosition = doc2local.offsetToLocal(context, docPosition)!;
      if (widget.params.onGeneralTap!(
        _contextForFocusNode!,
        _controller!,
        PdfViewerGeneralTapHandlerDetails(
          type: type,
          localPosition: localPosition,
          documentPosition: docPosition,
          tapOn: what,
        ),
      )) {
        return; // the tap was handled
      }
    }
    switch (type) {
      case PdfViewerGeneralTapType.tap:
        _clearTextSelections();
      case PdfViewerGeneralTapType.longPress:
        if (what == PdfViewerPart.nonSelectedText && isTextSelectionEnabled) {
          selectWord(docPosition, deviceKind: _pointerDeviceKind);
        } else {
          showContextMenu(docPosition, forPart: what);
        }
      case PdfViewerGeneralTapType.secondaryTap:
        showContextMenu(docPosition, forPart: what);
      default:
    }
  }

  void showContextMenu(Offset docPosition, {PdfViewerPart? forPart}) {
    _contextMenuDocumentPosition = docPosition;
    _contextMenuFor = forPart ?? _onWhat(docPosition);
    _invalidate();
  }

  void _onTextPanStart(DragStartDetails details) {
    if (_isInteractionGoingOn) return;
    _selPartMoving = _TextSelectionPart.free;
    _isSelectingAllText = false;
    _contextMenuDocumentPosition = null;
    _selA = _findTextAndIndexForPoint(details.localPosition);
    _textSelectAnchor = Offset(_txController.value.x, _txController.value.y);
    _selB = null;
    _updateTextSelection();
    _requestFocus();
  }

  void _onTextPanUpdate(DragUpdateDetails details) {
    _updateTextSelectRectTo(details.localPosition);
    _selectionPointerDeviceKind = _pointerDeviceKind;
  }

  void _onTextPanEnd(DragEndDetails details) {
    _updateTextSelectRectTo(details.localPosition);
    _selPartMoving = _TextSelectionPart.none;
    _isSelectingAllText = false;
    _invalidate();
  }

  void _updateTextSelectRectTo(Offset panTo) {
    if (_selPartMoving != _TextSelectionPart.free) return;
    final to = _findTextAndIndexForPoint(
      panTo + _textSelectAnchor! - Offset(_txController.value.x, _txController.value.y),
    );
    if (to != null) {
      _selB = to;
      _updateTextSelection();
    }
  }

  void _updateTextSelection({bool invalidate = true}) {
    if (isTextSelectionEnabled) {
      final a = _selA;
      final b = _selB;
      if (a == null || b == null) {
        _textSelA = _textSelB = null;
      } else if (a.text.pageNumber == b.text.pageNumber) {
        final page = _document!.pages[a.text.pageNumber - 1];
        final pageRect = _layout!.pageLayouts[a.text.pageNumber - 1];
        final range = a.text.getRangeFromAB(a.index, b.index);
        _textSelA = PdfTextSelectionAnchor(
          a.text.charRects[range.start].toRectInDocument(page: page, pageRect: pageRect),
          range.firstFragment?.direction ?? PdfTextDirection.ltr,
          PdfTextSelectionAnchorType.a,
          a.text,
          a.index,
        );
        _textSelB = PdfTextSelectionAnchor(
          a.text.charRects[range.end - 1].toRectInDocument(page: page, pageRect: pageRect),
          range.lastFragment?.direction ?? PdfTextDirection.ltr,
          PdfTextSelectionAnchorType.b,
          a.text,
          b.index,
        );
      } else {
        final first = a.text.pageNumber < b.text.pageNumber ? a : b;
        final second = a.text.pageNumber < b.text.pageNumber ? b : a;
        final rangeA = PdfPageTextRange(pageText: first.text, start: first.index, end: first.text.charRects.length);
        _textSelA = PdfTextSelectionAnchor(
          first.text.charRects[first.index].toRectInDocument(
            page: _document!.pages[first.text.pageNumber - 1],
            pageRect: _layout!.pageLayouts[first.text.pageNumber - 1],
          ),
          rangeA.firstFragment?.direction ?? PdfTextDirection.ltr,
          PdfTextSelectionAnchorType.a,
          first.text,
          first.index,
        );
        final rangeB = PdfPageTextRange(pageText: second.text, start: 0, end: second.index + 1);
        _textSelB = PdfTextSelectionAnchor(
          second.text.charRects[second.index].toRectInDocument(
            page: _document!.pages[second.text.pageNumber - 1],
            pageRect: _layout!.pageLayouts[second.text.pageNumber - 1],
          ),
          rangeB.lastFragment?.direction ?? PdfTextDirection.ltr,
          PdfTextSelectionAnchorType.b,
          second.text,
          second.index,
        );
      }
    } else {
      _selA = _selB = null;
      _textSelA = _textSelB = null;
      _contextMenuDocumentPosition = null;
      _isSelectingAllText = false;
    }

    if (invalidate) {
      _notifyTextSelectionChange();
    }
  }

  /// [point] is in the document coordinates.
  PdfTextSelectionPoint? _findTextAndIndexForPoint(Offset? point, {double hitTestMargin = 8}) {
    if (point == null) return null;
    for (var pageIndex = 0; pageIndex < _document!.pages.length; pageIndex++) {
      final pageRect = _layout!.pageLayouts[pageIndex];
      if (!pageRect.contains(point)) {
        continue;
      }
      final page = _document!.pages[pageIndex];
      final text = _getCachedTextOrDelayLoadText(pageIndex + 1, onTextLoaded: () => _updateTextSelection());
      if (text == null) continue;
      final pt = point.translate(-pageRect.left, -pageRect.top).toPdfPoint(page: page, scaledPageSize: pageRect.size);
      var d2Min = double.infinity;
      int? closestIndex;
      for (var i = 0; i < text.charRects.length; i++) {
        final charRect = text.charRects[i];
        if (charRect.containsPoint(pt)) {
          return PdfTextSelectionPoint(text, i);
        }
        final d2 = charRect.distanceSquaredTo(pt);
        if (d2 < d2Min) {
          d2Min = d2;
          closestIndex = i;
        }
      }
      if (closestIndex != null && d2Min <= hitTestMargin * hitTestMargin) {
        return PdfTextSelectionPoint(text, closestIndex);
      }
    }
    return null;
  }

  void _notifyTextSelectionChange() {
    _onSelectionChange();
    _invalidate();
  }

  Rect? _anchorARect;
  Rect? _anchorBRect;
  Rect? _magnifierRect;
  Rect? _previousMagnifierRect;
  Rect? _contextMenuRect;
  _TextSelectionPart _hoverOn = _TextSelectionPart.none;

  bool get enableSelectionHandles =>
      widget.params.textSelectionParams?.enableSelectionHandles ?? _pointerDeviceKind == PointerDeviceKind.touch;

  List<Widget> _placeTextSelectionWidgets(BuildContext context, Size viewSize, bool isCopyTextEnabled) {
    Widget? createContextMenu(Offset? a, Offset? b, PdfViewerPart contextMenuFor) {
      if (a == null) return null;
      final ctxMenuBuilder = widget.params.buildContextMenu ?? _buildContextMenu;
      return ctxMenuBuilder(
        context,
        PdfViewerContextMenuBuilderParams(
          isTextSelectionEnabled: isTextSelectionEnabled,
          anchorA: a,
          anchorB: b,
          a: _textSelA,
          b: _textSelB,
          contextMenuFor: contextMenuFor,
          textSelectionDelegate: this,
          dismissContextMenu: () {
            _contextMenuDocumentPosition = null;
            _invalidate();
          },
        ),
      );
    }

    List<Widget> contextMenuIfNeeded() {
      final contextMenu = createContextMenu(
        offsetToLocal(context, _contextMenuDocumentPosition),
        null,
        _contextMenuFor,
      );
      return [if (contextMenu != null) contextMenu];
    }

    final renderBox = _renderBox;
    if (!isTextSelectionEnabled || renderBox == null || _textSelA == null || _textSelB == null) {
      return contextMenuIfNeeded();
    }

    final rectA = _documentToRenderBox(_textSelA!.rect, renderBox);
    final rectB = _documentToRenderBox(_textSelB!.rect, renderBox);
    if (rectA == null || rectB == null) {
      return contextMenuIfNeeded();
    }

    double? aLeft, aRight, aBottom;
    double? bLeft, bTop, bRight;
    Widget? anchorA, anchorB;

    if ((enableSelectionHandles || _selectionPointerDeviceKind == PointerDeviceKind.touch) &&
        _selPartMoving != _TextSelectionPart.free) {
      final builder = widget.params.textSelectionParams?.buildSelectionHandle ?? _buildDefaultSelectionHandle;

      if (_textSelA != null) {
        final state = _selPartMoving == _TextSelectionPart.a
            ? PdfViewerTextSelectionAnchorHandleState.dragging
            : _hoverOn == _TextSelectionPart.a
            ? PdfViewerTextSelectionAnchorHandleState.hover
            : PdfViewerTextSelectionAnchorHandleState.normal;
        final offset =
            widget.params.textSelectionParams?.calcSelectionHandleOffset?.call(context, _textSelA!, state) ??
            Offset.zero;
        switch (_textSelA!.direction) {
          case PdfTextDirection.ltr:
          case PdfTextDirection.unknown:
            aRight = viewSize.width - rectA.left - offset.dx;
            aBottom = viewSize.height - rectA.top - offset.dy;
          case PdfTextDirection.rtl:
            aLeft = rectA.right + offset.dx;
            aBottom = viewSize.height - rectA.top - offset.dy;
          case PdfTextDirection.vrtl:
            aLeft = rectA.right + offset.dx;
            aBottom = viewSize.height - rectA.top - offset.dy;
        }
        anchorA = builder(context, _textSelA!, state);
      }
      if (_textSelB != null) {
        final state = _selPartMoving == _TextSelectionPart.b
            ? PdfViewerTextSelectionAnchorHandleState.dragging
            : _hoverOn == _TextSelectionPart.b
            ? PdfViewerTextSelectionAnchorHandleState.hover
            : PdfViewerTextSelectionAnchorHandleState.normal;
        final offset =
            widget.params.textSelectionParams?.calcSelectionHandleOffset?.call(context, _textSelB!, state) ??
            Offset.zero;
        switch (_textSelB!.direction) {
          case PdfTextDirection.ltr:
          case PdfTextDirection.unknown:
            bLeft = rectB.right + offset.dx;
            bTop = rectB.bottom + offset.dy;
          case PdfTextDirection.rtl:
            bRight = viewSize.width - rectB.left - offset.dx;
            bTop = rectB.bottom + offset.dy;
          case PdfTextDirection.vrtl:
            bRight = viewSize.width - rectB.left - offset.dx;
            bTop = rectB.bottom + offset.dy;
        }
        anchorB = builder(context, _textSelB!, state);
      }
    } else {
      _anchorARect = _anchorBRect = null;
    }

    final textAnchorMoving = switch (_selPartMoving) {
      _TextSelectionPart.a => _selA! < _selB! ? _TextSelectionPart.a : _TextSelectionPart.b,
      _TextSelectionPart.b => _selA! < _selB! ? _TextSelectionPart.b : _TextSelectionPart.a,
      _ => _selPartMoving,
    };

    // Determines whether the widget is [Positioned] or [Align] to avoid unnecessary wrapping.
    bool isPositionalWidget(Widget? widget) => widget != null && (widget is Positioned || widget is Align);

    const defMargin = 8.0;

    Offset normalizeWidgetPosition(Offset pos, Size? widgetSize, {double margin = defMargin}) {
      if (widgetSize == null) return pos;
      var left = pos.dx;
      var top = pos.dy;
      if (left + widgetSize.width + margin > viewSize.width) {
        left = viewSize.width - widgetSize.width - margin;
      }
      if (left < margin) {
        left = margin;
      }
      if (top + widgetSize.height + margin > viewSize.height) {
        top = viewSize.height - widgetSize.height - margin;
      }
      if (top < margin) {
        top = margin;
      }
      return Offset(left, top);
    }

    Offset? calcPosition(
      Size? widgetSize,
      Rect anchorLocalRect,
      Rect? handleLocalRect,
      PdfTextSelectionAnchor? textAnchor,
      Offset pointerPosition, {
      double margin = defMargin,
      double? marginOnTop,
      double? marginOnBottom,
    }) {
      if (widgetSize == null || textAnchor == null) {
        return null;
      }

      late double left, top;
      final rect0 = anchorLocalRect;
      final rect1 = handleLocalRect;
      final pt = rect0.center;
      final rectTop = rect1 == null ? rect0.top : min(rect0.top, rect1.top);
      final rectBottom = rect1 == null ? rect0.bottom : max(rect0.bottom, rect1.bottom);
      final rectLeft = rect1 == null ? rect0.left : min(rect0.left, rect1.left);
      final rectRight = rect1 == null ? rect0.right : max(rect0.right, rect1.right);
      switch (textAnchor.direction) {
        case PdfTextDirection.ltr:
        case PdfTextDirection.rtl:
        case PdfTextDirection.unknown:
          left = pt.dx - widgetSize.width / 2 + margin;
          if (left < margin) {
            left = margin;
          } else if (left + widgetSize.width + margin > viewSize.width) {
            // If the anchor is too close to the right, place the magnifier to the left of it.
            left = viewSize.width - widgetSize.width - margin;
          }
          top = rectTop - widgetSize.height - (marginOnTop ?? margin);
          if (top < margin) {
            // If the anchor is too close to the top, place the magnifier below it.
            top = rectBottom + (marginOnBottom ?? margin);
          }
          break;
        case PdfTextDirection.vrtl:
          if (textAnchor.type == PdfTextSelectionAnchorType.a) {
            left = rectRight + margin;
            if (left + widgetSize.width + margin > viewSize.width) {
              left = rectLeft - widgetSize.width - margin;
            }
          } else {
            left = rectLeft - widgetSize.width - margin;
            if (left < margin) {
              left = rectRight + margin;
            }
          }
          top = pt.dy - widgetSize.height / 2;
          if (top < margin) {
            top = margin;
          } else if (top + widgetSize.height + margin > viewSize.height) {
            // If the anchor is too close to the bottom, place the magnifier above it.
            top = viewSize.height - widgetSize.height - margin;
          }
      }
      return normalizeWidgetPosition(Offset(left, top), widgetSize, margin: margin);
    }

    Widget? magnifier;

    final shouldShowMagnifier = widget.params.textSelectionParams?.magnifier?.shouldShowMagnifier?.call();
    // Show magnifier if dragging
    if (((textAnchorMoving == _TextSelectionPart.a || textAnchorMoving == _TextSelectionPart.b) &&
            shouldShowMagnifier != false) ||
        shouldShowMagnifier == true) {
      final textAnchor = textAnchorMoving == _TextSelectionPart.a
          ? _textSelA!
          : textAnchorMoving == _TextSelectionPart.b
          ? _textSelB!
          : (_selPartLastMoved == _TextSelectionPart.a ? _textSelA! : _textSelB!);
      final magnifierParams = widget.params.textSelectionParams?.magnifier ?? const PdfViewerSelectionMagnifierParams();

      final magnifierEnabled =
          (magnifierParams.enabled ?? _selectionPointerDeviceKind == PointerDeviceKind.touch) &&
          (magnifierParams.shouldShowMagnifierForAnchor ?? _shouldShowMagnifierForAnchor)(
            textAnchor,
            _controller!,
            magnifierParams,
          );
      if (magnifierEnabled) {
        final anchorLocalRect = textAnchorMoving == _TextSelectionPart.a ? rectA : rectB;
        final handleLocalRect = textAnchorMoving == _TextSelectionPart.a ? _anchorARect! : _anchorBRect!;
        // Calculate final magnifier position before calling builder
        final magnifierPosition =
            (magnifierParams.calcPosition ?? calcPosition)(
              _magnifierRect?.size,
              anchorLocalRect,
              handleLocalRect,
              textAnchor,
              _pointerOffset,
              margin: 10,
              marginOnTop: 20,
              marginOnBottom: 80,
            ) ??
            Offset.zero;

        // Calculate clamped pointer position for magnifier content
        final clampedPointerPosition = _calcClampedPointerPosition(
          _pointerOffset,
          magnifierPosition,
          _magnifierRect?.size,
          textAnchor,
        );

        final magRect = (magnifierParams.getMagnifierRectForAnchor ?? _getMagnifierRect)(
          textAnchor,
          magnifierParams,
          clampedPointerPosition,
        );
        final magnifierMain = _buildMagnifier(context, magRect, magnifierParams);
        final builder = magnifierParams.builder ?? _buildMagnifierDecoration;
        magnifier = builder(
          context,
          textAnchor,
          magnifierParams,
          magnifierMain,
          magRect.size,
          _pointerOffset,
          magnifierPosition,
        );
        if (magnifier != null && !isPositionalWidget(magnifier)) {
          final offset = magnifierPosition;
          magnifier = AnimatedPositioned(
            duration: _previousMagnifierRect != null ? magnifierParams.animationDuration : Duration.zero,
            left: offset.dx,
            top: offset.dy,
            child: WidgetSizeSniffer(
              key: Key('magnifier'),
              child: magnifier,
              onSizeChanged: (rect) {
                _magnifierRect = rect.toLocal(context);
                _invalidate();
              },
            ),
          );
          _previousMagnifierRect = _magnifierRect;
        }
      } else {
        _magnifierRect = _previousMagnifierRect = null;
      }
    }

    final showContextMenuAutomatically =
        widget.params.textSelectionParams?.showContextMenuAutomatically ??
        _selectionPointerDeviceKind == PointerDeviceKind.touch;
    var showContextMenu = false;
    if (_contextMenuDocumentPosition != null) {
      showContextMenu = true;
    } else if (showContextMenuAutomatically &&
        _textSelA != null &&
        _textSelB != null &&
        _selPartMoving == _TextSelectionPart.none) {
      // Show context menu on mobile when selection is not moving.
      showContextMenu = true;
      _contextMenuFor = PdfViewerPart.selectedText;
    }

    Widget? contextMenu;
    if (showContextMenu &&
        _selPartMoving == _TextSelectionPart.none &&
        (_contextMenuDocumentPosition != null ||
            _selPartLastMoved == _TextSelectionPart.a ||
            _selPartLastMoved == _TextSelectionPart.b ||
            _isSelectingAllText) &&
        isCopyTextEnabled) {
      final localOffset = _contextMenuDocumentPosition != null
          ? offsetToLocal(context, _contextMenuDocumentPosition!)
          : null;

      Offset? a, b;
      if (isMobile) {
        a = localOffset;
        switch (_textSelA?.direction) {
          case PdfTextDirection.ltr:
            a ??= _anchorARect?.topLeft;
            b = localOffset == null ? _anchorBRect?.bottomLeft : null;
          case PdfTextDirection.rtl:
          case PdfTextDirection.vrtl:
            a ??= _anchorARect?.topRight;
            b = localOffset == null ? _anchorBRect?.bottomRight : null;
          default:
        }
      } else {
        // NOTE:
        // On Desktop, AdaptiveTextSelectionToolbar determines the context menu position by only the first anchor (a).
        // So, we need to be careful about where to place the anchor (a).
        if (!_isSelectingAWord && localOffset != null) {
          a = localOffset;
        } else {
          // NOTE: it's still a little strange behavior when selecting a word by long-pressing on it on Desktop
          if (_isSelectingAWord) {
            _isSelectingAWord = false;
            a = _anchorBRect?.bottomRight ?? _anchorARect?.center;
          }
          a ??= _pointerOffset;
          if (_anchorARect != null && _anchorBRect != null) {
            switch (_textSelA?.direction) {
              case PdfTextDirection.ltr:
                if (_anchorARect!.inflate(16).contains(a)) {
                  a = rectA.bottomLeft.translate(0, 8);
                }
                final selRect = rectA.expandToInclude(rectB);
                if (selRect.height < 60 && selRect.width < 250) {
                  a = _anchorBRect!.bottomRight;
                }
                if (_anchorBRect!.inflate(16).contains(a)) {
                  a = _anchorBRect!.bottomRight;
                }
              case PdfTextDirection.rtl:
              case PdfTextDirection.vrtl:
                final distA = (a - _anchorARect!.center).distanceSquared;
                final distB = (a - _anchorBRect!.center).distanceSquared;
                if (distA < distB) {
                  a = _anchorARect!.bottomLeft.translate(8, 8);
                } else {
                  a = _anchorBRect!.topRight.translate(8, 8);
                }
              default:
            }
            _contextMenuDocumentPosition = offsetToDocument(context, a);
          }
        }
      }

      contextMenu = createContextMenu(a, b, _contextMenuFor);
      if (contextMenu != null && !isPositionalWidget(contextMenu)) {
        final textAnchor = _selPartLastMoved == _TextSelectionPart.a
            ? _textSelA
            : _selPartLastMoved == _TextSelectionPart.b
            ? _textSelB
            : null;
        final anchorLocalRect = _selPartLastMoved == _TextSelectionPart.a ? rectA : rectB;
        final handleLocalRect = _selPartLastMoved == _TextSelectionPart.a ? _anchorARect : _anchorBRect;
        final offset = localOffset != null
            ? normalizeWidgetPosition(localOffset, _contextMenuRect?.size)
            : (calcPosition(_contextMenuRect?.size, anchorLocalRect, handleLocalRect, textAnchor, _pointerOffset) ??
                  Offset.zero);

        contextMenu = Positioned(
          left: offset.dx,
          top: offset.dy,
          child: WidgetSizeSniffer(
            key: Key('contextMenu'),
            child: contextMenu,
            onSizeChanged: (rect) {
              _contextMenuRect = rect.toLocal(context);
              _invalidate();
            },
          ),
        );
      } else {
        _contextMenuRect = null;
      }
    }

    if (textAnchorMoving == _TextSelectionPart.a || textAnchorMoving == _TextSelectionPart.b) {
      _selPartLastMoved = textAnchorMoving;
    }

    return [
      if (anchorA != null)
        Positioned(
          left: aLeft,
          right: aRight,
          bottom: aBottom,
          child: MouseRegion(
            cursor: _selPartMoving == _TextSelectionPart.a ? SystemMouseCursors.none : SystemMouseCursors.move,
            onEnter: (details) => _onSelectionHandleEnter(_TextSelectionPart.a, details),
            onExit: (details) => _onSelectionHandleExit(_TextSelectionPart.a, details),
            onHover: (details) => _onSelectionHandleHover(_TextSelectionPart.a, details),
            child: GestureDetector(
              onPanStart: (details) => _onSelectionHandlePanStart(_TextSelectionPart.a, details),
              onPanUpdate: (details) => _onSelectionHandlePanUpdate(_TextSelectionPart.a, details),
              onPanEnd: (details) => _onSelectionHandlePanEnd(_TextSelectionPart.a, details),
              child: WidgetSizeSniffer(
                key: Key('anchorA'),
                child: anchorA,
                onSizeChanged: (rect) {
                  _anchorARect = rect.toLocal(context);
                  _invalidate();
                },
              ),
            ),
          ),
        ),
      if (anchorB != null)
        Positioned(
          left: bLeft,
          top: bTop,
          right: bRight,
          child: MouseRegion(
            cursor: _selPartMoving == _TextSelectionPart.b ? SystemMouseCursors.none : SystemMouseCursors.move,
            onEnter: (details) => _onSelectionHandleEnter(_TextSelectionPart.b, details),
            onExit: (details) => _onSelectionHandleExit(_TextSelectionPart.b, details),
            onHover: (details) => _onSelectionHandleHover(_TextSelectionPart.b, details),

            child: GestureDetector(
              onPanStart: (details) => _onSelectionHandlePanStart(_TextSelectionPart.b, details),
              onPanUpdate: (details) => _onSelectionHandlePanUpdate(_TextSelectionPart.b, details),
              onPanEnd: (details) => _onSelectionHandlePanEnd(_TextSelectionPart.b, details),
              child: WidgetSizeSniffer(
                key: Key('anchorB'),
                child: anchorB,
                onSizeChanged: (rect) {
                  _anchorBRect = rect.toLocal(context);
                  _invalidate();
                },
              ),
            ),
          ),
        ),
      if (magnifier != null) magnifier,
      if (contextMenu != null) contextMenu,
    ];
  }

  /// Calculate the clamped pointer position for the magnifier content.
  ///
  /// When the magnifier widget is clamped to stay within viewport bounds (e.g., near screen edges),
  /// we adjust the pointer position by the same amount. This enables [PdfViewerGetMagnifierRectForAnchor]
  /// and [PdfViewerMagnifierBuilder] to use the clamped pointer position to effectively "freeze" the
  /// magnifier content, preventing it from sliding inside the magnifier.
  ///
  /// Returns the clamped pointer position in viewport coordinates.
  Offset _calcClampedPointerPosition(
    Offset pointerOffset,
    Offset magnifierPosition,
    Size? magnifierSize,
    PdfTextSelectionAnchor textAnchor,
  ) {
    var clampedPointerOffset = pointerOffset;

    if (magnifierSize != null) {
      // What the magnifier X position would be without clamping (centered on pointer)
      final unclampedLeft = pointerOffset.dx - magnifierSize.width / 2;
      // How much it was actually clamped by calcPosition
      final clampAmount = magnifierPosition.dx - unclampedLeft;
      // Adjust pointer position by the same clamp amount to freeze content
      clampedPointerOffset = Offset(pointerOffset.dx + clampAmount, pointerOffset.dy);
    }
    return clampedPointerOffset;
  }

  bool _shouldShowMagnifierForAnchor(
    PdfTextSelectionAnchor textAnchor,
    PdfViewerController controller,
    PdfViewerSelectionMagnifierParams params,
  ) {
    final h = textAnchor.direction == PdfTextDirection.vrtl ? textAnchor.rect.size.width : textAnchor.rect.size.height;
    return h * _currentZoom < params.magnifierSizeThreshold;
  }

  Widget _buildHandle(BuildContext context, Path path, PdfViewerTextSelectionAnchorHandleState state) {
    final baseColor =
        Theme.of(context).textSelectionTheme.selectionColor ?? DefaultSelectionStyle.of(context).selectionColor!;
    final (selectionColor, shadow) = switch (state) {
      PdfViewerTextSelectionAnchorHandleState.normal => (baseColor.withValues(alpha: .7), true),
      PdfViewerTextSelectionAnchorHandleState.dragging => (baseColor.withValues(alpha: 1), false),
      PdfViewerTextSelectionAnchorHandleState.hover => (baseColor.withValues(alpha: 1), true),
    };
    return CustomPaint(
      painter: _CustomPainter.fromFunctions((canvas, size) {
        if (shadow) {
          canvas.drawShadow(path, Colors.black, 4, true);
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = selectionColor
            ..style = PaintingStyle.fill,
        );
      }, hitTestFunction: (position) => position.dx >= 0 && position.dx <= 30 && position.dy >= 0 && position.dy <= 30),
      size: Size(30, 30),
    );
  }

  Widget? _buildDefaultSelectionHandle(
    BuildContext context,
    PdfTextSelectionAnchor anchor,
    PdfViewerTextSelectionAnchorHandleState state,
  ) {
    switch (anchor.direction) {
      case PdfTextDirection.ltr:
        if (anchor.type == PdfTextSelectionAnchorType.a) {
          return _buildHandle(
            context,
            Path()
              ..moveTo(30, 0)
              ..lineTo(30, 30)
              ..lineTo(0, 30)
              ..close(),
            state,
          );
        } else {
          return _buildHandle(
            context,
            Path()
              ..moveTo(0, 0)
              ..lineTo(30, 0)
              ..lineTo(0, 30)
              ..close(),
            state,
          );
        }
      case PdfTextDirection.rtl:
      case PdfTextDirection.vrtl:
        if (anchor.type == PdfTextSelectionAnchorType.a) {
          return _buildHandle(
            context,
            Path()
              ..moveTo(0, 30)
              ..lineTo(30, 30)
              ..lineTo(0, 0)
              ..close(),
            state,
          );
        } else {
          return _buildHandle(
            context,
            Path()
              ..moveTo(0, 0)
              ..lineTo(30, 0)
              ..lineTo(30, 30)
              ..close(),
            state,
          );
        }

      case PdfTextDirection.unknown:
        return _buildHandle(
          context,
          Path()
            ..moveTo(0, 0)
            ..lineTo(30, 0)
            ..lineTo(30, 30)
            ..lineTo(0, 30)
            ..close(),
          state,
        );
    }
  }

  Rect _getMagnifierRect(
    PdfTextSelectionAnchor textAnchor,
    PdfViewerSelectionMagnifierParams params,
    Offset clampedPointerPosition,
  ) {
    final c = textAnchor.page.charRects[textAnchor.index];

    final (width, height) = switch (_document!.pages[textAnchor.page.pageNumber - 1].rotation.index & 1) {
      0 => (c.width, c.height),
      _ => (c.height, c.width),
    };

    final (baseUnit, v, h) = switch (textAnchor.direction) {
      PdfTextDirection.ltr || PdfTextDirection.rtl || PdfTextDirection.unknown => (height, 2.0, 0.2),
      PdfTextDirection.vrtl => (width, 0.2, 2.0),
    };
    return Rect.fromLTRB(
      textAnchor.rect.left - baseUnit * v,
      textAnchor.rect.top - baseUnit * h,
      textAnchor.rect.right + baseUnit * v,
      textAnchor.rect.bottom + baseUnit * h,
    );
  }

  Widget _buildMagnifier(BuildContext context, Rect rectToDraw, PdfViewerSelectionMagnifierParams magnifierParams) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          clipBehavior: Clip.antiAlias,
          child: CustomPaint(
            painter: _CustomPainter.fromFunctions((canvas, size) {
              final magScale = max(size.width / rectToDraw.width, size.height / rectToDraw.height);
              canvas.save();
              canvas.scale(magScale);
              canvas.translate(-rectToDraw.left, -rectToDraw.top);
              _paintPagesCustom(
                canvas,
                cache: _magnifierImageCache,
                maxImageCacheBytes:
                    widget.params.textSelectionParams?.magnifier?.maxImageBytesCachedOnMemory ??
                    PdfViewerSelectionMagnifierParams.defaultMaxImageBytesCachedOnMemory,
                targetRect: rectToDraw,
                scale: magScale * MediaQuery.of(context).devicePixelRatio,
                enableLowResolutionPagePreview: true,
                filterQuality: FilterQuality.low,
              );
              canvas.restore();
            }),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        );
      },
    );
  }

  Widget _buildMagnifierDecoration(
    BuildContext context,
    PdfTextSelectionAnchor textAnchor,
    PdfViewerSelectionMagnifierParams params,
    Widget child,
    Size childSize,
    Offset pointerPosition,
    Offset magnifierPosition,
  ) {
    final scale = 80 / min(childSize.width, childSize.height);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 2)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: SizedBox(width: childSize.width * scale, height: childSize.height * scale, child: child),
      ),
    );
  }

  Widget? _buildContextMenu(BuildContext context, PdfViewerContextMenuBuilderParams params) {
    final items = [
      if (params.isTextSelectionEnabled &&
          params.textSelectionDelegate.isCopyAllowed &&
          params.textSelectionDelegate.hasSelectedText)
        ContextMenuButtonItem(
          onPressed: () => params.textSelectionDelegate.copyTextSelection(),
          type: ContextMenuButtonType.copy,
        ),
      if (params.isTextSelectionEnabled && !params.textSelectionDelegate.isSelectingAllText)
        ContextMenuButtonItem(
          onPressed: () => params.textSelectionDelegate.selectAllText(),
          type: ContextMenuButtonType.selectAll,
        ),
    ];

    widget.params.customizeContextMenuItems?.call(params, items);

    if (items.isEmpty) {
      return null;
    }

    return Align(
      alignment: Alignment.topLeft,
      child: AdaptiveTextSelectionToolbar.buttonItems(
        anchors: TextSelectionToolbarAnchors(primaryAnchor: params.anchorA, secondaryAnchor: params.anchorB),
        buttonItems: items,
      ),
    );
  }

  void _onSelectionHandlePanStart(_TextSelectionPart handle, DragStartDetails details) {
    if (_isInteractionGoingOn) return;
    _selPartMoving = handle;
    _isSelectingAllText = false;
    final position = _globalToDocument(details.globalPosition);
    final anchor = Offset(_txController.value.x, _txController.value.y);
    if (_selPartMoving == _TextSelectionPart.a) {
      _textSelectAnchor = anchor + _textSelA!.rect.topLeft - position!;
      final a = _findTextAndIndexForPoint(_textSelA!.rect.center);
      if (a == null) return;
      _selA = a;
      // Notify drag start callback
      widget.params.textSelectionParams?.onSelectionHandlePanStart?.call(_textSelA!);
    } else if (_selPartMoving == _TextSelectionPart.b) {
      _textSelectAnchor = anchor + _textSelB!.rect.bottomRight - position!;
      final b = _findTextAndIndexForPoint(_textSelB!.rect.center);
      if (b == null) return;
      _selB = b;
      // Notify drag start callback
      widget.params.textSelectionParams?.onSelectionHandlePanStart?.call(_textSelB!);
    } else {
      return;
    }
    _updateTextSelection();
    _requestFocus();
  }

  bool _updateSelectionHandlesPan(Offset? panTo) {
    if (panTo == null) {
      return false;
    }
    if (_selPartMoving == _TextSelectionPart.a) {
      final a = _findTextAndIndexForPoint(
        panTo + _textSelectAnchor! - Offset(_txController.value.x, _txController.value.y),
      );
      if (a == null) {
        return false;
      }
      _selA = a;
    } else if (_selPartMoving == _TextSelectionPart.b) {
      final b = _findTextAndIndexForPoint(
        panTo + _textSelectAnchor! - Offset(_txController.value.x, _txController.value.y),
      );
      if (b == null) {
        return false;
      }
      _selB = b;
    } else {
      return false;
    }
    _updateTextSelection();
    return true;
  }

  void _onSelectionHandlePanUpdate(_TextSelectionPart handle, DragUpdateDetails details) {
    if (_isInteractionGoingOn) return;
    _contextMenuDocumentPosition = null;
    _updateSelectionHandlesPan(_globalToDocument(details.globalPosition));
    // Notify drag update callback
    final anchor = handle == _TextSelectionPart.a ? _textSelA : _textSelB;
    if (anchor != null) {
      widget.params.textSelectionParams?.onSelectionHandlePanUpdate?.call(anchor, details.delta);
    }
  }

  void _onSelectionHandlePanEnd(_TextSelectionPart handle, DragEndDetails details) {
    if (_isInteractionGoingOn) return;
    final result = _updateSelectionHandlesPan(_globalToDocument(details.globalPosition));
    // Notify drag end callback before clearing state
    final anchor = handle == _TextSelectionPart.a ? _textSelA : _textSelB;
    if (anchor != null) {
      widget.params.textSelectionParams?.onSelectionHandlePanEnd?.call(anchor);
    }

    _selPartMoving = _TextSelectionPart.none;
    _isSelectingAllText = false;
    if (!result) {
      _updateTextSelection();
    }
  }

  void _onSelectionHandleEnter(_TextSelectionPart handle, PointerEnterEvent details) {
    _hoverOn = handle;
    _invalidate();
  }

  void _onSelectionHandleExit(_TextSelectionPart handle, PointerExitEvent details) {
    _hoverOn = _TextSelectionPart.none;
    _invalidate();
  }

  void _onSelectionHandleHover(_TextSelectionPart handle, PointerHoverEvent details) {
    _hoverOn = handle;
    _invalidate();
  }

  void _clearTextSelections({bool invalidate = true}) {
    _selA = _selB = null;
    _textSelA = _textSelB = null;
    _contextMenuDocumentPosition = null;
    _isSelectingAllText = false;
    _updateTextSelection(invalidate: invalidate);
  }

  @override
  Future<void> clearTextSelection() async => _clearTextSelections();

  @override
  PdfTextSelectionRange? get textSelectionPointRange {
    final a = _selA;
    final b = _selB;
    if (a == null || b == null) {
      return null;
    }
    return PdfTextSelectionRange.fromPoints(a, b);
  }

  @override
  Future<void> setTextSelectionPointRange(PdfTextSelectionRange range) async {
    if (_selA == range.start && _selB == range.end) {
      return;
    }
    _selA = range.start;
    _selB = range.end;
    if (_selA! > _selB!) {
      final temp = _selA;
      _selA = _selB;
      _selB = temp;
    }
    _textSelA = _textSelB = null;
    _contextMenuDocumentPosition = null;
    _isSelectingAllText = false;
    _updateTextSelection();
  }

  PdfPageTextRange? _loadTextSelectionForPageNumber(int pageNumber) {
    final a = _selA;
    final b = _selB;
    if (a == null || b == null) {
      return null;
    }
    final first = a.text.pageNumber < b.text.pageNumber ? a : b;
    final second = a.text.pageNumber < b.text.pageNumber ? b : a;
    if (first.text.pageNumber == second.text.pageNumber && first.text.pageNumber == pageNumber) {
      return a.text.getRangeFromAB(a.index, b.index);
    }
    if (first.text.pageNumber == pageNumber) {
      return PdfPageTextRange(pageText: first.text, start: a.index, end: first.text.charRects.length);
    }
    if (second.text.pageNumber == pageNumber) {
      return PdfPageTextRange(pageText: second.text, start: 0, end: b.index + 1);
    }
    if (first.text.pageNumber < pageNumber && pageNumber < second.text.pageNumber) {
      final text = _getCachedTextOrDelayLoadText(pageNumber, onTextLoaded: () => _invalidate());
      if (text == null) return null;
      return PdfPageTextRange(pageText: text, start: 0, end: text.fullText.length);
    }
    return null;
  }

  @override
  bool get hasSelectedText => _selA != null && _selB != null;

  @override
  Future<List<PdfPageTextRange>> getSelectedTextRanges() async {
    final a = _selA;
    final b = _selB;
    if (a == null || b == null) {
      return [];
    }
    final first = a.text.pageNumber < b.text.pageNumber ? a : b;
    final second = a.text.pageNumber < b.text.pageNumber ? b : a;
    if (first.text.pageNumber == second.text.pageNumber) {
      return [a.text.getRangeFromAB(a.index, b.index)];
    }
    final selections = <PdfPageTextRange>[a.text.getRangeFromAB(a.index, a.text.charRects.length - 1)];

    for (var i = first.text.pageNumber + 1; i < second.text.pageNumber; i++) {
      final text = await _loadTextAsync(i);
      if (text == null || text.fullText.isEmpty) continue;
      selections.add(text.getRangeFromAB(0, text.charRects.length - 1));
    }

    selections.add(second.text.getRangeFromAB(0, b.index));
    return selections;
  }

  @override
  Future<String> getSelectedText() async {
    final selections = await getSelectedTextRanges();
    if (selections.isEmpty) return '';
    return selections.map((e) => e.text).join();
  }

  @override
  bool get isTextSelectionEnabled => widget.params.textSelectionParams?.enabled ?? true;

  @override
  bool get isCopyAllowed => _document!.permissions?.allowsCopying != false;

  @override
  bool get isSelectingAllText => _isSelectingAllText;

  @override
  Future<void> selectAllText() async {
    if (_document!.pages.isEmpty && _layout != null) return;
    PdfPageText? first;
    for (var i = 1; i <= _document!.pages.length; i++) {
      final text = await _loadTextAsync(i);
      if (text == null || text.fullText.isEmpty) continue;
      first = text;
      break;
    }
    PdfPageText? last;
    for (var i = _document!.pages.length; i >= 1; i--) {
      final text = await _loadTextAsync(i);
      if (text == null || text.fullText.isEmpty) continue;
      last = text;
      break;
    }

    if (first != null && last != null) {
      _selA = _findTextAndIndexForPoint(
        first.charRects.first.center.toOffsetInDocument(
          page: _document!.pages[first.pageNumber - 1],
          pageRect: _layout!.pageLayouts[first.pageNumber - 1],
        ),
      );
      _selB = _findTextAndIndexForPoint(
        last.charRects.last.center.toOffsetInDocument(
          page: _document!.pages[last.pageNumber - 1],
          pageRect: _layout!.pageLayouts[last.pageNumber - 1],
        ),
      );
    } else {
      _selA = _selB = null;
    }
    _textSelA = _textSelB = null;
    _contextMenuDocumentPosition = null;
    _selPartLastMoved = _TextSelectionPart.none;
    _isSelectingAllText = true;
    _updateTextSelection();
  }

  @override
  Future<void> selectWord(Offset offset, {PointerDeviceKind? deviceKind}) async {
    // ARGUS fork — Phase F1 (2026-05-14). Was a linear scan over
    // every page; now a single binary search via
    // [PdfPageLayout.pageIndexContaining]. The post-body cleanup (the
    // `_selPartMoving` reset etc.) runs unconditionally as before.
    final i = _layout!.pageIndexContaining(offset);
    findWord:
    {
      if (i < 0) break findWord;
      final pageRect = _layout!.pageLayouts[i];
      final text = await _loadTextAsync(i + 1);
      if (text == null || text.fullText.isEmpty) break findWord;
      final page = _document!.pages[i];
      final point = offset
          .translate(-pageRect.left, -pageRect.top)
          .toPdfPoint(page: page, scaledPageSize: pageRect.size);
      final f = text.fragments.firstWhereOrNull((f) => f.bounds.containsPoint(point));
      if (f == null) break findWord;
      final range = PdfPageTextRange(pageText: text, start: f.index, end: f.end);
      final selectionRect = f.bounds.toRectInDocument(page: page, pageRect: pageRect);
      _selA = PdfTextSelectionPoint(text, f.index);
      _selB = PdfTextSelectionPoint(text, f.end - 1);
      _textSelA = PdfTextSelectionAnchor(
        selectionRect,
        range.pageText.getFragmentForTextIndex(range.start)?.direction ?? PdfTextDirection.ltr,
        PdfTextSelectionAnchorType.a,
        text,
        _selA!.index,
      );
      _textSelB = _textSelA!.copyWith(type: PdfTextSelectionAnchorType.b, index: _selB!.index);
      _textSelectAnchor = Offset(_txController.value.x, _txController.value.y);
    }

    _selPartMoving = _TextSelectionPart.none;
    _selPartLastMoved = _TextSelectionPart.b;
    _isSelectingAllText = false;
    _selectionPointerDeviceKind = deviceKind;
    _contextMenuDocumentPosition = null;
    _isSelectingAWord = true;
    _notifyTextSelectionChange();
  }

  Future<bool> _copyTextSelection() async {
    if (_document!.permissions?.allowsCopying == false) return false;
    setClipboardData(await getSelectedText());
    return true;
  }

  @override
  Future<bool> copyTextSelection() async {
    final result = await _copyTextSelection();
    _clearTextSelections();
    return result;
  }

  @override
  Offset? offsetToLocal(BuildContext context, Offset? position) {
    if (position == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final global = _documentToGlobal(position);
    if (global == null) return null;
    return renderBox.globalToLocal(global);
  }

  @override
  Rect? rectToLocal(BuildContext context, Rect? rect) {
    if (rect == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final globalTopLeft = _documentToGlobal(rect.topLeft);
    final globalBottomRight = _documentToGlobal(rect.bottomRight);
    if (globalTopLeft == null || globalBottomRight == null) return null;
    return Rect.fromPoints(renderBox.globalToLocal(globalTopLeft), renderBox.globalToLocal(globalBottomRight));
  }

  @override
  Offset? offsetToDocument(BuildContext context, Offset? position) {
    if (position == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final global = renderBox.localToGlobal(position);
    return _globalToDocument(global);
  }

  @override
  Rect? rectToDocument(BuildContext context, Rect? rect) {
    if (rect == null) return null;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final globalTopLeft = renderBox.localToGlobal(rect.topLeft);
    final globalBottomRight = renderBox.localToGlobal(rect.bottomRight);
    final docTopLeft = _globalToDocument(globalTopLeft);
    final docBottomRight = _globalToDocument(globalBottomRight);
    if (docTopLeft == null || docBottomRight == null) return null;
    return Rect.fromPoints(docTopLeft, docBottomRight);
  }

  @override
  PdfViewerCoordinateConverter get doc2local => this;

  void forceRepaintAllPageImages() {
    _imageCache.cancelAllPendingRenderings();
    _magnifierImageCache.cancelAllPendingRenderings();
    _imageCache.releaseAllImages();
    _magnifierImageCache.releaseAllImages();
    _invalidate();
  }
}

class _PdfPageImageCache {
  final pageImages = <int, _PdfImageWithScale>{};
  final pageImageRenderingTimers = <int, Timer>{};
  final pageImagesPartial = <int, _PdfImageWithScaleAndRect>{};
  final cancellationTokens = <int, List<PdfPageRenderCancellationToken>>{};
  final pageImagePartialRenderingRequests = <int, _PdfPartialImageRenderingRequest>{};

  void addCancellationToken(int pageNumber, PdfPageRenderCancellationToken token) {
    var tokens = cancellationTokens.putIfAbsent(pageNumber, () => []);
    tokens.add(token);
  }

  void releasePartialImages() {
    for (final request in pageImagePartialRenderingRequests.values) {
      request.cancel();
    }
    pageImagePartialRenderingRequests.clear();
    for (final image in pageImagesPartial.values) {
      image.image.dispose();
    }
    pageImagesPartial.clear();
  }

  void releaseAllImages() {
    for (final timer in pageImageRenderingTimers.values) {
      timer.cancel();
    }
    pageImageRenderingTimers.clear();
    for (final request in pageImagePartialRenderingRequests.values) {
      request.cancel();
    }
    pageImagePartialRenderingRequests.clear();
    for (final image in pageImages.values) {
      image.image.dispose();
    }
    pageImages.clear();
    for (final image in pageImagesPartial.values) {
      image.image.dispose();
    }
    pageImagesPartial.clear();
  }

  void cancelPendingRenderings(int pageNumber) {
    final tokens = cancellationTokens[pageNumber];
    if (tokens != null) {
      for (final token in tokens) {
        token.cancel();
      }
      tokens.clear();
    }
  }

  void cancelAllPendingRenderings() {
    for (final pageNumber in cancellationTokens.keys) {
      cancelPendingRenderings(pageNumber);
    }
    cancellationTokens.clear();
  }

  void makeCacheImageForPageDirty(int pageNumber) {
    final image = pageImages[pageNumber];
    if (image != null) {
      image.isDirty = true;
    }
    final imagePartial = pageImagesPartial[pageNumber];
    if (imagePartial != null) {
      imagePartial.isDirty = true;
    }
  }

  void removeCacheImagesForPage(int pageNumber) {
    final removed = pageImages.remove(pageNumber);
    if (removed != null) {
      removed.image.dispose();
    }
    pageImagesPartial.remove(pageNumber)?.dispose();
  }

  void removeCacheImagesIfCacheBytesExceedsLimit(
    List<int> pageNumbers,
    int acceptableBytes,
    PdfPage currentPage, {
    required double Function(int pageNumber) dist,
  }) {
    pageNumbers.sort((a, b) => dist(b).compareTo(dist(a)));
    int getBytesConsumed(ui.Image? image) => image == null ? 0 : (image.width * image.height * 4).toInt();
    var bytesConsumed =
        pageImages.values.fold(0, (sum, e) => sum + getBytesConsumed(e.image)) +
        pageImagesPartial.values.fold(0, (sum, e) => sum + getBytesConsumed(e.image));
    for (final key in pageNumbers) {
      final removed = pageImages.remove(key);
      if (removed != null) {
        bytesConsumed -= getBytesConsumed(removed.image);
        removed.image.dispose();
      }
      final removedPartial = pageImagesPartial.remove(key);
      if (removedPartial != null) {
        bytesConsumed -= getBytesConsumed(removedPartial.image);
        removedPartial.dispose();
      }
      if (bytesConsumed <= acceptableBytes) {
        break;
      }
    }
  }

  /// Hard cap on the number of distinct page entries kept in the in-memory
  /// image cache. Counts the *union* of [pageImages] and [pageImagesPartial]
  /// keys (a page with both a preview and a partial image counts once).
  ///
  /// ARGUS fork addition (2026-05-13). The original
  /// [removeCacheImagesIfCacheBytesExceedsLimit] is reactive (it only evicts
  /// pages that have already left the cache-extent rectangle, and only when
  /// the byte budget is exceeded). On low-RAM smart-board hardware viewing
  /// 300-1000 page PDFs, a fast scroll-thumb drag can enqueue hundreds of
  /// renders before the byte-budget eviction fires — see pdfrx issue #604.
  /// This method runs at the end of every paint frame and proactively
  /// evicts the farthest cached pages (by document-coordinate distance from
  /// [currentPage]) until the cache count is no greater than [maxPageCount].
  ///
  /// No-op if the cache is already at or below the cap. Disposes the
  /// underlying `ui.Image` GPU textures for evicted entries so PDFium's
  /// pixel buffers + the GL/Vulkan texture both get released.
  void removeCacheImagesIfPageCountExceedsLimit(
    int maxPageCount,
    PdfPage currentPage, {
    required double Function(int pageNumber) dist,
  }) {
    // Union of both image maps' keys — a page with both preview + partial
    // counts as one entry, matching how we'd report cache size to a human.
    final allKeys = <int>{...pageImages.keys, ...pageImagesPartial.keys}.toList();
    if (allKeys.length <= maxPageCount) return;

    // Farthest pages first. Stable for ties (distance == 0 only for current).
    allKeys.sort((a, b) => dist(b).compareTo(dist(a)));

    var remaining = allKeys.length;
    for (final key in allKeys) {
      if (remaining <= maxPageCount) break;
      // Never evict the current page itself even if maxPageCount somehow
      // ends up < 1 (defensive — caller is expected to pass >= 1).
      if (key == currentPage.pageNumber) continue;
      // ARGUS fork — Phase X1 (2026-05-14). Drop any in-flight render
      // cancellation tokens *and* their debounced kick-off timer for
      // the evicted page. Upstream only freed `pageImages` /
      // `pageImagesPartial`; the `cancellationTokens` and
      // `pageImageRenderingTimers` maps kept entries indefinitely. On
      // a 270-page document that's a slow but real heap leak that
      // also lets cancelled renders continue to occupy
      // BackgroundWorker slots if they were already in flight.
      cancelPendingRenderings(key);
      pageImageRenderingTimers.remove(key)?.cancel();
      final removed = pageImages.remove(key);
      if (removed != null) removed.image.dispose();
      pageImagesPartial.remove(key)?.dispose();
      remaining--;
    }
  }
}

class _PdfPartialImageRenderingRequest {
  _PdfPartialImageRenderingRequest(this.timer, this.cancellationToken, this.rect, this.scale);
  final Timer timer;
  final PdfPageRenderCancellationToken cancellationToken;

  /// ARGUS fork (2026-08-20). Which (rect, scale) this in-flight request is
  /// for. Upstream did not track this, so `_requestRealSizePartialImage`
  /// cancelled the pending render on EVERY repaint — even when the new
  /// request was byte-for-byte identical. See that method for the field
  /// report this closes.
  final Rect rect;
  final double scale;

  void cancel() {
    timer.cancel();
    cancellationToken.cancel();
  }
}

class _PdfImageWithScale {
  _PdfImageWithScale(this.image, this.scale);
  final ui.Image image;
  final double scale;

  int get width => image.width;
  int get height => image.height;

  bool isDirty = false;

  void dispose() {
    image.dispose();
  }
}

class _PdfImageWithScaleAndRect extends _PdfImageWithScale {
  _PdfImageWithScaleAndRect(super.image, super.scale, this.rect, this.left, this.top);
  final Rect rect;
  final int left;
  final int top;

  int get bottom => top + height;
  int get right => left + width;

  void draw(Canvas canvas, [FilterQuality filterQuality = FilterQuality.low]) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      rect,
      Paint()..filterQuality = filterQuality,
    );
  }

  void drawNoScale(Canvas canvas, int x, int y, [FilterQuality filterQuality = FilterQuality.low]) {
    canvas.drawImage(
      image,
      Offset((left - x).toDouble(), (top - y).toDouble()),
      Paint()..filterQuality = filterQuality,
    );
  }
}

class _PdfViewerTransformationController extends TransformationController {
  _PdfViewerTransformationController(this._state);

  final _PdfViewerState _state;

  @override
  set value(Matrix4 newValue) {
    super.value = _state._makeMatrixInSafeRange(newValue);
  }
}

/// What selection part is moving by mouse-dragging/finger-panning.
enum _TextSelectionPart { none, free, a, b }

/// Represents a point (combination of page and character index) in the text selection.
/// It contains the [PdfPageText] and the index of the character in that text.
@immutable
class PdfTextSelectionPoint {
  const PdfTextSelectionPoint(this.text, this.index);

  /// The page text associated with this selection point.
  final PdfPageText text;

  /// The index of the character in the [text].
  ///
  /// Similar to [PdfPageText.getRangeFromAB], this index is inclusive; even for the end point of the selection.
  /// In other words, for the end of the selection, the index points to the last selected character.
  final int index;

  /// Whether the index is valid in the [text].
  bool get isValid => index >= 0 && index < text.charRects.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfTextSelectionPoint) return false;
    return text == other.text && index == other.index;
  }

  bool operator <(PdfTextSelectionPoint other) {
    if (text.pageNumber != other.text.pageNumber) {
      return text.pageNumber < other.text.pageNumber;
    }
    return index < other.index;
  }

  bool operator >(PdfTextSelectionPoint other) => !(this <= other);

  bool operator <=(PdfTextSelectionPoint other) {
    if (text.pageNumber != other.text.pageNumber) {
      return text.pageNumber < other.text.pageNumber;
    }
    return index <= other.index;
  }

  bool operator >=(PdfTextSelectionPoint other) => !(this < other);

  @override
  int get hashCode => text.hashCode ^ index.hashCode;

  @override
  String toString() => '$PdfTextSelectionPoint(text: $text, index: $index)';
}

/// Represents a range of text selection between two points.
class PdfTextSelectionRange {
  /// Creates a [PdfTextSelectionRange] from two selection points.
  ///
  /// The points can be in any order; the constructor will ensure that [start] is less than or equal to [end].
  PdfTextSelectionRange.fromPoints(PdfTextSelectionPoint a, PdfTextSelectionPoint b)
    : start = a <= b ? a : b,
      end = a <= b ? b : a;

  /// The start point of the text selection.
  final PdfTextSelectionPoint start;

  /// The end point of the text selection.
  ///
  /// Please note that the index of this point is inclusive; it points to the last selected character.
  final PdfTextSelectionPoint end;
}

/// Represents the anchor point of the text selection.
///
/// It contains the rectangle of the anchor point, the text direction, and the type of the anchor (A or B).
@immutable
class PdfTextSelectionAnchor {
  const PdfTextSelectionAnchor(this.rect, this.direction, this.type, this.page, this.index);

  /// The rectangle of the character, on which the anchor is associated to.
  ///
  /// This rectangle is in the document coordinates.
  final Rect rect;

  /// The text direction of the anchored character.
  final PdfTextDirection direction;

  /// The type of the anchor, either [PdfTextSelectionAnchorType.a] or [PdfTextSelectionAnchorType.b].
  final PdfTextSelectionAnchorType type;

  /// The page text on which the anchor is associated to.
  final PdfPageText page;

  /// The index of the character in [page].
  ///
  /// Please note that the index is always inclusive, even for the end anchor (B);
  ///
  /// When selecting `"Selection"` in `"This is a Selection."`, the index of the start anchor (A) is 10,
  /// and the index of the end anchor (B) is 19 (not 18).
  ///
  /// ```
  ///                                         A                               B
  /// 0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  19
  /// +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
  /// | T | h | i | s |   | i | s |   | a |   | S | e | l | e | c | t | i | o | n | . |
  /// +---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+---+
  /// ```
  final int index;

  /// The point of the anchor in the document coordinates, which is an apex of [rect] depending on
  /// the [direction] and [type].
  Offset get anchorPoint {
    switch (direction) {
      case PdfTextDirection.ltr:
      case PdfTextDirection.unknown:
        return type == PdfTextSelectionAnchorType.a ? rect.topLeft : rect.bottomRight;
      case PdfTextDirection.rtl:
        return type == PdfTextSelectionAnchorType.a ? rect.topRight : rect.bottomLeft;
      case PdfTextDirection.vrtl:
        return type == PdfTextSelectionAnchorType.a ? rect.topRight : rect.bottomLeft;
    }
  }

  /// Copies the current instance with the given parameters.
  PdfTextSelectionAnchor copyWith({
    Rect? rect,
    PdfTextDirection? direction,
    PdfTextSelectionAnchorType? type,
    PdfPageText? page,
    int? index,
  }) {
    return PdfTextSelectionAnchor(
      rect ?? this.rect,
      direction ?? this.direction,
      type ?? this.type,
      page ?? this.page,
      index ?? this.index,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfTextSelectionAnchor) return false;
    return rect == other.rect &&
        direction == other.direction &&
        type == other.type &&
        page == other.page &&
        index == other.index;
  }

  @override
  int get hashCode {
    return rect.hashCode ^ direction.hashCode ^ type.hashCode ^ page.hashCode ^ index.hashCode;
  }
}

/// Defines the type of the text selection anchor.
///
/// It can be either [a] or [b], which represents the start and end of the selection respectively.
enum PdfTextSelectionAnchorType { a, b }

/// Defines page layout.
class PdfPageLayout {
  PdfPageLayout({required this.pageLayouts, required this.documentSize})
      : _isVerticallyMonotone = _detectVerticallyMonotone(pageLayouts);
  final List<Rect> pageLayouts;
  final Size documentSize;

  /// ARGUS fork addition (F1, 2026-05-14). Pre-computed at
  /// construction so the binary-search visible-range helpers below can
  /// short-circuit to a linear scan for arbitrary custom layouts
  /// without re-checking per call.
  final bool _isVerticallyMonotone;

  static bool _detectVerticallyMonotone(List<Rect> pages) {
    for (var i = 1; i < pages.length; i++) {
      if (pages[i].top < pages[i - 1].top) return false;
    }
    return true;
  }

  /// Returns the half-open page-index range `[begin, end)` whose
  /// layout rects might overlap [viewport]. O(log N) when pages are
  /// vertically monotone (the default pdfrx layout AND argus's
  /// `_singlePageLayout`); O(N) linear fallback for custom non-monotone
  /// layouts.
  ///
  /// ARGUS fork addition (F1, 2026-05-14). The viewer's hot loops
  /// (`_paintPagesCustom`, `_buildPageOverlayWidgets`, hit tests) used
  /// to iterate every page in the document on every frame just to
  /// discover which ones overlap the viewport — for a 1000-page PDF
  /// at 60 fps that's 60 000 rect intersects per second of pan/zoom,
  /// the bulk of them returning empty. With this range computed once
  /// per paint, those loops drop to ~3-5 iterations on typical zoom.
  ///
  /// The returned range is a **superset** of truly visible pages —
  /// callers should still apply a per-page rect.intersect check to
  /// weed out partial overlaps, but anything OUTSIDE the range is
  /// guaranteed not to overlap.
  ({int begin, int end}) visiblePageRange(Rect viewport) {
    final pages = pageLayouts;
    if (pages.isEmpty) return (begin: 0, end: 0);
    if (!_isVerticallyMonotone) {
      return (begin: 0, end: pages.length);
    }
    final yTop = viewport.top;
    final yBottom = viewport.bottom;
    // First page index where rect.bottom > yTop (the first page that
    // could possibly overlap the viewport from the top).
    int lo = 0, hi = pages.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (pages[mid].bottom <= yTop) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final begin = lo;
    // First page index where rect.top >= yBottom (the first page
    // entirely below the viewport).
    hi = pages.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (pages[mid].top < yBottom) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return (begin: begin, end: lo);
  }

  /// Returns the index of the page whose layout rect contains
  /// [point], or -1 if no page contains it. O(log N) for vertically
  /// monotone layouts; O(N) fallback otherwise. ARGUS fork addition
  /// (F1, 2026-05-14).
  int pageIndexContaining(Offset point) {
    final pages = pageLayouts;
    if (pages.isEmpty) return -1;
    if (!_isVerticallyMonotone) {
      for (var i = 0; i < pages.length; i++) {
        if (pages[i].contains(point)) return i;
      }
      return -1;
    }
    // Binary search by y, then verify x containment.
    int lo = 0, hi = pages.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (pages[mid].bottom <= point.dy) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo >= pages.length) return -1;
    if (pages[lo].contains(point)) return lo;
    return -1;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PdfPageLayout) return false;
    return listEquals(pageLayouts, other.pageLayouts) && documentSize == other.documentSize;
  }

  @override
  int get hashCode => pageLayouts.hashCode ^ documentSize.hashCode;
}

/// Represents the result of the hit test on the page.
class PdfPageHitTestResult {
  PdfPageHitTestResult({required this.page, required this.offset});

  /// The page that was hit.
  final PdfPage page;

  /// The offset in the PDF page coordinates; the origin is at the bottom-left corner.
  final PdfPoint offset;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PdfPageHitTestResult && other.page == page && other.offset == offset;
  }

  @override
  int get hashCode => page.hashCode ^ offset.hashCode;
}

/// Controls associated [PdfViewer].
///
/// It's always your option to extend (inherit) the class to customize the [PdfViewer] behavior.
///
/// Please note that almost all fields and functions are not working if the controller is not associated
/// to any [PdfViewer].
/// You can check whether the controller is associated or not by checking [isReady] property.
class PdfViewerController extends ValueListenable<Matrix4> {
  _PdfViewerState? __state;
  final _listeners = <VoidCallback>[];

  void _attach(_PdfViewerState? state) {
    __state?._txController.removeListener(_notifyListeners);
    __state = state;
    __state?._txController.addListener(_notifyListeners);
  }

  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  _PdfViewerState get _state => __state!;

  /// Get the associated [PdfViewer] widget.
  PdfViewer get widget => _state.widget;

  /// Get the associated [PdfViewerParams] parameters.
  PdfViewerParams get params => widget.params;

  /// Determine whether the document/pages are ready or not.
  bool get isReady => __state?._document?.pages != null;

  /// The document layout size.
  Size get documentSize => _state._layout!.documentSize;

  /// Page layout.
  PdfPageLayout get layout => _state._layout!;

  /// The view port size (The widget's client area's size)
  Size get viewSize => _state._viewSize!;

  /// The zoom ratio that fits the page's smaller side (either horizontal or vertical) to the view port.
  double get coverScale => _state._coverScale!;

  /// The zoom ratio that fits whole the page to the view port.
  double? get alternativeFitScale => _state._alternativeFitScale;

  /// The minimum zoom ratio allowed.
  double get minScale => _state.minScale;

  /// The area of the document layout which is visible on the view port.
  Rect get visibleRect => _state._visibleRect;

  /// Get the associated document.
  ///
  /// Please note that the field does not ensure that the [PdfDocument] is alive during long asynchronous operations.
  ///
  /// **If you want to do some time consuming asynchronous operation, consider to use [useDocument] instead.**
  PdfDocument get document => _state._document!;

  /// Get the associated pages.
  ///
  /// Please note that the field does not ensure that the associated [PdfDocument] is alive during long asynchronous
  /// operations. For page count, use [pageCount] instead.
  ///
  /// **If you want to do some time consuming asynchronous operation, consider to use [useDocument] instead.**
  List<PdfPage> get pages => _state._document!.pages;

  /// Get the page count of the document.
  int get pageCount => _state._document!.pages.length;

  /// The current page number if available.
  int? get pageNumber => _state._pageNumber;

  /// The document reference associated to the [PdfViewer].
  PdfDocumentRef get documentRef => _state.widget.documentRef;

  /// Within call to the function, it ensures that the [PdfDocument] is alive (not null and not disposed).
  ///
  /// If [ensureLoaded] is true, it tries to ensure that the document is loaded.
  /// If the document is not loaded, the function does not call [task] and return null.
  /// [cancelLoading] is used to cancel the loading process.
  ///
  /// The following fragment explains how to use [PdfDocument]:
  ///
  /// ```dart
  /// await controller.useDocument(
  ///   (document) async {
  ///     // Use the document here
  ///   },
  /// );
  /// ```
  ///
  /// This is just a shortcut for the combination of [PdfDocumentRef.resolveListenable] and [PdfDocumentListenable.useDocument].
  ///
  /// For more information, see [PdfDocumentRef], [PdfDocumentRef.resolveListenable], and [PdfDocumentListenable.useDocument].
  FutureOr<T?> useDocument<T>(
    FutureOr<T> Function(PdfDocument document) task, {
    bool ensureLoaded = true,
    Completer? cancelLoading,
  }) => documentRef.resolveListenable().useDocument(task, ensureLoaded: ensureLoaded, cancelLoading: cancelLoading);

  @override
  Matrix4 get value => _state._txController.value;

  set value(Matrix4 newValue) {
    _state._txController.value = makeMatrixInSafeRange(newValue, forceClamp: true);
  }

  @override
  void addListener(ui.VoidCallback listener) => _listeners.add(listener);

  @override
  void removeListener(ui.VoidCallback listener) => _listeners.remove(listener);

  /// Restrict matrix to the safe range.
  Matrix4 makeMatrixInSafeRange(Matrix4 newValue, {bool forceClamp = false}) =>
      _state._makeMatrixInSafeRange(newValue, forceClamp: forceClamp);

  double getNextZoom({bool loop = true}) => _state._findNextZoomStop(currentZoom, zoomUp: true, loop: loop);

  double getPreviousZoom({bool loop = true}) => _state._findNextZoomStop(currentZoom, zoomUp: false, loop: loop);

  void notifyFirstChange(void Function() onFirstChange) {
    void handler() {
      removeListener(handler);
      onFirstChange();
    }

    addListener(handler);
  }

  /// Go to the specified area.
  ///
  /// [anchor] specifies how the page is positioned if the page is larger than the view.
  Future<void> goToArea({
    required Rect rect,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) => _state._goToArea(rect: rect, anchor: anchor, duration: duration);

  /// Go to the specified page.
  ///
  /// [anchor] specifies how the page is positioned if the page is larger than the view.
  Future<void> goToPage({
    required int pageNumber,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) => _state._goToPage(pageNumber: pageNumber, anchor: anchor, duration: duration);

  /// Go to the specified area inside the page.
  ///
  /// [pageNumber] specifies the page number.
  /// [rect] specifies the area to go in page coordinates.
  /// [anchor] specifies how the page is positioned if the page is larger than the view.
  Future<void> goToRectInsidePage({
    required int pageNumber,
    required PdfRect rect,
    PdfPageAnchor? anchor,
    Duration duration = const Duration(milliseconds: 200),
  }) => _state._goToRectInsidePage(pageNumber: pageNumber, rect: rect, anchor: anchor, duration: duration);

  /// Calculate the rectangle for the specified area inside the page.
  ///
  /// [pageNumber] specifies the page number.
  /// [rect] specifies the area to go in page coordinates.
  Rect calcRectForRectInsidePage({required int pageNumber, required PdfRect rect}) =>
      _state._calcRectForRectInsidePage(pageNumber: pageNumber, rect: rect);

  /// Calculate the matrix for the specified area inside the page.
  ///
  /// [pageNumber] specifies the page number.
  /// [rect] specifies the area to go in page coordinates.
  /// [anchor] specifies how the page is positioned if the page is larger than the view.
  Matrix4 calcMatrixForRectInsidePage({required int pageNumber, required PdfRect rect, PdfPageAnchor? anchor}) =>
      _state._calcMatrixForRectInsidePage(pageNumber: pageNumber, rect: rect, anchor: anchor);

  /// Go to the specified destination.
  ///
  /// [dest] specifies the destination.
  /// [duration] specifies the duration of the animation.
  Future<bool> goToDest(PdfDest? dest, {Duration duration = const Duration(milliseconds: 200)}) =>
      _state._goToDest(dest, duration: duration);

  /// Calculate the matrix for the specified destination.
  ///
  /// [dest] specifies the destination.
  Matrix4? calcMatrixForDest(PdfDest? dest) => _state._calcMatrixForDest(dest);

  /// Calculate the matrix to fit the page into the view.
  ///
  /// `/Fit` command on [PDF 32000-1:2008, 12.3.2.2 Explicit Destinations, Table 151](https://opensource.adobe.com/dc-acrobat-sdk-docs/pdfstandards/PDF32000_2008.pdf#page=374)
  Matrix4? calcMatrixForFit({required int pageNumber}) =>
      calcMatrixForDest(PdfDest(pageNumber, PdfDestCommand.fit, null));

  /// Calculate the matrix to fit the specified page width into the view.
  ///
  Matrix4? calcMatrixFitWidthForPage({required int pageNumber}) {
    final page = layout.pageLayouts[pageNumber - 1];
    final zoom = (viewSize.width - params.margin * 2) / page.width;
    final y = (viewSize.height / 2 - params.margin) / zoom;
    return calcMatrixFor(page.topCenter.translate(0, y), zoom: zoom, viewSize: viewSize);
  }

  /// Calculate the matrix to fit the specified page height into the view.
  ///
  Matrix4? calcMatrixFitHeightForPage({required int pageNumber}) {
    final page = layout.pageLayouts[pageNumber - 1];
    final zoom = (viewSize.height - params.margin * 2) / page.height;
    return calcMatrixFor(page.center, zoom: zoom, viewSize: viewSize);
  }

  /// Get list of possible matrices that fit some of the pages into the view.
  ///
  /// [sortInSuitableOrder] specifies whether the result is sorted in a suitable order.
  ///
  /// Because [PdfViewer] can show multiple pages at once, there are several possible
  /// matrices to fit the pages into the view according to several criteria.
  /// The method returns the list of such matrices.
  ///
  /// In theory, the method can be also used to determine the dominant pages in the view.
  List<PdfPageFitInfo> calcFitZoomMatrices({bool sortInSuitableOrder = true}) {
    final viewRect = visibleRect;
    final result = <PdfPageFitInfo>[];
    final pos = centerPosition;
    for (var i = 0; i < layout.pageLayouts.length; i++) {
      final page = layout.pageLayouts[i];
      if (page.intersect(viewRect).isEmpty) continue;
      final boundaryMargin = _state._adjustedBoundaryMargins;
      final zoom = viewSize.width / (page.width + (params.margin * 2) + boundaryMargin.horizontal);

      // NOTE: keep the y-position but center the x-position
      final newMatrix = calcMatrixFor(Offset(page.left + page.width / 2, pos.dy), zoom: zoom);

      final intersection = newMatrix.calcVisibleRect(viewSize).intersect(page);
      // if the page is not visible after changing the zoom, ignore it
      if (intersection.isEmpty) continue;
      final intersectionRatio = intersection.width * intersection.height / (page.width * page.height);
      result.add(PdfPageFitInfo(pageNumber: i + 1, matrix: newMatrix, visibleAreaRatio: intersectionRatio));
    }
    if (sortInSuitableOrder) {
      result.sort((a, b) => b.visibleAreaRatio.compareTo(a.visibleAreaRatio));
    }
    return result;
  }

  /// Calculate the matrix for the page.
  ///
  /// [pageNumber] specifies the page number.
  /// [anchor] specifies how the page is positioned if the page is larger than the view.
  Matrix4 calcMatrixForPage({required int pageNumber, PdfPageAnchor? anchor}) =>
      _state._calcMatrixForPage(pageNumber: pageNumber, anchor: anchor);

  /// Calculate the matrix for the specified area.
  ///
  /// [rect] specifies the area in document coordinates.
  /// [anchor] specifies how the page is positioned if the page is larger than the view.
  Matrix4 calcMatrixForArea({required Rect rect, PdfPageAnchor? anchor}) =>
      _state._calcMatrixForArea(rect: rect, anchor: anchor);

  /// Go to the specified position by the matrix.
  ///
  /// All the `goToXXX` functions internally calls the function.
  /// So if you customize the behavior of the viewer, you can extend [PdfViewerController] and override the function:
  ///
  /// ```dart
  /// class MyPdfViewerController extends PdfViewerController {
  ///   @override
  ///   Future<void> goTo(
  ///     Matrix4? destination, {
  ///     Duration duration = const Duration(milliseconds: 200),
  ///     }) async {
  ///       print('goTo');
  ///       super.goTo(destination, duration: duration);
  ///   }
  /// }
  /// ```
  Future<void> goTo(Matrix4? destination, {Duration duration = const Duration(milliseconds: 200)}) =>
      _state._goTo(destination, duration: duration);

  /// Ensure the specified area is visible inside the view port.
  ///
  /// If the area is larger than the view port, the area is zoomed to fit the view port.
  /// [margin] adds extra margin to the area.
  Future<void> ensureVisible(Rect rect, {Duration duration = const Duration(milliseconds: 200), double margin = 0}) =>
      _state._ensureVisible(rect, duration: duration, margin: margin);

  /// Calculate the matrix to center the specified position.
  Matrix4 calcMatrixFor(Offset position, {double? zoom, Size? viewSize}) =>
      _state._calcMatrixFor(position, zoom: zoom ?? currentZoom, viewSize: viewSize ?? this.viewSize);

  Offset get centerPosition => value.calcPosition(viewSize);

  Matrix4 calcMatrixForRect(Rect rect, {double? zoomMax, double? margin}) =>
      _state._calcMatrixForRect(rect, zoomMax: zoomMax, margin: margin);

  Matrix4 calcMatrixToEnsureRectVisible(Rect rect, {double margin = 0}) =>
      _state._calcMatrixToEnsureRectVisible(rect, margin: margin);

  /// Do hit-test against laid out pages.
  ///
  /// Returns the hit-test result if the specified offset is inside a page; otherwise null.
  ///
  /// [useDocumentLayoutCoordinates] specifies whether the offset is in the document layout coordinates;
  /// if true, the offset is in the document layout coordinates; otherwise, the offset is in the widget's local coordinates.
  PdfPageHitTestResult? getPdfPageHitTestResult(Offset offset, {required bool useDocumentLayoutCoordinates}) =>
      _state._getPdfPageHitTestResult(offset, useDocumentLayoutCoordinates: useDocumentLayoutCoordinates);

  /// Set the current page number.
  ///
  /// This function does not scroll/zoom to the specified page but changes the current page number.
  void setCurrentPageNumber(int pageNumber) => _state._setCurrentPageNumber(pageNumber);

  /// The current zoom ratio.
  double get currentZoom => value.zoom;

  /// Set the zoom ratio with the specified position as the zoom center.
  ///
  /// [position] specifies the zoom center in the document coordinates.
  /// [zoom] specifies the new zoom ratio.
  /// [duration] specifies the duration of the animation.
  Future<void> setZoom(Offset position, double zoom, {Duration duration = const Duration(milliseconds: 200)}) =>
      _state._setZoom(position, zoom, duration: duration);

  /// Zoom in with the specified position as the zoom center.
  ///
  /// [zoomCenter] specifies the zoom center in the document coordinates; if null, the center of the view is used.
  /// [loop] specifies whether to loop the zoom stops.
  /// [duration] specifies the duration of the animation.
  Future<void> zoomUp({bool loop = false, Offset? zoomCenter, Duration duration = const Duration(milliseconds: 200)}) =>
      _state._zoomUp(loop: loop, zoomCenter: zoomCenter, duration: duration);

  /// Zoom out with the specified position as the zoom center.
  ///
  /// [zoomCenter] specifies the zoom center in the document coordinates; if null, the center of the view is used.
  /// [loop] specifies whether to loop the zoom stops.
  /// [duration] specifies the duration of the animation.
  Future<void> zoomDown({
    bool loop = false,
    Offset? zoomCenter,
    Duration duration = const Duration(milliseconds: 200),
  }) => _state._zoomDown(loop: loop, zoomCenter: zoomCenter, duration: duration);

  /// Set the zoom ratio with the document point corresponding to the specified local position is kept unmoved
  /// on the view.
  ///
  /// [localPosition] specifies the position in the widget's local coordinates.
  /// [newZoom] specifies the new zoom ratio.
  /// [duration] specifies the duration of the animation.
  Future<void> zoomOnLocalPosition({
    required Offset localPosition,
    required double newZoom,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    final center = _state._localPositionToZoomCenter(localPosition, newZoom);
    await _state._setZoom(center, newZoom, duration: duration);
  }

  /// Zoom in with the document point corresponding to the specified local position is kept unmoved
  /// on the view.
  ///
  /// [localPosition] specifies the position in the widget's local coordinates.
  /// [loop] specifies whether to loop the zoom stops.
  /// [duration] specifies the duration of the animation.
  Future<void> zoomUpOnLocalPosition({
    required Offset localPosition,
    bool loop = false,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    final newZoom = _state._findNextZoomStop(currentZoom, zoomUp: true, loop: loop);
    final center = _state._localPositionToZoomCenter(localPosition, newZoom);
    await _state._setZoom(center, newZoom, duration: duration);
  }

  /// Zoom out with the document point corresponding to the specified local position is kept unmoved
  /// on the view.
  ///
  /// [localPosition] specifies the position in the widget's local coordinates.
  /// [loop] specifies whether to loop the zoom stops.
  /// [duration] specifies the duration of the animation.
  Future<void> zoomDownOnLocalPosition({
    required Offset localPosition,
    bool loop = false,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    final newZoom = _state._findNextZoomStop(currentZoom, zoomUp: false, loop: loop);
    final center = _state._localPositionToZoomCenter(localPosition, newZoom);
    await _state._setZoom(center, newZoom, duration: duration);
  }

  RenderBox? get renderBox => _state._renderBox;

  /// Converts the global position to the local position in the widget.
  Offset? globalToLocal(Offset global) => _state._globalToLocal(global);

  /// Converts the local position to the global position in the widget.
  Offset? localToGlobal(Offset local) => _state._localToGlobal(local);

  /// Converts the global position to the local position in the PDF document structure.
  Offset? globalToDocument(Offset global) => _state._globalToDocument(global);

  /// Converts the local position in the PDF document structure to the global position.
  Offset? documentToGlobal(Offset document) => _state._documentToGlobal(document);

  /// Converts local coordinates to document coordinates.
  Offset localToDocument(Offset local) => _state._localToDocument(local);

  /// Converts document coordinates to local coordinates.
  Offset documentToLocal(Offset document) => _state._documentToLocal(document);

  /// Converts document coordinates to local coordinates.
  PdfViewerCoordinateConverter get doc2local => _state;

  /// Provided to workaround certain widgets eating wheel events. Use with [Listener.onPointerSignal].
  void handlePointerSignalEvent(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      _state._onWheelDelta(event);
    }
  }

  /// Invalidates the current Widget display state.
  ///
  /// Almost identical to `setState` but can be called outside the state.
  void invalidate() => _state._invalidate();

  /// The text selection delegate.
  PdfTextSelectionDelegate get textSelectionDelegate => _state;

  /// [FocusNode] associated to the [PdfViewer] if available.
  FocusNode? get focusNode => _state._getFocusNode();

  /// Request focus to the [PdfViewer].
  void requestFocus() => _state._requestFocus();

  /// Force redraw all the page images.
  void forceRepaintAllPageImages() => _state.forceRepaintAllPageImages();
}

/// [PdfViewerController.calcFitZoomMatrices] returns the list of this class.
@immutable
class PdfPageFitInfo {
  const PdfPageFitInfo({required this.pageNumber, required this.matrix, required this.visibleAreaRatio});

  /// The page number of the target page.
  final int pageNumber;

  /// The matrix to fit the page horizontally into the view.
  final Matrix4 matrix;

  /// The ratio of the visible area of the page. 1 means the whole page is visible inside the view.
  final double visibleAreaRatio;

  @override
  String toString() => 'PdfPageFitInfo(pageNumber=$pageNumber, visibleAreaRatio=$visibleAreaRatio, matrix=$matrix)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PdfPageFitInfo &&
        other.pageNumber == pageNumber &&
        other.matrix == matrix &&
        other.visibleAreaRatio == visibleAreaRatio;
  }

  @override
  int get hashCode => pageNumber.hashCode ^ matrix.hashCode ^ visibleAreaRatio.hashCode;
}

extension PdfMatrix4Ext on Matrix4 {
  /// Zoom ratio of the matrix.
  double get zoom => storage[0];

  /// X position of the matrix.
  double get xZoomed => storage[12];

  /// X position of the matrix.
  set xZoomed(double value) => storage[12] = value;

  /// Y position of the matrix.
  double get yZoomed => storage[13];

  /// Y position of the matrix.
  set yZoomed(double value) => storage[13] = value;

  double get x => xZoomed / zoom;

  set x(double value) => xZoomed = value * zoom;

  double get y => yZoomed / zoom;

  set y(double value) => yZoomed = value * zoom;

  /// Calculate the position of the matrix based on the specified view size.
  ///
  /// Because [Matrix4] does not have the information of the view size,
  /// this function calculates the position based on the specified view size.
  Offset calcPosition(Size viewSize) => Offset((viewSize.width / 2 - xZoomed), (viewSize.height / 2 - yZoomed)) / zoom;

  /// Calculate the visible rectangle based on the specified view size.
  ///
  /// [margin] adds extra margin to the area.
  /// Because [Matrix4] does not have the information of the view size,
  /// this function calculates the visible rectangle based on the specified view size.
  Rect calcVisibleRect(Size viewSize, {double margin = 0}) => Rect.fromCenter(
    center: calcPosition(viewSize),
    width: (viewSize.width - margin * 2) / zoom,
    height: (viewSize.height - margin * 2) / zoom,
  );

  Offset transformOffset(Offset xy) {
    final x = xy.dx;
    final y = xy.dy;
    final w = x * storage[3] + y * storage[7] + storage[15];
    return Offset(
      (x * storage[0] + y * storage[4] + storage[12]) / w,
      (x * storage[1] + y * storage[5] + storage[13]) / w,
    );
  }
}

extension RectExt on Rect {
  Rect operator *(double operand) => Rect.fromLTRB(left * operand, top * operand, right * operand, bottom * operand);

  Rect operator /(double operand) => Rect.fromLTRB(left / operand, top / operand, right / operand, bottom / operand);

  bool containsRect(Rect other) => contains(other.topLeft) && contains(other.bottomRight);

  Rect inflateHV({required double horizontal, required double vertical}) =>
      Rect.fromLTRB(left - horizontal, top - vertical, right + horizontal, bottom + vertical);
}

/// Create a [CustomPainter] from a paint function.
class _CustomPainter extends CustomPainter {
  /// Create a [CustomPainter] from a paint function.
  const _CustomPainter.fromFunctions(this.paintFunction, {this.hitTestFunction});
  final void Function(ui.Canvas canvas, ui.Size size) paintFunction;
  final bool Function(ui.Offset position)? hitTestFunction;
  @override
  void paint(ui.Canvas canvas, ui.Size size) => paintFunction(canvas, size);

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  @override
  bool hitTest(ui.Offset position) {
    if (hitTestFunction == null) return false;
    return hitTestFunction!(position);
  }
}

Widget _defaultErrorBannerBuilder(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
  PdfDocumentRef documentRef,
) {
  return pdfErrorWidget(context, error, stackTrace: stackTrace);
}

/// Handles the link painting and tap handling.
class _CanvasLinkPainter {
  _CanvasLinkPainter(this._state);
  final _PdfViewerState _state;
  MouseCursor _cursor = MouseCursor.defer;
  final _links = <int, List<PdfLink>>{};

  bool get isEnabled => _state.widget.params.linkHandlerParams != null;

  bool get isLaidOverPageOverlays =>
      _state.widget.params.linkHandlerParams != null && _state.widget.params.linkHandlerParams!.laidOverPageOverlays;

  bool get isLaidUnderPageOverlays =>
      _state.widget.params.linkHandlerParams != null && !_state.widget.params.linkHandlerParams!.laidOverPageOverlays;

  /// Reset all the internal data.
  void resetAll() {
    _cursor = MouseCursor.defer;
    _links.clear();
  }

  /// Release the page data.
  void releaseLinksForPage(int pageNumber) {
    _links.remove(pageNumber);
  }

  List<PdfLink>? _ensureLinksLoaded(PdfPage page, {void Function()? onLoaded}) {
    if (!page.isLoaded) return null;
    final links = _links[page.pageNumber];
    if (links != null) return links;
    synchronized(() async {
      final links = _links[page.pageNumber];
      if (links != null) return links;
      final enableAutoLinkDetection = _state.widget.params.linkHandlerParams?.enableAutoLinkDetection ?? true;
      _links[page.pageNumber] = await page.loadLinks(compact: true, enableAutoLinkDetection: enableAutoLinkDetection);
      if (onLoaded != null) {
        onLoaded();
      } else {
        _state._invalidate();
      }
    });
    return null;
  }

  PdfLink? _findLinkAtPosition(Offset position) {
    final hitResult = _state._getPdfPageHitTestResult(position, useDocumentLayoutCoordinates: false);
    if (hitResult == null) return null;
    final links = _ensureLinksLoaded(hitResult.page);
    if (links == null) return null;
    for (final link in links) {
      for (final rect in link.rects) {
        if (rect.containsPoint(hitResult.offset)) {
          return link;
        }
      }
    }
    return null;
  }

  bool _handleTapUp(Offset tapPosition) {
    _state._requestFocus();
    _cursor = MouseCursor.defer;
    final link = _findLinkAtPosition(tapPosition);
    if (link != null) {
      final onLinkTap = _state.widget.params.linkHandlerParams?.onLinkTap;
      if (onLinkTap != null) {
        onLinkTap(link);
        return true;
      }
    }
    final globalPosition = _state._localToGlobal(tapPosition)!;
    _state._handleGeneralTap(globalPosition, PdfViewerGeneralTapType.tap);
    return false;
  }

  /// Creates a [GestureDetector] for handling link taps and mouse cursor.
  Widget linkHandlingOverlay(Size size) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // link taps
      onTapUp: (details) => _handleTapUp(details.localPosition),
      child: StatefulBuilder(
        builder: (context, setState) {
          return MouseRegion(
            hitTestBehavior: HitTestBehavior.translucent,
            onHover: (event) {
              final link = _findLinkAtPosition(event.localPosition);
              final newCursor = link == null ? MouseCursor.defer : SystemMouseCursors.click;
              if (newCursor != _cursor) {
                _cursor = newCursor;
                setState(() {});
              }
            },
            onExit: (event) {
              _cursor = MouseCursor.defer;
              setState(() {});
            },
            cursor: _cursor,
          );
        },
      ),
    );
  }

  /// Paints the link highlights.
  void paintLinkHighlights(Canvas canvas, Rect pageRect, PdfPage page) {
    final links = _ensureLinksLoaded(page);
    if (links == null) return;

    final customPainter = _state.widget.params.linkHandlerParams?.customPainter;

    if (customPainter != null) {
      customPainter.call(canvas, pageRect, page, links);
      return;
    }

    final paint = Paint()
      ..color = _state.widget.params.linkHandlerParams?.linkColor ?? Colors.blue.withAlpha(50)
      ..style = PaintingStyle.fill;
    for (final link in links) {
      for (final rect in link.rects) {
        final rectLink = rect.toRectInDocument(page: page, pageRect: pageRect);
        canvas.drawRect(rectLink, paint);
      }
    }
  }
}
