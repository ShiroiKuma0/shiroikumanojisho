import 'dart:io';

import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/src/utils/misc/app_export_import.dart';
import 'package:shiroikumanojisho/src/utils/misc/mokuro_payload.dart';
import 'package:shiroikumanojisho/src/utils/ocr/mokuro_html_generator.dart';
import 'package:shiroikumanojisho/src/utils/ocr/ocr_engine.dart';

/// Imports a scanned (image-only) PDF as a mokuro-style volume: each
/// page is rasterised via the native [PdfRendererBridge] channel,
/// OCR'd through the [OcrEngine] seam, and emitted as a legacy-mokuro
/// HTML file plus a directory of page JPEGs, which the existing mokuro
/// browse page then displays with tappable text.
class PdfOcrImporter {
  static const MethodChannel _channel = MethodChannel('shiroikuma.jisho/pdf');

  /// Rasterisation width cap in pixels: high enough for OCR on dense
  /// print, low enough to keep a 300-page book within tens of MB.
  static const int _maxPageWidth = 2000;

  /// JPEG quality for stored page images.
  static const int _jpegQuality = 85;

  /// Rasterise and OCR [pdfFile], generate the mokuro volume on disk,
  /// and return a ready [MediaItem] — or null on failure or if the
  /// PDF has no pages. Shows its own progress dialog; [context] must
  /// be able to show dialogs.
  static Future<MediaItem?> importPdf({
    required AppModel appModel,
    required BuildContext context,
    required File pdfFile,
    required MediaSource mediaSource,
  }) async {
    final navigator = Navigator.of(context);

    int pageCount;
    try {
      pageCount = await _channel.invokeMethod<int>(
            'open',
            {'path': pdfFile.path},
          ) ??
          0;
    } catch (e) {
      Fluttertoast.showToast(msg: 'Could not open PDF: $e');
      return null;
    }
    if (pageCount == 0) {
      await _channel.invokeMethod('close');
      Fluttertoast.showToast(msg: 'PDF has no pages.');
      return null;
    }

    final title = path.basenameWithoutExtension(pdfFile.path);
    // Static title; the per-page counter lives only in the body line.
    final titleNotifier =
        ValueNotifier<String>('Importing PDF - one-time OCR');
    final bodyNotifier = ValueNotifier<String>('Starting...');
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LongOpProgressDialog(
          titleNotifier: titleNotifier,
          bodyNotifier: bodyNotifier,
        ),
      );
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    // ASCII-only slug so the file:// media identifier needs no
    // percent-encoding; the human-readable name lives in the item title.
    final slug = 'pdf_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}';
    final bookDir = Directory('${appDocDir.path}/scannedPdf/$slug');
    final imgDir = Directory('${bookDir.path}/img');

    final OcrEngine engine = MlkitOcrEngine();
    try {
      imgDir.createSync(recursive: true);

      final images = <MokuroImage>[];
      for (var i = 0; i < pageCount; i++) {
        bodyNotifier.value = 'OCR running: page ${i + 1} of $pageCount...';

        final rendered = await _channel.invokeMethod<Map>(
          'renderPage',
          {'index': i, 'maxWidth': _maxPageWidth, 'quality': _jpegQuality},
        );
        final bytes = rendered!['bytes'] as Uint8List;
        final width = rendered['width'] as int;
        final height = rendered['height'] as int;

        final imageName = 'page_${i.toString().padLeft(4, '0')}.jpg';
        final imageFile = File('${imgDir.path}/$imageName');
        imageFile.writeAsBytesSync(bytes);

        final result = await engine.recognizeFile(imageFile.path);
        images.add(
          MokuroImage(
            url: 'img/$imageName',
            size: Size(width.toDouble(), height.toDouble()),
            blocks: _toMokuroBlocks(result),
          ),
        );
      }

      bodyNotifier.value = 'Generating volume...';
      final html = await MokuroHtmlGenerator.generate(
        payload: MokuroPayload(images: images),
        title: title,
      );
      File('${bookDir.path}/index.html').writeAsStringSync(html);

      return MediaItem(
        title: title,
        mediaIdentifier: 'file://${bookDir.path}/index.html',
        imageUrl: 'file://${imgDir.path}/page_0000.jpg',
        position: 0,
        duration: pageCount,
        mediaTypeIdentifier: mediaSource.mediaType.uniqueKey,
        mediaSourceIdentifier: mediaSource.uniqueKey,
        canDelete: true,
        canEdit: true,
      );
    } catch (e) {
      // Half-imported volumes are useless; reclaim the space.
      if (bookDir.existsSync()) {
        bookDir.deleteSync(recursive: true);
      }
      Fluttertoast.showToast(msg: 'PDF import failed: $e');
      return null;
    } finally {
      await engine.dispose();
      try {
        await _channel.invokeMethod('close');
      } catch (_) {}
      navigator.pop();
    }
  }

  /// Map an [OcrResult] to mokuro text boxes. The font size is derived
  /// from the block geometry so the invisible overlay text fills its
  /// box — for a horizontal block of N lines that is height/N shrunk by
  /// mokuro's 1.1em line height; for vertical (tategaki) columns, the
  /// same with width. This keeps taps landing on the right characters
  /// without needing a font size from the OCR engine.
  static List<MokuroBlock> _toMokuroBlocks(OcrResult result) {
    return result.blocks
        .where((block) => block.lines.isNotEmpty)
        .map((block) {
      final lineCount = block.lines.length;
      final extent =
          block.isVertical ? block.rect.width : block.rect.height;
      final fontSize = (extent / lineCount / 1.1).clamp(10.0, 96.0);

      return MokuroBlock(
        rectangle: block.rect,
        isVertical: block.isVertical,
        fontSize: fontSize,
        // Real z-indexes are recomputed by the generator from block
        // areas, matching mokuro's overlay_generator.
        zIndex: 0,
        lines: block.lines.map((line) => line.text).toList(),
        lineRects: block.lines.map((line) => line.rect).toList(),
      );
    }).toList();
  }
}
