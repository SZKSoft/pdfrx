import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_dart;
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

import 'utils.dart';

/// ARGUS fork: the module path must reach the worker BEFORE its first request.
///
/// Must stay the first thing in this file that touches the worker (each test file runs in its own isolate, so the
/// worker singleton is fresh here). The regression made the first request run with a null module path.
void main() {
  test('the first compute already sees Pdfrx.pdfiumModulePath', () async {
    final path = await pdfium_dart.PDFiumDownloader.downloadAndGetPDFiumModulePath(tmpRoot.path);
    Pdfrx.pdfiumModulePath = path;
    final seen = await PdfrxEntryFunctions.instance.compute((_) => Pdfrx.pdfiumModulePath, null);
    expect(seen, path);
  });
}
