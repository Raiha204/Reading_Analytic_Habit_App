import 'dart:typed_data';

import 'package:pdfx/pdfx.dart';

class PdfThumbnailService {
  PdfThumbnailService._();

  static Future<Uint8List?> renderFirstPage(Uint8List bytes) async {
    PdfDocument? document;
    PdfPage? page;
    try {
      document = await PdfDocument.openData(bytes);
      page = await document.getPage(1);
      final image = await page.render(
        width: 240,
        height: 320,
        format: PdfPageImageFormat.png,
        quality: 80,
      );
      return image?.bytes;
    } catch (_) {
      return null;
    } finally {
      await page?.close();
      await document?.close();
    }
  }
}
