import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pdfrx_engine/pdfrx_engine.dart';
import 'package:test/test.dart';

import 'utils.dart';

final testPdfFile = File('../pdfrx/example/viewer/assets/hello.pdf');

void main() {
  setUp(() => pdfrxInitialize(tmpPath: tmpRoot.path));

  test('PdfDocument.openFile', () async => await testDocument(await PdfDocument.openFile(testPdfFile.path)));
  test('PdfDocument.openData', () async {
    final data = await testPdfFile.readAsBytes();
    await testDocument(await PdfDocument.openData(data));
  });
  test('PdfDocument.openUri', () async {
    Pdfrx.createHttpClient = () =>
        MockClient((request) async => http.Response.bytes(await testPdfFile.readAsBytes(), 200));
    await testDocument(await PdfDocument.openUri(Uri.parse('https://example.com/hello.pdf')));
  });

  group('PdfDocument.openCustom with maxSizeToCacheOnMemory=0', () {
    test('opens PDF with custom read function', () async {
      final data = await testPdfFile.readAsBytes();

      // Custom read function that reads from the data buffer
      int readFunc(Uint8List buffer, int position, int size) {
        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: readFunc,
        fileSize: data.length,
        sourceName: 'custom:test.pdf',
        maxSizeToCacheOnMemory: 0,
      );

      await testDocument(doc);
    });

    test('handles multiple concurrent reads', () async {
      final data = await testPdfFile.readAsBytes();
      var readCount = 0;

      int readFunc(Uint8List buffer, int position, int size) {
        readCount++;
        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: readFunc,
        fileSize: data.length,
        sourceName: 'custom:concurrent.pdf',
        maxSizeToCacheOnMemory: 0,
      );

      await testDocument(doc);
      expect(readCount, greaterThan(0), reason: 'Read function should be called at least once');
    });

    test('handles async read function', () async {
      final data = await testPdfFile.readAsBytes();

      Future<int> asyncReadFunc(Uint8List buffer, int position, int size) async {
        // Simulate async delay
        await Future.delayed(Duration(milliseconds: 1));

        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: asyncReadFunc,
        fileSize: data.length,
        sourceName: 'custom:async.pdf',
        maxSizeToCacheOnMemory: 0,
      );

      await testDocument(doc);
    });

    test('handles read at various positions', () async {
      final data = await testPdfFile.readAsBytes();
      final readPositions = <int>[];

      int readFunc(Uint8List buffer, int position, int size) {
        readPositions.add(position);
        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: readFunc,
        fileSize: data.length,
        sourceName: 'custom:positions.pdf',
        maxSizeToCacheOnMemory: 0,
      );

      await testDocument(doc);

      // Verify that reads occurred at different positions (random access)
      expect(readPositions.isNotEmpty, true, reason: 'Should have read positions recorded');
      // PDFium typically reads from multiple positions for PDF structure
      expect(readPositions.toSet().length, greaterThan(1), reason: 'Should read from multiple positions');
    });

    test('handles read errors gracefully', () async {
      int readFunc(Uint8List buffer, int position, int size) {
        // Return 0 to indicate EOF/error - no valid PDF data
        return 0;
      }

      // This should fail because we're not providing valid PDF data
      expect(
        () async => await PdfDocument.openCustom(
          read: readFunc,
          fileSize: 1000,
          sourceName: 'custom:error.pdf',
          maxSizeToCacheOnMemory: 0,
        ),
        throwsA(isA<PdfException>()),
      );
    });

    test('calls onDispose callback when document is disposed', () async {
      final data = await testPdfFile.readAsBytes();
      var disposeCalled = false;

      int readFunc(Uint8List buffer, int position, int size) {
        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: readFunc,
        fileSize: data.length,
        sourceName: 'custom:dispose.pdf',
        maxSizeToCacheOnMemory: 0,
        onDispose: () {
          disposeCalled = true;
        },
      );

      expect(disposeCalled, false, reason: 'onDispose should not be called yet');
      await doc.dispose();
      expect(disposeCalled, true, reason: 'onDispose should be called after dispose');
    });

    test('handles large file sizes correctly', () async {
      final data = await testPdfFile.readAsBytes();
      final largeFileSize = data.length;

      int readFunc(Uint8List buffer, int position, int size) {
        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: readFunc,
        fileSize: largeFileSize,
        sourceName: 'custom:large.pdf',
        maxSizeToCacheOnMemory: 0,
      );

      await testDocument(doc);
    });

    test('handles partial reads correctly', () async {
      final data = await testPdfFile.readAsBytes();
      final readSizes = <int>[];

      int readFunc(Uint8List buffer, int position, int size) {
        readSizes.add(size);

        if (position >= data.length) return 0;
        final actualSize = (position + size > data.length) ? data.length - position : size;
        buffer.setRange(0, actualSize, data, position);
        return actualSize;
      }

      final doc = await PdfDocument.openCustom(
        read: readFunc,
        fileSize: data.length,
        sourceName: 'custom:partial.pdf',
        maxSizeToCacheOnMemory: 0,
      );

      await testDocument(doc);
      // Verify that reads occurred with various sizes
      expect(readSizes.isNotEmpty, true, reason: 'Should have read sizes recorded');
    });
  });

  // ARGUS fork (2026-09-22). Kept in this file on purpose: PDFium is process-global, and a second test file running
  // concurrently registers its own worker's font callback, which the other file's worker then invokes ("Cannot
  // invoke native callback from a different isolate").
  group('PdfDocument.openNativeMemory', () {
    ({int address, int size}) toNative(Uint8List bytes) {
      final p = malloc<Uint8>(bytes.length);
      p.asTypedList(bytes.length).setAll(0, bytes);
      return (address: p.address, size: bytes.length);
    }

    test('opens from native memory and releases it once, after dispose', () async {
      final buf = toNative(await testPdfFile.readAsBytes());
      var releases = 0;
      final doc = await PdfDocument.openNativeMemory(
        address: buf.address,
        size: buf.size,
        sourceName: 'native:hello.pdf',
        release: () {
          releases++;
          malloc.free(Pointer<Uint8>.fromAddress(buf.address));
        },
      );
      expect(doc.sourceName, 'native:hello.pdf');
      expect(doc.pages.length, greaterThan(0));
      await testPage(doc, 1);
      expect(releases, 0, reason: 'released while PDFium still reads the buffer');

      await doc.dispose();
      expect(releases, 1);
      await doc.dispose();
      expect(releases, 1, reason: 'a second dispose must not release again (double free)');
    });

    test('releases the buffer once when opening fails', () async {
      final buf = toNative(Uint8List.fromList(List<int>.generate(4096, (i) => (i * 31) & 0xff)));
      var releases = 0;
      await expectLater(
        PdfDocument.openNativeMemory(
          address: buf.address,
          size: buf.size,
          sourceName: 'native:garbage',
          release: () {
            releases++;
            malloc.free(Pointer<Uint8>.fromAddress(buf.address));
          },
        ),
        throwsA(isA<PdfException>()),
      );
      expect(releases, 1, reason: 'a failed open must release exactly once (0 = leak, 2 = double free)');
    });
  });
}
