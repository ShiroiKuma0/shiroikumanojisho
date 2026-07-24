import 'dart:typed_data';

import 'package:shiroikumanojisho/src/utils/ocr/pgs_parser.dart';

/// Parser for DVD VobSub subtitles: an `.idx` text index (palette,
/// timestamps, file positions) plus a `.sub` MPEG-2 program stream of
/// SPU (subpicture) packets, as produced by
/// `ffmpeg -map 0:s:N -c:s copy out.idx` (ffmpeg writes the pair).
///
/// Each idx timestamp entry points at an SPU packet in the `.sub`: PES
/// packets are reassembled into the subpicture, whose control sequence
/// supplies the 4-colour palette selection, alpha, display area,
/// interlaced RLE offsets, and the stop-display delay. Decoded events
/// are produced as [PgsEvent]s (the shared bitmap-event shape of the
/// subtitle OCR pipeline), composited over black like the PGS path.
class VobsubParser {
  VobsubParser._();

  /// DVD subs are SD renders; text is small, and ML Kit benefits from
  /// the same 2x upscale the PGS path applies to short bitmaps.
  static const int _upscaleHeightThreshold = 80;

  /// Fallback duration when an SPU carries no stop-display command and
  /// no later entry bounds it.
  static const Duration _trailingEventDuration = Duration(seconds: 5);

  /// Parse the `.idx` [idxContent] and `.sub` [subData]. [onEvent] is
  /// awaited per decoded subtitle in stream order; [onProgress] reports
  /// (current, total) over the idx entries.
  static Future<void> parse({
    required String idxContent,
    required Uint8List subData,
    required Future<void> Function(PgsEvent event) onEvent,
    void Function(int current, int total)? onProgress,
  }) async {
    final palette = _parsePalette(idxContent);
    final entries = _parseEntries(idxContent);

    for (var i = 0; i < entries.length; i++) {
      onProgress?.call(i + 1, entries.length);
      final entry = entries[i];

      final spu = _extractSpu(subData, entry.filepos);
      if (spu == null) {
        continue;
      }
      final decoded = _decodeSpu(spu, palette);
      if (decoded == null) {
        continue;
      }

      var end = decoded.stopDelay != null
          ? entry.timestamp + decoded.stopDelay!
          : (i + 1 < entries.length
              ? entries[i + 1].timestamp
              : entry.timestamp + _trailingEventDuration);
      // Never overlap into the next subtitle.
      if (i + 1 < entries.length && end > entries[i + 1].timestamp) {
        end = entries[i + 1].timestamp;
      }
      if (end <= entry.timestamp) {
        continue;
      }

      var bitmap = decoded.bitmap;
      var width = decoded.width;
      var height = decoded.height;
      if (height < _upscaleHeightThreshold) {
        final upscaled = _upscale2x(bitmap, width, height);
        bitmap = upscaled.rgba;
        width = upscaled.width;
        height = upscaled.height;
      }

      await onEvent(
        PgsEvent(
          start: entry.timestamp,
          end: end,
          rgba: bitmap,
          width: width,
          height: height,
        ),
      );
    }
  }

  /// The idx `palette:` line: 16 comma-separated RRGGBB values.
  static List<int> _parsePalette(String idxContent) {
    final match =
        RegExp(r'^palette:\s*(.+)$', multiLine: true).firstMatch(idxContent);
    final colors = List<int>.filled(16, 0);
    if (match == null) {
      return colors;
    }
    final values = match.group(1)!.split(',');
    for (var i = 0; i < values.length && i < 16; i++) {
      colors[i] = int.tryParse(values[i].trim(), radix: 16) ?? 0;
    }
    return colors;
  }

  static List<_VobsubEntry> _parseEntries(String idxContent) {
    final pattern = RegExp(
      r'^timestamp:\s*(\d+):(\d+):(\d+):(\d+),\s*filepos:\s*([0-9a-fA-F]+)',
      multiLine: true,
    );
    return pattern.allMatches(idxContent).map((match) {
      final timestamp = Duration(
        hours: int.parse(match.group(1)!),
        minutes: int.parse(match.group(2)!),
        seconds: int.parse(match.group(3)!),
        milliseconds: int.parse(match.group(4)!),
      );
      return _VobsubEntry(timestamp, int.parse(match.group(5)!, radix: 16));
    }).toList();
  }

  /// Reassemble one SPU from the MPEG-2 program stream starting at
  /// [filepos]: walk pack headers and private-stream-1 PES packets,
  /// concatenating payloads until the SPU's declared size is reached.
  static Uint8List? _extractSpu(Uint8List data, int filepos) {
    var offset = filepos;
    final chunks = BytesBuilder(copy: false);
    var spuSize = -1;
    var collected = 0;

    while (offset + 4 <= data.length) {
      final startCode = _readUint32(data, offset);
      if (startCode == 0x000001BA) {
        // Pack header: 14 bytes + stuffing.
        if (offset + 14 > data.length) {
          return null;
        }
        final stuffing = data[offset + 13] & 0x07;
        offset += 14 + stuffing;
      } else if (startCode == 0x000001BD) {
        if (offset + 9 > data.length) {
          return null;
        }
        final pesLength = _readUint16(data, offset + 4);
        final headerLength = data[offset + 8];
        var payloadStart = offset + 9 + headerLength;
        final payloadEnd = offset + 6 + pesLength;
        if (payloadEnd > data.length || payloadStart >= payloadEnd) {
          return null;
        }
        // First payload byte is the substream id (0x20-0x3F).
        payloadStart++;
        chunks.add(Uint8List.sublistView(data, payloadStart, payloadEnd));
        collected += payloadEnd - payloadStart;
        if (spuSize < 0 && collected >= 2) {
          final soFar = chunks.toBytes();
          spuSize = (soFar[0] << 8) | soFar[1];
          chunks
            ..clear()
            ..add(soFar);
        }
        if (spuSize >= 0 && collected >= spuSize) {
          final spu = chunks.toBytes();
          return Uint8List.sublistView(spu, 0, spuSize);
        }
        offset = payloadEnd;
      } else if ((startCode & 0xFFFFFF00) == 0x00000100) {
        // Some other PES packet (padding etc.) — skip it.
        if (offset + 6 > data.length) {
          return null;
        }
        offset += 6 + _readUint16(data, offset + 4);
      } else {
        return null;
      }
    }
    return null;
  }

  static _DecodedSpu? _decodeSpu(Uint8List spu, List<int> masterPalette) {
    if (spu.length < 4) {
      return null;
    }
    final controlOffset = (spu[2] << 8) | spu[3];
    if (controlOffset >= spu.length) {
      return null;
    }

    // Walk control sequences.
    var paletteNibbles = 0;
    var alphaNibbles = 0;
    var x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    var rleTop = -1, rleBottom = -1;
    Duration? stopDelay;

    var sequenceOffset = controlOffset;
    var guard = 0;
    while (sequenceOffset + 4 <= spu.length && guard++ < 64) {
      final delay90k = ((spu[sequenceOffset] << 8) | spu[sequenceOffset + 1]);
      final nextOffset =
          (spu[sequenceOffset + 2] << 8) | spu[sequenceOffset + 3];
      var p = sequenceOffset + 4;

      var done = false;
      while (p < spu.length && !done) {
        switch (spu[p]) {
          case 0x00: // Forced display.
          case 0x01: // Start display.
            p++;
            break;
          case 0x02: // Stop display: this sequence's delay is the duration.
            stopDelay = Duration(
                microseconds: (delay90k << 10) * 1000000 ~/ 90000);
            p++;
            break;
          case 0x03: // Palette selection: 4 nibbles.
            if (p + 2 >= spu.length) {
              return null;
            }
            paletteNibbles = (spu[p + 1] << 8) | spu[p + 2];
            p += 3;
            break;
          case 0x04: // Alpha: 4 nibbles.
            if (p + 2 >= spu.length) {
              return null;
            }
            alphaNibbles = (spu[p + 1] << 8) | spu[p + 2];
            p += 3;
            break;
          case 0x05: // Display area: 12-bit x1 x2 y1 y2.
            if (p + 6 >= spu.length) {
              return null;
            }
            x1 = (spu[p + 1] << 4) | (spu[p + 2] >> 4);
            x2 = ((spu[p + 2] & 0x0F) << 8) | spu[p + 3];
            y1 = (spu[p + 4] << 4) | (spu[p + 5] >> 4);
            y2 = ((spu[p + 5] & 0x0F) << 8) | spu[p + 6];
            p += 7;
            break;
          case 0x06: // RLE offsets for top/bottom fields.
            if (p + 4 >= spu.length) {
              return null;
            }
            rleTop = (spu[p + 1] << 8) | spu[p + 2];
            rleBottom = (spu[p + 3] << 8) | spu[p + 4];
            p += 5;
            break;
          case 0xFF:
            done = true;
            p++;
            break;
          default:
            // Unknown command — abandon this sequence.
            done = true;
            break;
        }
      }

      if (nextOffset == sequenceOffset) {
        break;
      }
      sequenceOffset = nextOffset;
    }

    final width = x2 - x1 + 1;
    final height = y2 - y1 + 1;
    if (width <= 0 || height <= 0 || width > 2048 || height > 2048 ||
        rleTop < 0 || rleBottom < 0) {
      return null;
    }

    // Resolve the 4 subtitle colours from the master palette + alpha.
    final colors = List<int>.filled(4, 0);
    final alphas = List<int>.filled(4, 0);
    for (var i = 0; i < 4; i++) {
      final paletteIndex = (paletteNibbles >> (i * 4)) & 0x0F;
      colors[i] = masterPalette[paletteIndex];
      final alpha4 = (alphaNibbles >> (i * 4)) & 0x0F;
      alphas[i] = alpha4 * 255 ~/ 15;
    }

    final rgba = Uint8List(width * height * 4);
    _decodeRleField(spu, rleTop, rgba, width, height, 0, colors, alphas);
    _decodeRleField(spu, rleBottom, rgba, width, height, 1, colors, alphas);

    return _DecodedSpu(rgba, width, height, stopDelay);
  }

  /// Decode one interlaced field (startLine 0 = top/even lines,
  /// 1 = bottom/odd lines) of nibble-based RLE.
  static void _decodeRleField(
    Uint8List spu,
    int offset,
    Uint8List rgba,
    int width,
    int height,
    int startLine,
    List<int> colors,
    List<int> alphas,
  ) {
    var bitOffset = offset * 8;
    var x = 0;
    var y = startLine;

    int readNibble() {
      if (bitOffset + 4 > spu.length * 8) {
        return -1;
      }
      final byte = spu[bitOffset >> 3];
      final nibble = (bitOffset & 7) == 0 ? byte >> 4 : byte & 0x0F;
      bitOffset += 4;
      return nibble;
    }

    void putRun(int color, int count) {
      final rgb = colors[color];
      final alpha = alphas[color];
      for (var n = 0; n < count && x < width; n++, x++) {
        if (alpha == 0) {
          continue;
        }
        final index = (y * width + x) * 4;
        rgba[index] = ((rgb >> 16) & 0xFF) * alpha ~/ 255;
        rgba[index + 1] = ((rgb >> 8) & 0xFF) * alpha ~/ 255;
        rgba[index + 2] = (rgb & 0xFF) * alpha ~/ 255;
        rgba[index + 3] = 255;
      }
    }

    while (y < height) {
      var value = readNibble();
      if (value < 0) {
        return;
      }
      if (value < 0x4) {
        final next = readNibble();
        if (next < 0) {
          return;
        }
        value = (value << 4) | next;
        if (value < 0x10) {
          final third = readNibble();
          if (third < 0) {
            return;
          }
          value = (value << 4) | third;
          if (value < 0x40) {
            final fourth = readNibble();
            if (fourth < 0) {
              return;
            }
            value = (value << 4) | fourth;
          }
        }
      }

      final color = value & 0x3;
      var count = value >> 2;
      if (count == 0) {
        // Fill to end of line.
        count = width - x;
      }
      putRun(color, count);

      if (x >= width) {
        x = 0;
        y += 2; // Interlaced: this field's next line.
        // Runs are byte-aligned per line.
        if ((bitOffset & 7) != 0) {
          bitOffset += 4;
        }
      }
    }
  }

  static _Upscaled _upscale2x(Uint8List rgba, int width, int height) {
    final outWidth = width * 2;
    final outHeight = height * 2;
    final out = Uint8List(outWidth * outHeight * 4);
    for (var y = 0; y < outHeight; y++) {
      final srcRow = (y >> 1) * width;
      final dstRow = y * outWidth;
      for (var x = 0; x < outWidth; x++) {
        final src = (srcRow + (x >> 1)) * 4;
        final dst = (dstRow + x) * 4;
        out[dst] = rgba[src];
        out[dst + 1] = rgba[src + 1];
        out[dst + 2] = rgba[src + 2];
        out[dst + 3] = rgba[src + 3];
      }
    }
    return _Upscaled(out, outWidth, outHeight);
  }

  static int _readUint16(Uint8List data, int offset) =>
      (data[offset] << 8) | data[offset + 1];

  static int _readUint32(Uint8List data, int offset) =>
      (data[offset] << 24) |
      (data[offset + 1] << 16) |
      (data[offset + 2] << 8) |
      data[offset + 3];
}

class _VobsubEntry {
  _VobsubEntry(this.timestamp, this.filepos);

  final Duration timestamp;
  final int filepos;
}

class _DecodedSpu {
  _DecodedSpu(this.bitmap, this.width, this.height, this.stopDelay);

  final Uint8List bitmap;
  final int width;
  final int height;
  final Duration? stopDelay;
}

class _Upscaled {
  _Upscaled(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}
