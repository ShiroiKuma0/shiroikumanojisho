import 'dart:typed_data';

/// One decoded PGS subtitle event: an RGBA bitmap with display timing.
class PgsEvent {
  /// Initialise an event.
  PgsEvent({
    required this.start,
    required this.end,
    required this.rgba,
    required this.width,
    required this.height,
  });

  /// When the subtitle appears.
  final Duration start;

  /// When the subtitle is cleared (the next display set's timestamp, or
  /// a fallback duration for a trailing event).
  final Duration end;

  /// Straight (non-premultiplied) RGBA pixels, composited over black —
  /// PGS text is typically white glyphs with a dark outline, so a black
  /// backdrop yields solid, OCR-friendly shapes.
  final Uint8List rgba;

  /// Bitmap width in pixels.
  final int width;

  /// Bitmap height in pixels.
  final int height;
}

/// Parser for Blu-ray PGS ("HDMV PGS") subtitle streams in the `.sup`
/// container, as produced by `ffmpeg -map 0:s:N -c:s copy out.sup`.
///
/// The format is a sequence of segments, each `PG` + PTS + DTS + type +
/// size: PCS (composition), WDS (windows), PDS (palette), ODS (object
/// bitmap, run-length encoded), END. A display set runs from a PCS to
/// an END; sets whose composition references at least one object are
/// visible subtitles, sets with zero objects are clears. An event's end
/// time is the following display set's PTS.
///
/// Parsing is two-pass so only one decoded bitmap is ever held: the
/// first pass indexes display sets and timings; the second decodes each
/// set in order (palette and object state carries across sets within an
/// epoch) and hands events to the caller one at a time.
class PgsParser {
  PgsParser._(this._data);

  final Uint8List _data;

  static const int _segmentPds = 0x14;
  static const int _segmentOds = 0x15;
  static const int _segmentPcs = 0x16;
  static const int _segmentEnd = 0x80;

  /// Fallback duration for the final event when no clearing display set
  /// follows it.
  static const Duration _trailingEventDuration = Duration(seconds: 5);

  /// Bitmaps shorter than this are upscaled 2x before OCR-oriented
  /// output; ML Kit recognises small subtitle renders (SD sources)
  /// noticeably better with a little more resolution.
  static const int _upscaleHeightThreshold = 80;

  /// Parse [data] (the contents of a `.sup` file). [onEvent] is awaited
  /// for each visible subtitle event in stream order; [onProgress]
  /// reports (current, total) display-set counts.
  static Future<void> parse({
    required Uint8List data,
    required Future<void> Function(PgsEvent event) onEvent,
    void Function(int current, int total)? onProgress,
  }) async {
    final parser = PgsParser._(data);
    final sets = parser._indexDisplaySets();
    final visibleTotal = sets.where((s) => s.hasObjects).length;
    var current = 0;

    // Decode state carried across display sets within an epoch.
    final palettes = <int, Uint8List>{};
    final objects = <int, _PgsObject>{};

    for (var i = 0; i < sets.length; i++) {
      final set = sets[i];
      final event = parser._decodeDisplaySet(set, palettes, objects);
      if (event == null) {
        continue;
      }
      current++;
      onProgress?.call(current, visibleTotal);

      final end = i + 1 < sets.length
          ? sets[i + 1].pts
          : set.pts + _trailingEventDuration;
      if (end <= set.pts) {
        continue;
      }
      await onEvent(
        PgsEvent(
          start: set.pts,
          end: end,
          rgba: event.rgba,
          width: event.width,
          height: event.height,
        ),
      );
    }
  }

  List<_PgsDisplaySet> _indexDisplaySets() {
    final sets = <_PgsDisplaySet>[];
    var offset = 0;
    _PgsDisplaySet? currentSet;

    while (offset + 13 <= _data.length) {
      if (_data[offset] != 0x50 || _data[offset + 1] != 0x47) {
        // Out of sync — should not happen in ffmpeg output; bail out
        // with what we have rather than scanning byte-by-byte.
        break;
      }
      final pts90k = _readUint32(offset + 2);
      final type = _data[offset + 10];
      final size = _readUint16(offset + 11);
      final payloadStart = offset + 13;
      if (payloadStart + size > _data.length) {
        break;
      }

      if (type == _segmentPcs) {
        final objectCount = size >= 11 ? _data[payloadStart + 10] : 0;
        currentSet = _PgsDisplaySet(
          pts: Duration(microseconds: pts90k * 1000 ~/ 90),
          hasObjects: objectCount > 0,
          pcsOffset: payloadStart,
          pcsSize: size,
        );
      } else if (currentSet != null) {
        if (type == _segmentPds || type == _segmentOds) {
          currentSet.segments.add(_PgsSegment(type, payloadStart, size));
        } else if (type == _segmentEnd) {
          sets.add(currentSet);
          currentSet = null;
        }
      }

      offset = payloadStart + size;
    }
    return sets;
  }

  _PgsComposedBitmap? _decodeDisplaySet(
    _PgsDisplaySet set,
    Map<int, Uint8List> palettes,
    Map<int, _PgsObject> objects,
  ) {
    // Apply this set's palette and object segments to the epoch state.
    for (final segment in set.segments) {
      if (segment.type == _segmentPds) {
        _decodePalette(segment, palettes);
      } else {
        _decodeObjectSegment(segment, objects);
      }
    }

    if (!set.hasObjects) {
      return null;
    }

    // Read the composition: palette id + object placements.
    final p = set.pcsOffset;
    final paletteId = _data[p + 9];
    final objectCount = _data[p + 10];
    final palette = palettes[paletteId];
    if (palette == null) {
      return null;
    }

    final placements = <_PgsPlacement>[];
    var q = p + 11;
    for (var i = 0; i < objectCount; i++) {
      if (q + 8 > p + set.pcsSize) {
        break;
      }
      final objectId = _readUint16(q);
      final cropped = (_data[q + 3] & 0x40) != 0;
      final x = _readUint16(q + 4);
      final y = _readUint16(q + 6);
      q += 8;
      if (cropped) {
        q += 8;
      }
      final object = objects[objectId];
      if (object != null && object.isComplete) {
        placements.add(_PgsPlacement(object, x, y));
      }
    }
    if (placements.isEmpty) {
      return null;
    }

    // Composite all placed objects into a canvas covering their union.
    var minX = placements.first.x;
    var minY = placements.first.y;
    var maxX = 0;
    var maxY = 0;
    for (final placement in placements) {
      minX = placement.x < minX ? placement.x : minX;
      minY = placement.y < minY ? placement.y : minY;
      final right = placement.x + placement.object.width;
      final bottom = placement.y + placement.object.height;
      maxX = right > maxX ? right : maxX;
      maxY = bottom > maxY ? bottom : maxY;
    }
    final width = maxX - minX;
    final height = maxY - minY;
    if (width <= 0 || height <= 0 || width > 4096 || height > 4096) {
      return null;
    }

    final rgba = Uint8List(width * height * 4);
    for (final placement in placements) {
      _renderObject(
        placement.object,
        palette,
        rgba,
        width,
        placement.x - minX,
        placement.y - minY,
      );
    }

    if (height < _upscaleHeightThreshold) {
      return _upscale2x(rgba, width, height);
    }
    return _PgsComposedBitmap(rgba, width, height);
  }

  void _decodePalette(_PgsSegment segment, Map<int, Uint8List> palettes) {
    if (segment.size < 2) {
      return;
    }
    final paletteId = _data[segment.offset];
    // 256 RGBA entries; undefined entries stay transparent.
    final palette = palettes.putIfAbsent(paletteId, () => Uint8List(256 * 4));
    var offset = segment.offset + 2;
    final endOffset = segment.offset + segment.size;
    while (offset + 5 <= endOffset) {
      final entry = _data[offset];
      final y = _data[offset + 1].toDouble();
      final cr = _data[offset + 2].toDouble() - 128;
      final cb = _data[offset + 3].toDouble() - 128;
      final alpha = _data[offset + 4];
      // BT.709, the norm for Blu-ray subtitle renders.
      final r = (y + 1.5748 * cr).round().clamp(0, 255);
      final g = (y - 0.1873 * cb - 0.4681 * cr).round().clamp(0, 255);
      final b = (y + 1.8556 * cb).round().clamp(0, 255);
      palette[entry * 4] = r;
      palette[entry * 4 + 1] = g;
      palette[entry * 4 + 2] = b;
      palette[entry * 4 + 3] = alpha;
      offset += 5;
    }
  }

  void _decodeObjectSegment(_PgsSegment segment, Map<int, _PgsObject> objects) {
    if (segment.size < 4) {
      return;
    }
    final objectId = _readUint16(segment.offset);
    final sequenceFlag = _data[segment.offset + 3];
    final isFirst = (sequenceFlag & 0x80) != 0;

    if (isFirst) {
      if (segment.size < 11) {
        return;
      }
      // 3-byte data length counts width/height plus RLE data, possibly
      // spanning continuation segments.
      final dataLength = (_data[segment.offset + 4] << 16) |
          (_data[segment.offset + 5] << 8) |
          _data[segment.offset + 6];
      final width = _readUint16(segment.offset + 7);
      final height = _readUint16(segment.offset + 9);
      final object = _PgsObject(width, height, dataLength - 4);
      object.appendRle(
          _data, segment.offset + 11, segment.offset + segment.size);
      objects[objectId] = object;
    } else {
      objects[objectId]
          ?.appendRle(_data, segment.offset + 4, segment.offset + segment.size);
    }
  }

  /// Decode an object's RLE data and alpha-blend it over the (black)
  /// canvas at (dstX, dstY).
  void _renderObject(
    _PgsObject object,
    Uint8List palette,
    Uint8List canvas,
    int canvasWidth,
    int dstX,
    int dstY,
  ) {
    final rle = object.rle;
    var i = 0;
    var x = 0;
    var y = 0;

    void put(int color, int count) {
      final r = palette[color * 4];
      final g = palette[color * 4 + 1];
      final b = palette[color * 4 + 2];
      final a = palette[color * 4 + 3];
      for (var n = 0; n < count; n++) {
        if (x >= object.width) {
          break;
        }
        if (a != 0) {
          final index = ((dstY + y) * canvasWidth + dstX + x) * 4;
          // Composite over black: premultiplied colour, opaque result.
          canvas[index] = r * a ~/ 255;
          canvas[index + 1] = g * a ~/ 255;
          canvas[index + 2] = b * a ~/ 255;
          canvas[index + 3] = 255;
        }
        x++;
      }
    }

    while (i < rle.length && y < object.height) {
      final first = rle[i++];
      if (first != 0) {
        put(first, 1);
        continue;
      }
      if (i >= rle.length) {
        break;
      }
      final flags = rle[i++];
      if (flags == 0) {
        // End of line.
        x = 0;
        y++;
      } else if (flags & 0xC0 == 0) {
        put(0, flags);
      } else if (flags & 0xC0 == 0x40) {
        if (i >= rle.length) {
          break;
        }
        put(0, ((flags & 0x3F) << 8) | rle[i++]);
      } else if (flags & 0xC0 == 0x80) {
        if (i >= rle.length) {
          break;
        }
        put(rle[i++], flags & 0x3F);
      } else {
        if (i + 1 >= rle.length) {
          break;
        }
        final count = ((flags & 0x3F) << 8) | rle[i++];
        put(rle[i++], count);
      }
    }
  }

  static _PgsComposedBitmap _upscale2x(Uint8List rgba, int width, int height) {
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
    return _PgsComposedBitmap(out, outWidth, outHeight);
  }

  int _readUint16(int offset) => (_data[offset] << 8) | _data[offset + 1];

  int _readUint32(int offset) =>
      (_data[offset] << 24) |
      (_data[offset + 1] << 16) |
      (_data[offset + 2] << 8) |
      _data[offset + 3];
}

class _PgsSegment {
  _PgsSegment(this.type, this.offset, this.size);

  final int type;
  final int offset;
  final int size;
}

class _PgsDisplaySet {
  _PgsDisplaySet({
    required this.pts,
    required this.hasObjects,
    required this.pcsOffset,
    required this.pcsSize,
  });

  final Duration pts;
  final bool hasObjects;
  final int pcsOffset;
  final int pcsSize;
  final List<_PgsSegment> segments = [];
}

class _PgsObject {
  _PgsObject(this.width, this.height, this.expectedRleLength)
      : rle = Uint8List(expectedRleLength < 0 ? 0 : expectedRleLength);

  final int width;
  final int height;
  final int expectedRleLength;
  final Uint8List rle;
  int _filled = 0;

  bool get isComplete => _filled >= expectedRleLength;

  void appendRle(Uint8List data, int start, int end) {
    final available = rle.length - _filled;
    final length = (end - start) < available ? (end - start) : available;
    if (length <= 0) {
      return;
    }
    rle.setRange(_filled, _filled + length, data, start);
    _filled += length;
  }
}

class _PgsPlacement {
  _PgsPlacement(this.object, this.x, this.y);

  final _PgsObject object;
  final int x;
  final int y;
}

class _PgsComposedBitmap {
  _PgsComposedBitmap(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}
