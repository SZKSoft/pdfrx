# pdfrx Performance Notes — ARGUS Fork

> This file documents the performance-oriented patches applied to pdfrx
> v2.2.24 in this fork. Upstream is
> https://github.com/espresso3389/pdfrx/tree/pdfrx-v2.2.24. Patches are
> additive — default behaviour matches upstream unless an explicit knob is
> set in `PdfViewerParams`.
>
> **Patch history (newest first)**:
> - 2026-05-14: Phase E (regression fixes) + F (sparse loops + prefetch).
>   Triggered by user report — 170 MB / 270-page PDF still struggled in
>   editor after the initial fork landing. Root cause: **B1's early-stop
>   on `_loadDelayed` was making subsequent pages render as blank** because
>   `PdfPage.render()` returns null for `!isLoaded` pages and the
>   on-demand loader added 250-500 ms latency. Secondary cause: the
>   editor's `maxCachedPageCount: 5` was too tight, causing visible-page
>   eviction during normal scrolling. **All deferred work shipped** —
>   disk cache wired through pdfrx, sparse layout loops, neighbour
>   prefetch.
> - 2026-05-13: Initial Phase A (knobs + storms) + B1 (viewport-driven
>   metadata load, **later reverted**) + D1 (argus tuning) + D2a
>   (cache foundation, not wired).

## Target environment

- **Hardware**: Turkish smart-board hardware. 2-4 GB total RAM, integrated
  GPU, mid-range ARM or x86 CPU.
- **PDFs**: 300-1000 pages, 50-300 MB on disk. Press-ready textbooks and
  question banks.
- **Use case**: classroom presentation — teacher navigates page-by-page;
  fast scroll-thumb drag is rare but must not crash; cropped regions
  (Alan Yakınlaştırma / aidf magnifier) are revisited often.

## Upstream issues that motivated the fork

| Issue | Symptom | Status |
|-------|---------|--------|
| [#604](https://github.com/espresso3389/pdfrx/issues/604) | 500+ page PDF, fast scroll spikes RAM 300 MB → 1.7 GB on iPad, OOM kill. Same on Android. | **Open, no fix in 2.2.24** — Patches A1 + A2 + Phase B1 target this. |
| [#586](https://github.com/espresso3389/pdfrx/issues/586) | Opening 238-page PDF at page 229 causes repeated viewport jumps as pages load. | **Open** — Phase B1 (viewport-driven `_loadDelayed`) targets this. |
| [#542](https://github.com/espresso3389/pdfrx/issues/542) | PdfViewer slower than stock Flutter list on mobile scroll. | **Open** — Phase C1 (sparse layout O(visible) loops) targets this. |
| [#319](https://github.com/espresso3389/pdfrx/issues/319) | 1574-page PDF takes 4 s in pdfrx vs ~1 s in ReadEra/Firefox. | **Closed without fix** — same root cause as #604. |
| [#617](https://github.com/espresso3389/pdfrx/pull/617) | Download-progress events trigger full viewer reset → infinite white-flash reload on 10+ MB PDFs. | **Merged in 2.3.x** — Phase A4 cherry-picks. |

## Applied patches

### A1. Hard page-count cap (`maxCachedPageCount`)

- **New `PdfViewerParams.maxCachedPageCount`** (nullable `int`, default
  `null` = disabled, matches upstream behaviour).
- **New `_PdfPageImageCache.removeCacheImagesIfPageCountExceedsLimit`**
  method.
- Called at the end of `_paintPagesCustom`, after the existing
  byte-budget eviction. Evicts the farthest cached pages (by
  document-coordinate distance from the current page) until the cache
  holds at most `maxCachedPageCount` distinct page entries.
- **Why**: upstream's eviction is reactive (fires only when a page leaves
  the cache-extent rect AND the byte total has already overshot
  `maxImageBytesCachedOnMemory`). On a 1000-page PDF a fast scroll-thumb
  drag enqueues hundreds of renders before either condition triggers,
  causing the spike documented in issue #604. The count cap is a hard
  ceiling independent of per-page render size.
- **Files**: `lib/src/widgets/pdf_viewer_params.dart` (~line 60 +
  ~line 397), `lib/src/widgets/pdf_viewer.dart` (~line 1400 +
  `_PdfPageImageCache` class).

### A2. Invalidate-storm coalescing

- **Refactored `_PdfViewerState._invalidate`** from a synchronous
  `_updateStream.add(_txController.value)` to a post-frame-coalesced
  variant guarded by `_invalidateScheduled`.
- Multiple invalidations within the same frame collapse into one stream
  emission. `WidgetsBinding.scheduleFrame()` ensures the callback fires
  even when the app is otherwise idle.
- **Why**: `PdfDocument.loadPagesProgressively` emits one
  `PdfDocumentPageStatusChangedEvent` per page during the initial scan;
  on a 1000-page PDF that's 1000 synchronous `_invalidate()` calls, each
  triggering a full `_relayoutPages` (O(N)) + `_paintPagesCustom` (O(N))
  rebuild. The FIXME at the existing `_onDocumentEvent` site
  (`pdf_viewer.dart:415`) explicitly acknowledges this. Coalescing alone
  removes multi-second cold-open jank on 500+ page docs.
- **Files**: `lib/src/widgets/pdf_viewer.dart` `_invalidate` body.

### A3. Smart-board tuning guide (this doc)

Recommended `PdfViewerParams` values for the smart-board target:

```dart
PdfViewerParams(
  // Render preview at 72 DPI (default 200 DPI). For a Letter page this
  // drops preview memory from ~15 MB to ~2 MB per page.
  onePassRenderingScaleThreshold: 1.0,

  // Hard cap preview dimensions at 1024 px (default 2000). Mostly
  // belt-and-suspenders for very large pages (A3 charts, schoolbook
  // double-spreads).
  onePassRenderingSizeThreshold: 1024,

  // 16 MB byte budget for the in-memory image cache. Combined with the
  // page-count cap below it gives a predictable upper bound.
  maxImageBytesCachedOnMemory: 16 * 1024 * 1024,

  // ARGUS fork addition (A1). Never more than 5 pages cached
  // simultaneously regardless of per-page render size — current ± 2
  // neighbours fits the smart-board reading flow.
  maxCachedPageCount: 5,

  // Minimal prefetch radius. Smart-board hardware does not benefit from
  // wide cache extents because pdfrx renders at the device pixel ratio;
  // a wider extent simply pre-renders pages the teacher hasn't asked
  // for.
  horizontalCacheExtent: 0.0,
  verticalCacheExtent: 0.25,

  // Let the host app pick the minimum zoom. pdfrx's default clamps
  // min-zoom to the "see whole document" scale, which on a 1000-page
  // doc means the user can pinch out and trigger an attempt to render
  // every page at once.
  useAlternativeFitScaleAsMinScale: false,

  // PDFium native flag — caps PDFium's internal cached image budget.
  // Already true by default; documented here for completeness.
  limitRenderingCache: true,
)
```

Argus viewer and argus_editor should converge on these values in their
Phase D integration step.

### A4. Cherry-pick PR #617 (planned)

Backport upstream PR #617 (`skip full viewer reset on progress-only
notifications`) which is merged in 2.3.x but missing from 2.2.24. The fix
filters `PdfDocumentDownloadProgressEvent` so the doc-changed pipeline
doesn't wipe the page-image cache on every HTTP chunk progress event.

For argus's RAM-loaded PDFs this only matters for HTTP-source PDFs (not
the current use case), but cherry-picking removes a footgun if we ever
switch to streaming.

## Phase E patches (2026-05-14) — regression fixes + disk cache wiring

### E1. **REVERT** B1's `_loadDelayed` early-stop

`_loadDelayed` capped the initial eager metadata load at ~30 pages on
the theory that `_setCurrentPageNumber` would top up the range as the
user scrolled. In practice that made navigating to a far page render
visibly **blank** — `PdfPage.render()` short-circuits to null for
`!isLoaded` pages (`pdfrx_pdfium.dart:1295`), and the on-demand
`_ensurePagesLoadedThrough` extension adds 250-500 ms latency before
the new metadata batch lands. By then paint has already drawn the
white fallback rect.

The invalidate-storm fix (A2) already removes the cold-open cost of
N invalidations during the background load, so there's no upside to
stopping early. `_loadDelayed` now passes `1 << 30` as the target,
which the callback inside `_ensurePagesLoadedThrough` never reaches —
loading runs to natural completion.

**Files**: `pdf_viewer.dart` `_loadDelayed` body.

### E2. Editor `PdfViewerParams` loosening

Tightened too aggressively in the initial pass:
- `maxCachedPageCount: 5 → 15` (a chapter's worth of close reading).
- `maxImageBytesCachedOnMemory: 64 → 128 MB` (lets count cap be the
  binding limit at 144 dpi).
- `verticalCacheExtent: 0.5 → 1.0` (default; adjacent pages no
  longer visibly pop in during scroll).

**Files**: `argus_editor/.../pdf_canvas.dart`.

### E3. `PdfPageRenderCache` interface

New abstract class in `lib/src/widgets/pdf_page_render_cache.dart`,
exported via `pdfrx.dart`. Host apps implement `tryGet` and `put`
(both returning PNG bytes); pdfrx calls into it from
`_cachePagePreviewImage`. The cache key is the implementation's
responsibility — typically `document.sourceName + page.pageNumber +
scale`.

### E4. Wire `renderCache` into the render pipeline

`_cachePagePreviewImage` now:
1. Before invoking PDFium: calls `renderCache.tryGet(...)`. On a hit,
   decodes the PNG via `ui.instantiateImageCodec`, installs it into
   `pageImages`, fires `_invalidate`, returns.
2. After a successful fresh PDFium render: PNG-encodes the resulting
   `ui.Image` and `unawaited`s a call to `renderCache.put(...)`. Disk
   I/O is best-effort, never blocks render-completion → paint.

PNG decode is ~50 ms warm vs. ~200-500 ms for a fresh PDFium render
on smart-board hardware. The disk cache survives in-memory eviction
(`maxCachedPageCount`) and viewer sessions — second open of the same
.aidf paints page 1 almost immediately.

**Files**: `pdf_viewer.dart` `_cachePagePreviewImage` (now has a
prelude + sequel) + `_persistRenderToDiskCache` helper.

### E5. `ArgusPageCacheManager` / `ArgusEditorPageCacheManager`
        implement `PdfPageRenderCache`

The host-app singletons (built in Phase D2a) now satisfy the
interface, using their existing `pageKey` formatter with
`document.sourceName` as the source-key. Each app's singleton has a
distinct `flutter_cache_manager` cache key namespace so the two apps
don't collide on the same machine.

**Files**: `argus/lib/src/platform/page_cache_manager.dart`,
`argus_editor/lib/src/platform/page_cache_manager.dart`.

### E6. Wire `renderCache` in both apps

- argus viewer: `renderCache: ArgusPageCacheManager.instance` in
  `_buildViewerParams`. Also changed `sourceName: doc.displayName →
  sourceName: doc.sourceKey` for stable cache keying (`displayName`
  collides between two files with the same filename).
- argus editor: `renderCache: ArgusEditorPageCacheManager.instance`
  + new `stableSourceKey` parameter on `PdfCanvas` plumbed from
  `EditorSession.document.pdfSha256`. Replaced the per-mount
  timestamp `sourceName` with the SHA-256 — distinct documents still
  get distinct names (no pdfrx confusion), but the same document
  re-opens with the same name (disk cache hits).

**Files**: argus `pdf_viewer_screen.dart`, argus_editor
`pdf_canvas.dart` + `editor_screen.dart`.

## Phase F patches (2026-05-14) — sustained performance

### F1. Sparse `PdfPageLayout` (was C1, deferred earlier)

Three new methods on `PdfPageLayout`:
- `_isVerticallyMonotone` — pre-computed at construction.
- `visiblePageRange(viewport)` — binary search for the half-open
  `[begin, end)` page-index range overlapping the viewport. O(log N)
  for monotone layouts; O(N) fallback returns full range.
- `pageIndexContaining(point)` — binary search for the page whose
  rect contains a point. Used by hit tests.

Rewrote four hot loops in `pdf_viewer.dart` to use these:
- `_buildPageOverlayWidgets` — uses `visiblePageRange`.
- `_paintPagesCustom` — uses `visiblePageRange` + walks the cache /
  cancellation maps directly for off-screen cleanup (snapshot to
  avoid concurrent-modification).
- `_hitTestForTextSelection` — uses `pageIndexContaining`.
- `selectWord` — uses `pageIndexContaining`; loop replaced with a
  labeled-break block.

**Impact**: at 60 fps × 1000 pages × 4 hot loops = 240 000
per-second iterations dropped to ~12-20 (visible-only). On
smart-board hardware that's the difference between buttery scroll
and visible jank during pan/zoom.

**Files**: `pdf_viewer.dart` (4 call sites + `PdfPageLayout` class
gains 2 methods + 1 pre-computed flag).

### F2. Neighbour-page prefetch on page change

`_setCurrentPageNumber` now fires `_prefetchNeighbourPages(N)` after
its existing side effects. The helper queues preview renders for
pages `N+1`, `N-1`, `N+2`, `N-2` (priority order, skipping
out-of-bounds + already-cached-at-correct-scale + `!isLoaded`).

Through E4 each prefetch render also lands on disk, so the warming
helps future sessions too.

**Files**: `pdf_viewer.dart` `_setCurrentPageNumber` +
`_prefetchNeighbourPages` + `_estimatePreviewScaleForPrefetch`
helpers.

## Phase H patches (2026-05-14) — native single-page mode

The user clarified that **scrolling between pages was never wanted**:
the apps are presentation tools where the teacher / author navigates
strictly via buttons. The host-side `_singlePageLayout` workaround
(20 000 pt inter-page gaps + 2 000 pt boundary margin) was a hack
around upstream pdfrx's "you can only have one document layout"
assumption. With **Phase H** that assumption is no longer baked in.

### H1+H2. `PdfViewerParams.singlePageMode` + state-internal layout

New `bool singlePageMode = false` on `PdfViewerParams`. Default
preserves upstream behaviour. When set:

- `_singlePageLayoutPages` becomes the canonical layout function
  (overrides both the upstream default AND any user-supplied
  `layoutPages`).
- Every page gets a rect at the shared origin `(margin, margin)`
  with its own dimensions. Pages overlap each other in document
  space; the paint loop's short-circuit (H4) decides which one is
  actually visible.
- `documentSize` is **just the target page** (current /
  goto-target / initial, whichever applies) plus margins. No more
  5 000 000 pt-tall document for a 270-page book.

**Why shared origin instead of `Rect.zero` for non-current pages?**
Earlier drafts used `Rect.zero` so the existing
`rect.intersect(viewport).isEmpty` check filtered to one page
automatically. But host-app code (argus's focus regions, drawing
overlay, aidf region targets) reads `pageLayouts[N-1]` directly
to do PDF→doc coordinate conversion — `Rect.zero` would break every
such call site. Returning a valid per-page rect keeps host
code working, and the H4 paint short-circuit handles single-page
visibility.

### H3. `_relayoutPages` routing

Single-page mode wins over both `params.layoutPages` and the
upstream default. Three-line priority decision before computing
`newLayout`.

### H4. Visible-range short-circuit in paint + overlay loops

`_paintPagesCustom` and `_buildPageOverlayWidgets` now have a
single-page branch that pins the visible range to
`(currentPage-1, currentPage)` — one page index — without consulting
`_layout.visiblePageRange` (which would fall back to linear scan
anyway because the layout isn't vertically monotone).

### H5. `_calcMatrixForPage` synthesises target rect

For a `goToPage(N)` where N differs from the currently-laid-out
page, the layout doesn't have N's rect available at the right
position yet. `_calcMatrixForPage` in single-page mode synthesises
the target rect directly from `page.width` / `page.height`
(the page's own dimensions at the canonical `(margin, margin)`
origin), so the matrix-fit calc is correct even before the
relayout fires.

### H6. `_goToPage` flow

In single-page mode, page navigation is:
1. `_setCurrentPageNumber(target, doSetState: true)` — commit the
   new page number first so the next relayout uses it.
2. `_relayoutPages()` — sync, so the new `documentSize` reflects
   the target page before the matrix is computed.
3. `_calcCoverFitScale()` — recompute min-zoom for the new layout.
4. `_goTo(matrix, duration: Duration.zero)` — snap instantly.

No animation between pages. The multi-page mode keeps its original
200 ms animated transition.

### H7. Page-number eviction distance

The geometric distance metric (`pageRect.center` to
`currentPage.pageRect.center`) is degenerate in single-page mode
because every page's rect shares the same origin. New helper
`_evictionDistanceFor(currentPage)` returns a page-number-distance
closure when `singlePageMode` is on, geometric otherwise. Used by
BOTH eviction paths (byte-budget + count-cap).

### H8. `_guessCurrentPageNumber` short-circuit

Returns `_pageNumber ?? _gotoTargetPageNumber ?? widget.initialPageNumber`
directly in single-page mode — no point running the
visibility-weighted scan against a single non-zero rect.

### H9+H10. Host-app wire-up

- **argus viewer**: removed `layoutPages: _singlePageLayout`,
  removed `boundaryMargin: EdgeInsets.all(2000)`, added
  `singlePageMode: true`. The dead `_singlePageLayout` function at
  the top of the file is marked `// ignore: unused_element` and
  deprecated for deletion next cleanup.
- **argus_editor**: added `singlePageMode: true`. Cache count cap
  dropped from 15 → 5 (no multi-page scroll = much smaller working
  set), byte budget 128 → 64 MB, `verticalCacheExtent: 1.0 → 0.0`
  (no extent to extend — single page is the whole viewport).

## Phase I patch (2026-05-14) — the actual bottleneck

After Phase H landed, the user reported a 170 MB / 220-page PDF still
hung for **minutes** on the editor's "PDF içeriği çözülüyor…" banner
before any page appeared, with RAM stuck around 275 MB. The Phase A-H
patches were targeting **render-time** performance; the actual blocker
was much earlier in the pipeline: **PDF document parse**.

### I1. Replace per-byte chunk copy in `_openData` with `Uint8List.setRange`

**File**: `packages/pdfrx_engine/lib/src/native/pdfrx_pdfium.dart`,
`_openData` (around line 289-316).

**Symptom**: editor banner stays on screen for minutes on 100 MB+ PDFs.
UI thread frozen — opening the .aidf is observably synchronous
even though everything looks async on paper.

**Root cause**: the `read` callback fed to `openCustom` / PDFium was

```dart
read: (buffer, position, size) {
  ...
  for (var i = 0; i < size; i++) {
    buffer[i] = data[position + i];
  }
  return size;
},
```

PDFium asks for the file in chunks as it parses the cross-reference
table, page tree, and the initial page's content. For a 170 MB PDF
this is many MB of total reads, every byte going through a Dart-VM
indexed assignment on a `Uint8List` view of native memory. The VM
can't peephole-optimise this into a memcpy because the source and
destination are different objects with no aliasing guarantees, so
every iteration pays for bounds checks + VM dispatch. **Effective
throughput on smart-board hardware: ~5-10 MB/s.** A few minutes for
the parse to finish.

**Fix** (Phase I1):

```dart
read: (buffer, position, size) {
  ...
  buffer.setRange(0, size, data, position);
  return size;
},
```

`Uint8List.setRange` is implemented as a native intrinsic and runs at
memcpy speed (multiple GB/s). Identical semantics to the old loop;
single-line change.

**Why this wasn't caught before:** the fork patches up to Phase H
optimised the render pipeline (count cap, sparse layout, disk
cache, single-page mode, etc.) — they all assume the document is
already loaded. The Phase I diagnostic was driven by the user
saying "the banner shows for minutes": that pointed at
document-open, not page-render. Both `_openData` paths
(cached-in-memory when `fileSize ≤ maxSizeToCacheOnMemory`, default
1 MB, AND the on-demand path via `PdfiumFileAccess` for larger files)
share the same `read` callback, so the single patch fixes both.

**Expected impact on the user's 170 MB / 220-page PDF**: the banner
should now dismiss within ~1-2 seconds (xref + page tree parse +
page 1 metadata load) rather than several minutes. The fix is
orthogonal to all earlier patches — Phase A-H stand as well.

## Phase K patch (2026-05-14) — F1 cancels F2's renders mid-flight

After Phase H+I landed and the user re-tested, **only the first page
rendered** on a fresh document. Navigating to pages 2, 3, 4… showed the
white fallback rect, never the actual content; returning to page 1 still
showed it (cached from the initial paint).

### K1. Preserve F2's prefetch zone from F1's off-screen cancellation

**File**: `pdf_viewer.dart::_paintPagesCustom` — the two snapshot-walks
right before the visible-page loop.

**Symptom**: even when the user sat on a new page for several seconds,
no render arrived. The PDFium worker thread was idle — render requests
were being queued AND then cancelled in the same paint frame.

**Root cause**: F2 (Phase F2 neighbour prefetch) fires
`_cachePagePreviewImage` for pages `N±1` / `N±2` from inside
`_setCurrentPageNumber` whenever the current page changes. That function
synchronously registers a cancellation token in
`_PdfPageImageCache.cancellationTokens[pageNumber]` BEFORE its
synchronized block awaits PDFium.

The next paint frame (triggered by the same nav's `_invalidate`) then
runs F1's off-screen sweep, which walks `cancellationTokens.keys` and
cancels every page outside the visible range. In single-page mode the
visible range is `(N-1, N)` — exactly one page — so pages `N±1` / `N±2`
fall outside it. F1 cancels exactly the renders F2 just queued. The
synchronized block then bails at its `cancellationToken.isCanceled`
check, never producing an image.

End result: only the visible page (which itself queued its own token in
the visible loop AFTER the off-screen sweep, so it survived) ever
rendered. Every other page stayed in the white-fallback path forever.

**Fix**: introduce a `prefetchPreserveRadius` (= 2 in single-page mode,
0 in multi-page mode) and skip BOTH off-screen walks for pages within
that radius of the current page. The cached-page walk's skip means
already-rendered neighbours aren't marked for byte-budget eviction; the
cancellation walk's skip means F2's pending renders are allowed to
complete. Pages beyond ±2 still get cancelled and become
eviction-eligible — memory stays bounded.

```dart
final int prefetchPreserveRadius = widget.params.singlePageMode ? 2 : 0;
bool _isInPrefetchZone(int pageNumber) =>
    prefetchPreserveRadius > 0 &&
    (pageNumber - currentPageNumberForPreserve).abs() <= prefetchPreserveRadius;

// ...both walks now have:
if (_isInPrefetchZone(pageNumber)) continue;
```

**Why this wasn't caught in Phase F2**: F2 was wired up at the same
time as the Phase F1 off-screen sweep, but the cancellation
short-circuit only became load-bearing once Phase H (single-page mode)
shrank the visible range to a single index. In multi-page mode F2's
neighbours were always inside the cache extent and the sweep didn't
fire on them.

**Expected impact**: navigating with the nav buttons now hits a warm
in-memory cache for pages `N±1`/`N±2` (the F2 prefetched ones) and a
warm on-disk cache for anything beyond that (E4 wrote each render to
disk). Pages should appear within a few hundred ms even on first
visit, and instantly on revisit.

## Phase L patches (2026-05-14) — disk-cache hang fix

After K1 landed the user re-tested and **still saw pages 2+ stay
blank for a minute or more**, even though K1 was supposed to stop F1
from cancelling F2's renders. Investigation pointed at a completely
different bug: pdfrx's `_cachePagePreviewImage` was getting stuck on
the `await renderCache.tryGet(...)` line — not on cancellation, but
on the disk cache call itself hanging.

### Why `flutter_cache_manager` was hanging on Windows

The host apps' `ArgusPageCacheManager` / `ArgusEditorPageCacheManager`
were built on `flutter_cache_manager 3.4.1`, which uses `sqflite` for
its on-disk index. On Windows desktop `sqflite` REQUIRES the host app
to register `sqflite_common_ffi` (via
`databaseFactory = databaseFactoryFfi`) BEFORE the first query —
neither editor nor viewer was doing that. The result is that the very
first lazy DB open inside `getFileFromCache` blocks indefinitely
(or, depending on sqflite version, throws an `UnimplementedError`
that we silently swallow but only after a long wait).

Page 1 still rendered because its `tryGet` returned null fast (empty
cache, fast-path miss) — but the subsequent unawaited `put` write
opened the DB, the DB call hung, and from that point on every other
page's `tryGet` was queued behind a wedged sqflite. Hence: page 1 OK,
every later page silently stuck on the disk-cache lookup.

### L1. Hard timeouts around disk-cache calls

**File**: `pdf_viewer.dart::_cachePagePreviewImage` and
`_persistRenderToDiskCache`.

- `renderCache.tryGet(...)` is now wrapped in
  `.timeout(const Duration(milliseconds: 500), onTimeout: () => null)`.
  A slow lookup is treated as a cache miss and the render falls
  through to PDFium.
- The PNG encode and `renderCache.put(...)` calls are each wrapped in
  5 s timeouts so a wedged cache layer can't strand the
  background-worker shutdown either.

This is a belt-and-suspenders safeguard — even if the disk cache
implementation later regresses, rendering can no longer hang on it.

### L2. Replace `flutter_cache_manager` with a plain file-based cache

**Files**: `argus/lib/src/platform/page_cache_manager.dart` and
`argus_editor/lib/src/platform/page_cache_manager.dart` — both
rewritten as plain `dart:io` + `path_provider` implementations.

Shape:
- Cache lives at `<application-support>/argus_page_cache_v1/` (and
  `..._editor_..._v1/` for the editor — distinct dirs so two apps on
  the same machine don't collide).
- One file per cached entry, named `<sha256(key, first 16 hex)>.png`.
- `tryGet` = `File.exists` + `readAsBytes`.
- `put` = `writeAsBytes` to a sibling `.tmp` + rename (atomic).
- All ops wrapped in try/catch; never throws to the caller.

No SQL, no native plugins, no Windows-specific setup dance. Works
identically on Windows, macOS, Linux, and (ARM Linux for the
Raspberry Pi target). The
`flutter_cache_manager` package is still in `pubspec.yaml`
(transitively — schedule for next cleanup) but no longer touched
by the page-cache path.

Why this is fine to roll our own: the cache shape we need is
**embarrassingly simple**. flutter_cache_manager's value-add is
network downloads with HTTP cache-control headers, which we don't
use; everything else we need (path resolution, byte read/write) is
in dart:io + path_provider already.

**Expected impact**: with L1+L2, navigating to page 2+ should produce
a render within ~200-500 ms (PDFium native render time on smart-board)
plus ~50 ms for the K1-preserved F2 prefetch hits on warm pages. The
disk cache now functions as the cross-session optimisation it was
always meant to be, without being able to wedge the render pipeline.

## Deferred patches (still worth doing if testing reveals need)

### F3. Eviction policy refinement

Add an `isProtected` predicate to
`removeCacheImagesIfPageCountExceedsLimit` so pages whose layout
rect overlaps the current cache-extent rect are skipped by the
count cap. Today the cap is strict — a 15-page cap with 15 visible
pages still evicts on the next page change. In practice F2's
prefetch + the disk cache + the editor's 15-page cap keep things
smooth, but this would shave the worst-case "page evict → disk
load → paint" sequence on aggressive scroll.

## Memory accounting

Default upstream config (PdfViewerParams() with no overrides):

| Item | Bytes/page (Letter) | At 1000 pages |
|------|---------------------|---------------|
| Preview image | ~15 MB (1700 × 2200 × 4) | bounded by 100 MB byte budget |
| Real-size partial | viewport-clipped (~5-15 MB) | bounded by same budget |
| `PdfPage` metadata Dart object | < 1 KB | < 1 MB total |
| PDFium native page handle | closed after render | 0 long-lived |
| `PdfPageLayout.pageLayouts` `Rect[]` | 48 B | 48 KB |
| Cumulative y-offset table (C1) | 8 B | 8 KB |

Smart-board target config:

| Item | Bytes/page | At 1000 pages |
|------|------------|---------------|
| Preview image | ~2 MB (612 × 792 × 4 at 72 DPI) | 5 × 2 MB = 10 MB (capped) |
| Real-size partial | viewport-clipped, ~2-4 MB | 5 × 4 MB = 20 MB (capped) |
| Other | unchanged | unchanged |

Total in-RAM PDF render cost on smart-board: < 40 MB regardless of
document length, vs. up to ~100 MB on upstream config + unbounded
transient peaks during fast scrolls.

## Testing checklist

Before declaring a patch complete, verify on representative PDFs:

- [ ] 300-page question-bank PDF — cold open < 2 s, page nav < 200 ms,
      steady-state RAM growth < 5 MB after 5 min idle.
- [ ] 500-page school textbook — cold open < 4 s, page nav < 300 ms,
      no white-flash on fast scroll-thumb drag.
- [ ] 1000-page reference manual — cold open < 6 s, page nav < 400 ms,
      RAM < 250 MB peak even during scroll-thumb stress test.
- [ ] Cropped region revisit (aidf magnifier) — second open < 100 ms
      after flutter_cache_manager integration (Phase D2).

All thresholds are for the smart-board reference device; modern desktop
should be much faster.


---

## Phase Z (2026-08-20) — "ilk sayfa bulanik" : AYNI render istegi iptal ediliyordu

Saha raporu (ARGUS viewer): *"acilan ilk sayfada bulaniklik var; sonraki
sayfalarda yok. Ms farkiyla sonradan netlestigini gorebiliyorum."*

### Neden bulanik gorunuyor

Ekrandaki olcek `zoom * devicePixelRatio`; onizleme ise
`onePassRenderingScaleThreshold` ile sinirli (ARGUS'ta 2.0) ve
`onePassRenderingSizeThreshold` (1600 px) ile kirpiliyor. Yuksek DPI'li bir
tahtada `zoom * dpr` bu tavani asar → onizleme BUYUTULEREK cizilir. Netligi
getiren sey `_requestRealSizePartialImage` ("gercek boyut" gecisi).

### Kusur

`_requestRealSizePartialImage` bekleyen istegi **kimligine bakmadan** iptal
ediyordu:

```dart
cache.pageImagePartialRenderingRequests[page.pageNumber]?.cancel();
```

`_paintPagesCustom` HER boyamada calisir. ARGUS viewer sik boyanir (murekkep
tikleri, saglayici guncellemeleri, acilistaki fit-tekrar dongusu 50/250/600 ms,
odak animasyonlari). Her boyama, ZATEN AYNI (rect, scale) icin ucusta olan
render'i olduruyor ve bastan basliyordu → netlesme, boyama patlamasi bittigi
ana kadar ACLIGA giriyordu. Acilista o patlama en uzundur; ILK sayfanin
bulanik olmasinin sebebi tam olarak budur.

### Olcum (`tool/argus_render_kuyrugu_olcum.dart`, 370 sayfalik sentetik PDF)

```
A) isci BOS                        : 3, 2, 2 ms
B) 30 is KUYRUKTA                  : 39 ms      -> 16,7x
C) kuyruk bosalinca                : 3 ms

D) 30 karelik boyamada IPTALLI     : 590 ms     (upstream davranisi)
D) iptalsiz (duzeltilmis kural)    : 3 ms
   bosuna giden netlesme suresi    : 587 ms
```

PDFium iscisi TEK is parcacigi: her yeniden baslatma, render'i o sirada
kuyrukta ne varsa onun ARKASINA atar. Sentetik sayfa 3 ms'de rendera oluyor;
gercek soru bankasi sayfasi 200-500 ms → ayni desende kayip saniyelere cikar.

### Duzeltme

`_PdfPartialImageRenderingRequest` artik hangi `(rect, scale)` icin
istendigini saklar; istek AYNIYSA iptal edilmez, birakilir tamamlansin.
Degistiyse (kullanici zoom/pan yapti) iptal DOGRU davranistir — o render'in
ciktisi bayattir.

⚠ Bekleyen kayit, istek tamamlaninca VE iptal edilmis olarak bulununca
dusuruluyor; asili kalsaydi kapi sonsuza dek kapanir ve sayfa HIC
netlesmezdi (duzeltilenden daha kotu bir ariza).

### Olcumu tekrarlamak

```bash
# 370 sayfalik PDF uretmek icin herhangi bir arac; sonra:
dart pub get           # tool/olcum_pubspec.yaml.ornek'i kopyalayarak
PATH=<pdfium.dll dizini>:$PATH dart run tool/argus_render_kuyrugu_olcum.dart <pdf>
```
