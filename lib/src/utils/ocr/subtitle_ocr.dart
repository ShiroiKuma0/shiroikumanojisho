import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:shiroikumanojisho/src/utils/ocr/ocr_engine.dart';
import 'package:shiroikumanojisho/src/utils/ocr/pgs_parser.dart';
import 'package:shiroikumanojisho/src/utils/ocr/vobsub_parser.dart';

/// An image-based subtitle track found in a video container.
class ImageSubtitleTrack {
  /// Initialise a track description.
  ImageSubtitleTrack({
    required this.subtitleOrdinal,
    required this.codec,
    this.language,
    this.title,
  });

  /// The N in an ffmpeg `0:s:N` mapping — the track's position among
  /// the container's subtitle streams, not its absolute stream index.
  final int subtitleOrdinal;

  /// ffprobe codec name: `hdmv_pgs_subtitle` (Blu-ray PGS) or
  /// `dvd_subtitle` (VobSub).
  final String codec;

  /// ISO language tag from the container, if any.
  final String? language;

  /// Track title from the container, if any.
  final String? title;

  /// Whether this is a PGS (Blu-ray) track, as opposed to VobSub (DVD).
  bool get isPgs => codec == 'hdmv_pgs_subtitle';

  /// The per-track sidecar suffix, e.g. `.ocr-s3-jpn.srt`. Keyed by
  /// the subtitle ordinal so multiple image tracks (or two tracks of
  /// the same language) each get their own OCR result; the language is
  /// included for human readability of the files.
  String get sidecarSuffix {
    final languagePart =
        (language != null && language!.isNotEmpty) ? '-$language' : '';
    return '.ocr-s$subtitleOrdinal$languagePart.srt';
  }

  /// Directory (under the app's `ocrSubtitles/bitmaps/`) holding this
  /// track's decoded event bitmaps for [videoPath]: one PNG per event
  /// plus `index.json` with per-event timings. The player overlays the
  /// matching PNG on the paused frame, so the playhead never needs to
  /// move to show the bitmap.
  String bitmapDirName(String videoPath) {
    final basename = path.basenameWithoutExtension(videoPath);
    final suffix = sidecarSuffix.replaceAll('.srt', '');
    return '$basename$suffix';
  }

  /// A human-readable label for track pickers.
  String get label {
    final parts = <String>[
      if (title != null && title!.isNotEmpty) title!,
      if (language != null && language!.isNotEmpty) language!,
      isPgs ? 'PGS' : 'VobSub (not yet supported)',
    ];
    return parts.join(' · ');
  }
}

/// Converts image-based subtitle tracks (Blu-ray PGS and DVD VobSub)
/// to SRT via OCR: ffmpeg demuxes the track with a stream copy,
/// [PgsParser] or [VobsubParser] decodes per-event bitmaps, the
/// [OcrEngine] recognises each, and the result is written as a
/// `<video-basename>.ocr.srt` sidecar so the player's existing sidecar
/// scan auto-loads it on every later open.
class SubtitleOcr {
  /// The subtitle codec names seen by the most recent
  /// [detectImageTracks] probe — diagnostic surface for the "no image
  /// tracks found" toast.
  static List<String> lastProbedSubtitleCodecs = [];

  /// Enumerate image-based subtitle tracks in [videoPath] using
  /// ffprobe. Returns an empty list when there are none (or probing
  /// fails — image tracks in that case cannot be extracted either).
  static Future<List<ImageSubtitleTrack>> detectImageTracks(
    String videoPath,
  ) async {
    lastProbedSubtitleCodecs = [];
    try {
      final probeSession = await FFprobeKit.getMediaInformation(videoPath);
      final information = probeSession.getMediaInformation();
      final streams = information?.getStreams() ?? [];

      final tracks = <ImageSubtitleTrack>[];
      var subtitleOrdinal = 0;
      for (final stream in streams) {
        final properties = stream.getAllProperties() ?? {};
        if (properties['codec_type'] != 'subtitle') {
          continue;
        }
        final codec = properties['codec_name']?.toString() ?? '';
        lastProbedSubtitleCodecs.add(codec);
        if (codec == 'hdmv_pgs_subtitle' || codec == 'dvd_subtitle') {
          final tags = properties['tags'];
          tracks.add(
            ImageSubtitleTrack(
              subtitleOrdinal: subtitleOrdinal,
              codec: codec,
              language: tags is Map ? tags['language']?.toString() : null,
              title: tags is Map ? tags['title']?.toString() : null,
            ),
          );
        }
        subtitleOrdinal++;
      }
      return tracks;
    } catch (e) {
      return [];
    }
  }

  /// OCR [track] of [videoPath] into an SRT file and return it, or
  /// throw with a reason. [onProgress] reports (current, total) OCR'd
  /// subtitle events.
  static Future<File> ocrTrack({
    required String videoPath,
    required ImageSubtitleTrack track,
    required OcrEngine engine,
    void Function(int current, int total)? onProgress,
  }) async {
    if (!track.isPgs) {
      // ffmpeg has no VobSub (.idx/.sub) muxer, so a stream copy of a
      // dvd_subtitle track out of an MKV is not possible this way. The
      // [VobsubParser] is ready; the missing piece is an extraction
      // route (e.g. MPEG-PS remux + palette from codec extradata).
      throw UnsupportedError('VobSub OCR is not available yet.');
    }

    final appDocDir = await getApplicationDocumentsDirectory();
    final scratchDir = Directory('${appDocDir.path}/ocrSubtitles');
    if (!scratchDir.existsSync()) {
      scratchDir.createSync(recursive: true);
    }

    // ffmpeg writes PGS to a single .sup; the vobsub muxer writes the
    // .idx and its companion .sub next to it.
    final extractFile = File(track.isPgs
        ? '${scratchDir.path}/extract.sup'
        : '${scratchDir.path}/extract.idx');
    final companionSub = File('${scratchDir.path}/extract.sub');
    for (final file in [extractFile, companionSub]) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    final command = '-loglevel quiet -i "$videoPath" '
        '-map 0:s:${track.subtitleOrdinal} -c:s copy "${extractFile.path}"';
    await FFmpegKit.execute(command);
    if (!extractFile.existsSync() ||
        extractFile.lengthSync() == 0 ||
        (!track.isPgs && !companionSub.existsSync())) {
      throw StateError('ffmpeg could not extract the subtitle track.');
    }

    // Fresh per-track bitmap store: one PNG per event plus a timing
    // index, used by the player to overlay the original bitmap on the
    // paused frame without moving the playhead.
    final bitmapDir = Directory(
        '${scratchDir.path}/bitmaps/${track.bitmapDirName(videoPath)}');
    if (bitmapDir.existsSync()) {
      bitmapDir.deleteSync(recursive: true);
    }
    bitmapDir.createSync(recursive: true);
    final bitmapIndex = <Map<String, dynamic>>[];

    final srtBuffer = StringBuffer();
    var srtIndex = 0;
    Future<void> onEvent(PgsEvent event) async {
      final result = await engine.recognizeBitmap(
        rgba: event.rgba,
        width: event.width,
        height: event.height,
      );

      try {
        final fileName =
            '${(bitmapIndex.length + 1).toString().padLeft(4, '0')}.png';
        final png = await _encodePng(event.rgba, event.width, event.height);
        File('${bitmapDir.path}/$fileName').writeAsBytesSync(png);
        bitmapIndex.add({
          's': event.start.inMilliseconds,
          'e': event.end.inMilliseconds,
          'f': fileName,
        });
      } catch (e) {
        // A missing bitmap only degrades the paused comparison overlay.
      }

      final text = _textFromResult(result);
      if (text.isEmpty) {
        return;
      }
      srtIndex++;
      // End the SRT cue a hair before the bitmap's own clear time:
      // pause-on-subtitle-end fires at the cue end, and with identical
      // times the paused frame lands a fraction AFTER the PGS bitmap
      // vanished — killing the OCR-vs-bitmap comparison. Ending early
      // keeps the bitmap on screen at the pause point.
      var srtEnd = event.end - const Duration(milliseconds: 50);
      if (srtEnd <= event.start) {
        srtEnd = event.start +
            (event.end - event.start) * 0.8;
      }
      srtBuffer
        ..writeln(srtIndex)
        ..writeln('${_formatSrtTime(event.start)} --> '
            '${_formatSrtTime(srtEnd)}')
        ..writeln(text)
        ..writeln();
    }

    if (track.isPgs) {
      await PgsParser.parse(
        data: extractFile.readAsBytesSync(),
        onProgress: onProgress,
        onEvent: onEvent,
      );
    } else {
      await VobsubParser.parse(
        idxContent: extractFile.readAsStringSync(),
        subData: companionSub.readAsBytesSync(),
        onProgress: onProgress,
        onEvent: onEvent,
      );
    }
    for (final file in [extractFile, companionSub]) {
      if (file.existsSync()) {
        file.deleteSync();
      }
    }

    if (srtIndex == 0) {
      throw StateError('OCR produced no text from this track.');
    }

    File('${bitmapDir.path}/index.json')
        .writeAsStringSync(jsonEncode(bitmapIndex));

    return _writeSidecar(videoPath, track, srtBuffer.toString(), scratchDir);
  }

  /// Encode raw RGBA pixels as PNG via `dart:ui`.
  static Future<Uint8List> _encodePng(
    Uint8List rgba,
    int width,
    int height,
  ) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
        rgba, width, height, ui.PixelFormat.rgba8888, completer.complete);
    final image = await completer.future;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  /// The bitmap store for [track] of [videoPath], if an OCR run has
  /// produced one (older runs predate bitmap saving).
  static Future<Directory?> bitmapDirForTrack({
    required String videoPath,
    required ImageSubtitleTrack track,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory(
        '${appDocDir.path}/ocrSubtitles/bitmaps/${track.bitmapDirName(videoPath)}');
    return dir.existsSync() ? dir : null;
  }

  /// Assemble event text in visual order: blocks top-to-bottom (then
  /// left-to-right), each block's recognised text joined by newlines.
  static String _textFromResult(OcrResult result) {
    final blocks = result.blocks.toList()
      ..sort((a, b) {
        final byTop = a.rect.top.compareTo(b.rect.top);
        return byTop != 0 ? byTop : a.rect.left.compareTo(b.rect.left);
      });
    return blocks
        .map((block) => block.text.trim())
        .where((text) => text.isNotEmpty)
        .join('\n')
        .trim();
  }

  /// Write the per-track sidecar next to the video, falling back to
  /// the app's `ocrSubtitles/` directory when the video's directory is
  /// not writable (e.g. SAF-restricted storage).
  static File _writeSidecar(
    String videoPath,
    ImageSubtitleTrack track,
    String srt,
    Directory fallbackDir,
  ) {
    final basename = path.basenameWithoutExtension(videoPath);
    final sidecar = File(
        '${path.dirname(videoPath)}/$basename${track.sidecarSuffix}');
    try {
      sidecar.writeAsStringSync(srt);
      return sidecar;
    } catch (e) {
      final fallback =
          File('${fallbackDir.path}/$basename${track.sidecarSuffix}');
      fallback.writeAsStringSync(srt);
      return fallback;
    }
  }

  static String _formatSrtTime(Duration duration) {
    String pad(int value, int width) => value.toString().padLeft(width, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;
    return '${pad(hours, 2)}:${pad(minutes, 2)}:${pad(seconds, 2)},'
        '${pad(milliseconds, 3)}';
  }
}
