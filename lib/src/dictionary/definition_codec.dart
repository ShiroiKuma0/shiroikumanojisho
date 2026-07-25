import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shiroikumanojisho/dictionary.dart' show DictionaryEntry;
import 'package:shiroikumanojisho/src/dictionary/dictionary_entry.dart' show DictionaryEntry;

/// Codec for compressing and decompressing dictionary entry definition lists.
///
/// Definitions are stored on [DictionaryEntry.compressedDefinitions] as raw
/// gzip-compressed bytes (no base64 wrapping — Isar's `byteList` type stores
/// `List<int>` natively as a packed byte array).
///
/// Wire format:
///   1 byte  — magic byte (0x47 = 'G') identifying gzip-compressed payload
///   1 byte  — version (currently 1)
///   N bytes — gzip-compressed UTF-8 of JSON-encoded `List<String>`
///
/// Empty inputs are returned as an empty byte list (no header). Inputs whose
/// JSON representation is shorter than [_minCompressLength] are stored as the
/// magic + version + raw uncompressed UTF-8 (decompression detects this
/// because a small payload won't begin with a gzip frame magic). The two-byte
/// header is cheap insurance against future format changes.
///
/// The underlying [GZipCodec] from `dart:io` is synchronous, but the codec
/// exposes an asynchronous API to match the previous zstd-based interface
/// and to give callers the option to route compression through an isolate
/// later without an API break. Each call runs the codec inline and returns
/// a resolved Future.
///
/// Compression ratios on dictionary glossary text are typically in the
/// 3–3.5× range at gzip's default level (6). This is lower than zstd's
/// ~4.5× but is still a substantial win over storing raw JSON, and the
/// codec ships with the Dart SDK itself — no plugin, no FFI, no
/// SDK-version constraints.
class DefinitionCodec {
  DefinitionCodec._();

  /// Magic byte identifying a gzip-compressed definitions payload.
  static const int _magicByte = 0x47; // 'G'

  /// Current wire format version.
  static const int _version = 0x01;

  /// Inputs whose UTF-8 JSON encoding is below this size in bytes are stored
  /// uncompressed (after the 2-byte header). Compression overhead and frame
  /// headers exceed the win below this threshold for gzip (which adds an
  /// ~18-byte gzip frame header).
  static const int _minCompressLength = 64;

  /// Shared codec instance. [GZipCodec] is stateless so we just reuse it.
  static final GZipCodec _gzip = GZipCodec();

  /// Encode a list of definition strings into compressed bytes ready for
  /// storage in [DictionaryEntry.compressedDefinitions].
  ///
  /// An empty list returns an empty `List<int>`.
  static Future<List<int>> encode(List<String> definitions) async {
    if (definitions.isEmpty) return const <int>[];

    final jsonBytes = utf8.encode(jsonEncode(definitions));

    if (jsonBytes.length < _minCompressLength) {
      // Skip compression for tiny payloads — header + raw JSON.
      return _withHeader(jsonBytes, compressed: false);
    }

    try {
      final compressed = _gzip.encode(jsonBytes);
      if (compressed.isEmpty) {
        return _withHeader(jsonBytes, compressed: false);
      }
      return _withHeader(compressed, compressed: true);
    } catch (e) {
      debugPrint('DefinitionCodec.encode: gzip encode failed, falling '
          'back to uncompressed storage: $e');
      return _withHeader(jsonBytes, compressed: false);
    }
  }

  /// Decode previously encoded bytes back into the original list of
  /// definition strings.
  ///
  /// Returns an empty list if [bytes] is empty. Throws [FormatException] on
  /// header mismatch (which would indicate corruption or wrong-format data
  /// in the field).
  static Future<List<String>> decode(List<int> bytes) async {
    if (bytes.isEmpty) return const <String>[];

    if (bytes.length < 2) {
      throw const FormatException(
          'DefinitionCodec: payload too short for header');
    }

    if (bytes[0] != _magicByte) {
      throw FormatException(
          'DefinitionCodec: bad magic byte: 0x${bytes[0].toRadixString(16)}');
    }

    final version = bytes[1];
    if (version != _version) {
      throw FormatException(
          'DefinitionCodec: unsupported wire format version $version');
    }

    final payload = bytes.length == 2
        ? const <int>[]
        : Uint8List.sublistView(
            bytes is Uint8List ? bytes : Uint8List.fromList(bytes), 2);

    List<int> jsonBytes;
    if (_looksLikeGzipFrame(payload)) {
      try {
        jsonBytes = _gzip.decode(payload);
      } catch (e) {
        throw FormatException('DefinitionCodec: gzip decode failed: $e');
      }
    } else {
      // Stored uncompressed (small payload path).
      jsonBytes = payload;
    }

    if (jsonBytes.isEmpty) return const <String>[];

    final decoded = jsonDecode(utf8.decode(jsonBytes));
    if (decoded is! List) {
      throw const FormatException(
          'DefinitionCodec: payload did not decode to a List');
    }
    return List<String>.from(decoded);
  }

  /// Decode many entries' compressed definitions in one batch. Useful in the
  /// search post-processing step to populate caches before render.
  static Future<List<List<String>>> decodeAll(
      Iterable<List<int>> entriesBytes) async {
    return Future.wait(entriesBytes.map(decode));
  }

  /// Marker check: does [payload] begin with the gzip frame magic
  /// (`0x1F 0x8B`)?
  static bool _looksLikeGzipFrame(List<int> payload) {
    if (payload.length < 2) return false;
    return payload[0] == 0x1F && payload[1] == 0x8B;
  }

  /// Prepend the 2-byte header to the given payload.
  static List<int> _withHeader(List<int> payload, {required bool compressed}) {
    final out = Uint8List(payload.length + 2);
    out[0] = _magicByte;
    out[1] = _version;
    out.setRange(2, out.length, payload);
    return out;
  }
}
