import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// One entry in the user-font registry: a font the user has imported
/// via the reader appearance dialog, stored on disk and available to
/// the TTU WebView via `@font-face` rules injected on page load.
class UserFontEntry {
  UserFontEntry({
    required this.name,
    required this.fileName,
    required this.relativePath,
  });

  /// Display/CSS name — the string the user selects in the font-family
  /// field. Extracted from the font file's OpenType `name` table when
  /// possible, otherwise derived from the filename.
  final String name;

  /// Original filename as picked by the user. Preserved so a later
  /// duplicate import can be detected by file rather than by display
  /// name.
  final String fileName;

  /// Path relative to the user fonts directory. We store relative, not
  /// absolute, because `getApplicationDocumentsDirectory()` can change
  /// across OS upgrades on some devices (sandbox path rewrites).
  final String relativePath;

  Map<String, String> toJson() => {
        'name': name,
        'fileName': fileName,
        'relativePath': relativePath,
      };

  static UserFontEntry fromJson(Map<dynamic, dynamic> json) => UserFontEntry(
        name: (json['name'] ?? '').toString(),
        fileName: (json['fileName'] ?? '').toString(),
        relativePath: (json['relativePath'] ?? '').toString(),
      );
}

/// Process-wide singleton managing imported user fonts.
///
/// Persistence layout:
///   - bytes:  `<appDocDir>/user_fonts/<sanitized>.<ttf|otf>`
///   - index:  Hive box `user_fonts` → key `entries` is a
///             JSON-encoded list of [UserFontEntry] maps.
///
/// The index is JSON-encoded rather than stored as a raw Hive list
/// because Hive's typed adapters don't round-trip heterogeneous map
/// values cleanly across schema changes, and the overhead of a single
/// encode/decode per mutation is negligible at our cardinality.
///
/// Fonts are served to the reader WebView over a small loopback HTTP
/// server ([port]), so `@font-face` rules can use URL sources like
/// `http://127.0.0.1:<port>/<fileName>` instead of shipping multi-MB
/// base64 blobs through `evaluateJavascript`. This mirrors how TTU
/// itself serves its own imported fonts (Cache API + service worker
/// at `/userfonts/*`) — just from Dart rather than from a browser
/// cache — so the reader's font-loading path stays the one TTU's
/// Svelte code was built around.
class UserFontsStore {
  UserFontsStore._();

  static final UserFontsStore instance = UserFontsStore._();

  static const String _boxName = 'user_fonts';
  static const String _entriesKey = 'entries';
  static const String _dirName = 'user_fonts';

  Box? _box;
  Directory? _dir;
  HttpServer? _server;
  int? _port;

  /// Loopback port where imported fonts are served, or null if the
  /// server hasn't started (or failed to start). Callers building
  /// `@font-face` URLs should check for null and skip injection.
  int? get port => _port;

  /// Open the Hive box, ensure the fonts directory exists, and start
  /// the loopback font server. Idempotent — repeated calls after a
  /// successful start are no-ops.
  Future<void> initialise() async {
    _box ??= await Hive.openBox(_boxName);
    if (_dir == null) {
      final appDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDir.path}/$_dirName');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      _dir = dir;
    }
    if (_server == null) {
      try {
        final server = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          0, // Dynamic port — avoids clashing with the reader's own
          // LocalAssetsServer which also binds to loopback.
        );
        _server = server;
        _port = server.port;
        // Listen in the background. Errors on individual requests are
        // swallowed in [_handleRequest]; errors on the socket itself
        // are logged but don't crash the app.
        server.listen(
          _handleRequest,
          onError: (Object e, StackTrace st) {},
          cancelOnError: false,
        );
      } catch (_) {
        _server = null;
        _port = null;
      }
    }
  }

  /// Serve a GET request for a font file. The request path is the
  /// URL-encoded [UserFontEntry.fileName]; we look up the entry,
  /// stream the bytes, and attach permissive CORS headers so the
  /// reader (loaded from a different loopback port by
  /// `LocalAssetsServer`) can use the response for `@font-face`.
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      // CORS preflight + allow any origin. @font-face is subject to
      // the Fetch spec's cross-origin rules, and our reader runs at
      // a different loopback port than this font server.
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET');
      if (request.method == 'OPTIONS') {
        request.response.statusCode = 204;
        await request.response.close();
        return;
      }
      if (request.method != 'GET') {
        request.response.statusCode = 405;
        await request.response.close();
        return;
      }

      final path = request.uri.path;
      final raw = path.startsWith('/') ? path.substring(1) : path;
      final fileName = Uri.decodeComponent(raw);

      // Manual null-returning lookup: `list().where(...).firstOrNull`
      // would require `package:collection`, but the cost of adding a
      // whole dep for one call isn't worth it.
      UserFontEntry? entry;
      for (final e in list()) {
        if (e.fileName == fileName) {
          entry = e;
          break;
        }
      }
      if (entry == null) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      final abs = absolutePath(entry);
      if (abs == null) {
        request.response.statusCode = 500;
        await request.response.close();
        return;
      }
      final file = File(abs);
      if (!file.existsSync()) {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }

      final ext = fileName.split('.').last.toLowerCase();
      final mime = ext == 'otf' ? 'font/otf' : 'font/ttf';
      request.response.headers.contentType = ContentType.parse(mime);
      request.response.headers
          .add('Cache-Control', 'public, max-age=31536000, immutable');
      await file.openRead().pipe(request.response);
    } catch (_) {
      try {
        request.response.statusCode = 500;
        await request.response.close();
      } catch (_) {}
    }
  }

  /// Current list of registered fonts, in insertion order.
  List<UserFontEntry> list() {
    final box = _box;
    if (box == null) return const [];
    final raw = box.get(_entriesKey);
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<dynamic, dynamic>>()
          .map(UserFontEntry.fromJson)
          .where((e) => e.name.isNotEmpty && e.relativePath.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persist an updated list back to Hive.
  Future<void> _writeList(List<UserFontEntry> entries) async {
    final box = _box;
    if (box == null) return;
    final payload =
        jsonEncode(entries.map((e) => e.toJson()).toList(growable: false));
    await box.put(_entriesKey, payload);
  }

  /// Absolute path for a stored font. Resolved lazily against the
  /// current app-docs directory so we tolerate sandbox-path rewrites
  /// across OS upgrades (see [UserFontEntry.relativePath]).
  String? absolutePath(UserFontEntry entry) {
    final dir = _dir;
    if (dir == null) return null;
    return '${dir.path}/${entry.relativePath}';
  }

  /// Read bytes for a stored font, or null if the file is missing.
  Future<Uint8List?> readBytes(UserFontEntry entry) async {
    final path = absolutePath(entry);
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    return file.readAsBytes();
  }

  /// Import a font file into the store. The file at [sourcePath] is
  /// copied into our fonts directory and the index is updated. If a
  /// [displayName] is not provided it's extracted from the font's
  /// OpenType `name` table; if that fails we fall back to the filename
  /// stem.
  ///
  /// Returns the persisted [UserFontEntry]. Rejects (throws) if the
  /// extension isn't .ttf or .otf.
  Future<UserFontEntry> addFont({
    required String sourcePath,
    String? displayName,
  }) async {
    await initialise();
    final source = File(sourcePath);
    final fileName = source.uri.pathSegments.last;
    final ext = _extensionOf(fileName).toLowerCase();
    if (ext != 'ttf' && ext != 'otf') {
      throw const FormatException('Only .ttf and .otf fonts are supported');
    }

    final bytes = await source.readAsBytes();
    final extracted = displayName ?? _extractFontName(bytes) ?? _stemOf(fileName);
    final cleanName = extracted.trim();
    if (cleanName.isEmpty) {
      throw const FormatException('Font name could not be determined');
    }

    final sanitized = _sanitizeFilename(fileName);
    final relativePath = sanitized;
    final destAbsPath = '${_dir!.path}/$relativePath';
    await File(destAbsPath).writeAsBytes(bytes, flush: true);

    final entry = UserFontEntry(
      name: cleanName,
      fileName: fileName,
      relativePath: relativePath,
    );

    final current = list();
    // If an entry with the same display name or same filename already
    // exists, replace it in place (user reimporting, or picking a file
    // with the same on-disk name twice). Keeps insertion order stable.
    final updated = <UserFontEntry>[];
    bool replaced = false;
    for (final existing in current) {
      if (existing.name == entry.name || existing.fileName == entry.fileName) {
        updated.add(entry);
        replaced = true;
      } else {
        updated.add(existing);
      }
    }
    if (!replaced) updated.add(entry);
    await _writeList(updated);
    return entry;
  }

  /// Remove a registered font by display name. Missing entries are a
  /// no-op (the caller shouldn't have to check existence first).
  Future<void> removeByName(String name) async {
    await initialise();
    final current = list();
    final remaining = current.where((e) => e.name != name).toList();
    if (remaining.length == current.length) return;
    for (final e in current.where((e) => e.name == name)) {
      final path = absolutePath(e);
      if (path == null) continue;
      final file = File(path);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (_) {
          // Best-effort cleanup; leave orphan file rather than fail
          // the removal.
        }
      }
    }
    await _writeList(remaining);
  }

  static String _extensionOf(String fileName) {
    final i = fileName.lastIndexOf('.');
    if (i < 0 || i == fileName.length - 1) return '';
    return fileName.substring(i + 1);
  }

  static String _stemOf(String fileName) {
    final i = fileName.lastIndexOf('.');
    return i > 0 ? fileName.substring(0, i) : fileName;
  }

  /// Map a filename to a safe on-disk name. Keeps ASCII alphanumerics,
  /// `.`, `_`, `-`; everything else becomes `_`. Guarantees the result
  /// is non-empty and ends with a recognisable extension.
  static String _sanitizeFilename(String input) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      final c = String.fromCharCode(rune);
      final isAllowed = (rune >= 0x30 && rune <= 0x39) || // 0-9
          (rune >= 0x41 && rune <= 0x5A) || // A-Z
          (rune >= 0x61 && rune <= 0x7A) || // a-z
          c == '.' ||
          c == '_' ||
          c == '-';
      buf.write(isAllowed ? c : '_');
    }
    final out = buf.toString();
    return out.isEmpty ? 'font.ttf' : out;
  }

  /// Parse the OpenType `name` table out of a raw TTF/OTF buffer and
  /// return the best available family-name string. Returns null if the
  /// buffer isn't recognisable as an uncompressed OpenType font.
  ///
  /// Preference, matching the JS auto-fill hook in the TTU WebView
  /// injection so Flutter-side and WebView-side imports end up with
  /// the same display name for the same file:
  ///   1. nameID 16 — Typographic Family Name (modern)
  ///   2. nameID  1 — Font Family Name        (legacy fallback)
  ///   3. nameID  4 — Full Font Name          (last resort)
  ///
  /// WOFF (zlib-compressed) and WOFF2 (Brotli-compressed) aren't
  /// supported — the caller falls back to the filename stem for those.
  static String? _extractFontName(Uint8List bytes) {
    try {
      final data = ByteData.sublistView(bytes);
      if (data.lengthInBytes < 12) return null;
      final numTables = data.getUint16(4);
      if (numTables < 1 || numTables > 100) return null;

      int nameOffset = -1;
      for (int i = 0; i < numTables; i++) {
        final rec = 12 + i * 16;
        if (rec + 16 > data.lengthInBytes) return null;
        final tag = String.fromCharCodes([
          data.getUint8(rec),
          data.getUint8(rec + 1),
          data.getUint8(rec + 2),
          data.getUint8(rec + 3),
        ]);
        if (tag == 'name') {
          nameOffset = data.getUint32(rec + 8);
          break;
        }
      }
      if (nameOffset < 0 || nameOffset + 6 > data.lengthInBytes) return null;

      final count = data.getUint16(nameOffset + 2);
      final stringOffset = data.getUint16(nameOffset + 4);
      final stringsStart = nameOffset + stringOffset;

      String? id16;
      String? id1;
      String? id4;
      for (int j = 0; j < count; j++) {
        final off = nameOffset + 6 + j * 12;
        if (off + 12 > data.lengthInBytes) break;
        final platformID = data.getUint16(off);
        final encodingID = data.getUint16(off + 2);
        final nameID = data.getUint16(off + 6);
        final length = data.getUint16(off + 8);
        final strOff = data.getUint16(off + 10);
        if (nameID != 16 && nameID != 1 && nameID != 4) continue;
        if (nameID == 16 && id16 != null) continue;
        if (nameID == 1 && id1 != null) continue;
        if (nameID == 4 && id4 != null) continue;
        final strStart = stringsStart + strOff;
        if (strStart + length > data.lengthInBytes) continue;

        String? value;
        if (platformID == 3 && (encodingID == 0 || encodingID == 1)) {
          // Windows UCS-2 BE
          final codes = <int>[];
          for (int k = 0; k < length; k += 2) {
            codes.add(data.getUint16(strStart + k));
          }
          value = String.fromCharCodes(codes);
        } else if (platformID == 0) {
          // Unicode platform — also UCS-2 BE
          final codes = <int>[];
          for (int k = 0; k < length; k += 2) {
            codes.add(data.getUint16(strStart + k));
          }
          value = String.fromCharCodes(codes);
        } else if (platformID == 1 && encodingID == 0) {
          // Mac Roman — approximate with Latin-1 for our purposes.
          final codes = <int>[];
          for (int k = 0; k < length; k++) {
            codes.add(data.getUint8(strStart + k));
          }
          value = String.fromCharCodes(codes);
        }
        if (value == null || value.isEmpty) continue;
        if (nameID == 16) id16 = value;
        if (nameID == 1) id1 = value;
        if (nameID == 4) id4 = value;
      }

      return id16 ?? id1 ?? id4;
    } catch (_) {
      return null;
    }
  }
}
