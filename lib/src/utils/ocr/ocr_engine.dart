import 'dart:typed_data';
import 'dart:ui';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// One recognised line of text within an [OcrBlock].
class OcrLine {
  /// Initialise a line.
  OcrLine({
    required this.text,
    required this.rect,
  });

  /// The recognised text of the line.
  final String text;

  /// Bounding box of the line in image coordinates.
  final Rect rect;
}

/// One block of recognised text — roughly a paragraph or text box.
class OcrBlock {
  /// Initialise a block.
  OcrBlock({
    required this.text,
    required this.rect,
    required this.lines,
  });

  /// The recognised text of the whole block.
  final String text;

  /// Bounding box of the block in image coordinates.
  final Rect rect;

  /// The lines making up the block.
  final List<OcrLine> lines;

  /// Heuristic for vertically-set (tategaki) text: a column is much
  /// taller than wide. Used for reading-order sorting and for the
  /// `writing-mode` styling of generated overlays.
  bool get isVertical => rect.height > rect.width * 1.5;
}

/// The result of recognising one image.
class OcrResult {
  /// Initialise a result.
  OcrResult({
    required this.text,
    required this.blocks,
  });

  /// All recognised text, blocks joined by newlines. Empty if nothing
  /// was recognised.
  final String text;

  /// The recognised blocks with geometry.
  final List<OcrBlock> blocks;
}

/// The pluggable OCR seam. All in-app OCR (subtitle bitmaps, scanned PDF
/// pages, the home-menu smoke test) goes through this interface so the
/// backing engine can be swapped — ML Kit today, potentially MangaOCR
/// (on-device ONNX or a desktop pipeline) later, without touching the
/// pipelines that consume it.
abstract class OcrEngine {
  /// Recognise text in an image file on disk (any format the engine's
  /// platform decoder accepts — JPEG/PNG/WebP/BMP).
  Future<OcrResult> recognizeFile(String path);

  /// Recognise text in a raw RGBA bitmap (the `ui.Image.toByteData
  /// (rawRgba)` layout: width * height * 4 bytes). Used by the subtitle
  /// pipeline, whose decoded PGS/VobSub bitmaps never touch disk.
  Future<OcrResult> recognizeBitmap({
    required Uint8List rgba,
    required int width,
    required int height,
  });

  /// Release engine resources. The engine must not be used afterwards.
  Future<void> dispose();
}

/// [OcrEngine] backed by Google ML Kit text recognition v2 with the
/// bundled Japanese model. One native recognizer is held open across the
/// engine's lifetime — batch users (subtitle OCR, PDF import) create one
/// engine, feed it every image, then [dispose].
class MlkitOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.japanese);

  @override
  Future<OcrResult> recognizeFile(String path) async {
    return _toResult(
      await _recognizer.processImage(InputImage.fromFilePath(path)),
    );
  }

  @override
  Future<OcrResult> recognizeBitmap({
    required Uint8List rgba,
    required int width,
    required int height,
  }) async {
    return _toResult(
      await _recognizer.processImage(
        InputImage.fromBitmap(bitmap: rgba, width: width, height: height),
      ),
    );
  }

  @override
  Future<void> dispose() => _recognizer.close();

  OcrResult _toResult(RecognizedText recognized) {
    return OcrResult(
      text: recognized.text,
      blocks: recognized.blocks
          .map(
            (block) => OcrBlock(
              text: block.text,
              rect: block.boundingBox,
              lines: block.lines
                  .map(
                    (line) => OcrLine(
                      text: line.text,
                      rect: line.boundingBox,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}
