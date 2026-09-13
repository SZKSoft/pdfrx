// ARGUS pdfrx fork addition (2026-05-14, Phase E3).
//
// Cross-session disk-backed cache for rendered page bitmaps. Sits in
// front of PDFium's render path so a page the viewer has shown before
// (in this session or a previous one) can be decoded from PNG bytes
// instead of going through `FPDF_RenderPageBitmap`. On smart-board
// hardware that swap is the difference between a ~50 ms PNG decode and
// a 200-500 ms native render — the user-visible "blank page when
// scrolling back" symptom that hit our 170 MB / 270-page stress PDF
// even after the in-memory eviction patch (A1) landed.
//
// The interface is intentionally thin: the host app provides one
// implementation, pdfrx calls it from the render pipeline. Cache key
// generation, on-disk format, and eviction policy are all the host
// app's responsibility — pdfrx doesn't impose a directory layout.

import 'dart:typed_data';

import 'package:pdfrx_engine/pdfrx_engine.dart';

/// Host-app-supplied disk cache for full-page render PNGs.
///
/// Implementations are expected to be **thread-safe** (multiple
/// concurrent renders may race against the same key) and **idempotent**
/// on writes (the same page may be put more than once with identical
/// bytes when re-renders fire). pdfrx never awaits `put` in a
/// load-bearing path; failures should be silent.
///
/// Cache key generation is the implementation's responsibility. It
/// should incorporate at minimum:
/// - A stable identifier for the source PDF (NOT [PdfDocument.sourceName]
///   if the host app uses per-mount unique names — prefer a content
///   hash like SHA-256 of the underlying bytes).
/// - The page number (1-based).
/// - The render scale, rounded to enough precision to discriminate
///   meaningful resolution buckets without exploding the keyspace.
///
/// Reads should be cheap; pdfrx may call [tryGet] from inside the paint
/// loop's `Future` chain. Writes can be expensive (PNG encoding +
/// disk I/O); pdfrx fires them with `unawaited` so they run in the
/// background.
abstract class PdfPageRenderCache {
  const PdfPageRenderCache();

  /// Returns the cached PNG bytes for the given (document, page,
  /// scale) tuple, or `null` if no entry exists / the entry is
  /// unreadable / the implementation chooses not to serve it. pdfrx
  /// treats null as a cache miss and falls through to a fresh PDFium
  /// render.
  Future<Uint8List?> tryGet({
    required PdfDocument document,
    required PdfPage page,
    required double scale,
  });

  /// Stores the freshly-rendered PNG bytes. pdfrx calls this once per
  /// successful preview render (the low-res first pass), not for the
  /// real-size partial passes — those are viewport-clipped and
  /// re-derivable. Implementations are free to drop the call (e.g. if
  /// disk is full) without telling pdfrx; the in-memory tile cache
  /// keeps working either way.
  Future<void> put({
    required PdfDocument document,
    required PdfPage page,
    required double scale,
    required Uint8List pngBytes,
  });
}
