// ARGUS — pdfrx render kuyrugu olcumu.
//
// SORU: "gercek boyut" render'i, ISCI MESGULKEN ne kadar gecikiyor?
// PDFium isci TEK is parcacigi; acilista sayfa-metadata taramasi +
// onizleme render'lari ayni kuyrukta.
import 'dart:io';

import 'package:pdfrx_engine/pdfrx_engine.dart';

Future<int> _renderMs(PdfDocument doc, int pageNo, double scale) async {
  final PdfPage p = doc.pages[pageNo - 1];
  final sw = Stopwatch()..start();
  try {
    final PdfImage? img = await p.render(
      fullWidth: p.width * scale,
      fullHeight: p.height * scale,
      backgroundColor: 0xFFFFFFFF,
    );
    sw.stop();
    if (img == null) {
      stdout.writeln('  ! sayfa $pageNo render null (isLoaded=${p.isLoaded})');
      return -1;
    }
    img.dispose();
  } catch (e) {
    sw.stop();
    stdout.writeln('  ! sayfa $pageNo HATA: $e');
    return -1;
  }
  return sw.elapsedMilliseconds;
}

Future<void> main(List<String> args) async {
  try {
    // Yerel pdfium (Qt derlemesinden) — indirmeye gerek yok.
    Pdfrx.pdfiumModulePath = args.length > 1 ? args[1] : null;
    await pdfrxInitialize();
    stdout.writeln('pdfium hazir: ${Pdfrx.pdfiumModulePath}');
    final doc = await PdfDocument.openFile(args.first);
    stdout.writeln('sayfa sayisi: ${doc.pages.length}');

    // ── A) ISCI BOS ────────────────────────────────────────────────────
    await _renderMs(doc, 40, 2.0); // isinma
    final a1 = await _renderMs(doc, 41, 2.0);
    final a2 = await _renderMs(doc, 42, 2.0);
    final a3 = await _renderMs(doc, 43, 2.0);

    // ── B) ISCI MESGUL: 30 render kuyruga atilir, BEKLENMEZ ───────────
    //    (acilistaki 30 sayfalik metadata taramasinin karsiligi)
    final yukler = <Future<int>>[];
    for (int i = 1; i <= 30; i++) {
      yukler.add(_renderMs(doc, i, 1.0));
    }
    final b1 = await _renderMs(doc, 44, 2.0); // viewer'in ILK sayfa render'i
    await Future.wait(yukler);
    final c1 = await _renderMs(doc, 45, 2.0); // kuyruk bosaldiktan sonra

    stdout.writeln('');
    stdout.writeln('--- render gecikmesi (ms) ---');
    stdout.writeln('A) isci BOS        : $a1, $a2, $a3');
    stdout.writeln('B) 30 is KUYRUKTA  : $b1');
    stdout.writeln('C) kuyruk bosalinca: $c1');
    final double taban = (a1 + a2 + a3) / 3.0;
    stdout.writeln('taban ortalama     : ${taban.toStringAsFixed(0)} ms');
    stdout.writeln('MESGUL / BOS       : ${(b1 / taban).toStringAsFixed(1)}x');

    // ── D) AYNI istegin her boyamada IPTAL edilip yeniden baslatilmasi ──
    //    (upstream pdfrx davranisi: _requestRealSizePartialImage bekleyen
    //     istegin KIMLIGINE bakmadan cancel() cagiriyordu)
    Future<int> iptalli(int pageNo, int boyamaSayisi, int araMs) async {
      final p = doc.pages[pageNo - 1];
      final sw = Stopwatch()..start();
      PdfPageRenderCancellationToken? tok;
      Future<PdfImage?>? istek;
      for (int i = 0; i < boyamaSayisi; i++) {
        tok?.cancel(); // her boyamada iptal — istek AYNI olsa bile
        tok = p.createCancellationToken();
        istek = p.render(
          fullWidth: p.width * 2.0,
          fullHeight: p.height * 2.0,
          backgroundColor: 0xFFFFFFFF,
          cancellationToken: tok,
        );
        await Future<void>.delayed(Duration(milliseconds: araMs));
      }
      final img = await istek;
      sw.stop();
      img?.dispose();
      return sw.elapsedMilliseconds;
    }

    // Acilistaki boyama patlamasi: ~30 kare, 16 ms araligla (~480 ms).
    final d1 = await iptalli(50, 30, 16);
    // Duzeltilmis kural: ayni istek iptal EDILMEZ -> ilk render tamamlanir.
    final sw2 = Stopwatch()..start();
    await _renderMs(doc, 51, 2.0);
    sw2.stop();
    final d2 = sw2.elapsedMilliseconds;

    stdout.writeln('');
    stdout.writeln('--- ayni istegin iptal-yeniden baslat maliyeti ---');
    stdout.writeln('D) 30 boyamada IPTALLI (upstream): $d1 ms');
    stdout.writeln('D) iptalsiz (duzeltilmis kural)  : $d2 ms');
    stdout.writeln('netlesme gecikmesi               : ${d1 - d2} ms bosuna');
    await doc.dispose();
  } catch (e, s) {
    stdout.writeln('OLCUM HATASI: $e');
    stdout.writeln(s.toString().split('\n').take(4).join('\n'));
  }
  exit(0);
}
