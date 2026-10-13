import 'pdf_point.dart';
import 'pdf_rect.dart';

/// ARGUS fork (2026-10-13). Vector page objects returned by `PdfPage.loadObjects`:
/// PDFium path, text, image and shading objects.
///
/// Coordinates are in the same space as [PdfRect] from `PdfPage.loadText`: PDF points,
/// origin at the bottom-left of the page box. Form XObjects are flattened with their
/// matrices, so every object is already in page space.
class PdfPageObjects {
  const PdfPageObjects({
    required this.paths,
    required this.texts,
    required this.images,
    this.shadings = const <PdfRect>[],
  });

  /// Path (stroke / fill) objects in painting order.
  final List<PdfPathObject> paths;

  /// Text objects in painting order.
  final List<PdfTextObject> texts;

  /// Bounding boxes of raster image objects (their content is not vector).
  final List<PdfRect> images;

  /// Bounding boxes of shading objects (`sh` operator: gradient fills, often used for shaded
  /// bodies such as spheres or blocks). Kept separate from [images]: a shading is drawn by the
  /// renderer, not stored as pixels.
  final List<PdfRect> shadings;
}

/// Path segment type (PDFium `FPDF_SEGMENT_*`).
enum PdfPathSegmentType {
  /// Starts a new subpath.
  moveTo,

  /// Straight line from the previous point.
  lineTo,

  /// One point of a cubic Bezier: three consecutive segments (two control points and the end point).
  bezierTo,
}

/// A path object.
class PdfPathObject {
  const PdfPathObject({
    required this.segmentTypes,
    required this.points,
    required this.closes,
    required this.strokeColor,
    required this.fillColor,
    required this.fillMode,
    required this.strokeWidth,
    required this.dashArray,
    required this.dashPhase,
    required this.bounds,
    this.clipPaths,
  });

  /// Segment types; the point of segment i is ([points][2*i], [points][2*i+1]).
  final List<PdfPathSegmentType> segmentTypes;

  /// Segment points x0, y0, x1, y1, ... in page space.
  final List<double> points;

  /// Whether the subpath is closed after the segment.
  final List<bool> closes;

  /// Stroke color (ARGB), or null if the path is not stroked.
  final int? strokeColor;

  /// Fill color (ARGB), or null if the path is not filled.
  final int? fillColor;

  /// Fill rule (PDFium `FPDF_FILLMODE_*`): 0 none, 1 even-odd, 2 winding.
  final int fillMode;

  /// Stroke width in page points (object scale applied).
  final double strokeWidth;

  /// Dash pattern in page points, or null for a solid line.
  final List<double>? dashArray;

  /// Dash phase in page points.
  final double dashPhase;

  /// Bounding box of the points (stroke width not included, clipping not applied).
  final PdfRect bounds;

  /// Clip paths applied to the object (points x0, y0, x1, y1, ... in page space; Bezier control
  /// points included as plain points), or null if the object is not clipped. The visible part is
  /// the intersection of all clip paths.
  final List<List<double>>? clipPaths;

  /// Number of segments.
  int get segmentCount => segmentTypes.length;
}

/// A text object (one run with a single font and size).
class PdfTextObject {
  const PdfTextObject({
    required this.text,
    required this.fontSize,
    required this.origin,
    required this.fillColor,
    required this.bounds,
  });

  /// The text (empty if it cannot be extracted).
  final String text;

  /// Font size in page points (object scale applied).
  final double fontSize;

  /// Start of the baseline.
  final PdfPoint origin;

  /// Fill color (ARGB).
  final int fillColor;

  /// Bounding box.
  final PdfRect bounds;
}
