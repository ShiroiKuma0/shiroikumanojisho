import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async_zip/async_zip.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:shiroikumanojisho/src/utils/ui_settings/ui_settings_export.dart';

/// One exportable category of the 保存復元 state-export contract.
class StateCategory {
  /// Define a category.
  const StateCategory(this.id, this.label, {this.parentId});

  /// Stable id — the ZIP entry name and the `items` token.
  final String id;

  /// Display label for pickers (ours and 自由作業盤's).
  final String label;

  /// Parent id for sub-options, null for top-level.
  final String? parentId;
}

/// The single-ZIP state export/import core — the one implementation
/// behind both the Export/Import panel and the headless 保存復元
/// automation receiver (the contract forbids duplicating export logic).
///
/// ZIP layout (family pattern): `manifest.json` +
/// one `<id>.json` per settings category (plain key→value maps) +
/// `artifacts/<dir>/...` file entries for the artifact sub-options.
class StateExport {
  /// Format tag in the manifest.
  static const String format = 'shiroikuma-jisho-state';

  /// Export filename prefix: the export is ALWAYS one ZIP named
  /// `shiroikuma-jisho_<yyyy-MM-dd_HH-mm-ss>.zip` (no version).
  static const String filePrefix = 'shiroikuma-jisho_';

  /// Entry name of an embedded cross-device bundle.
  static const String bundleEntry = 'app_data.zip';

  /// Manifest schema version.
  static const int version = 1;

  /// Artifact sub-option id → app-documents directory.
  static const Map<String, String> artifactDirs = {
    'artifacts.pdf': 'scannedPdf',
    'artifacts.ocr': 'ocrSubtitles',
    'artifacts.fonts': 'fonts',
  };

  /// The category table: six settings categories (ids matching the
  /// ZIP entry names), then the artifacts parent with three
  /// independently-selectable children.
  static const List<StateCategory> categories = [
    StateCategory('ui_theme', 'UI theme (colours · fonts · shapes)'),
    StateCategory('player', 'Player & subtitles'),
    StateCategory('reader', 'Reader & audio toolbar'),
    StateCategory('dictionary', 'Dictionary & search'),
    StateCategory('creator', 'Creator & Anki'),
    StateCategory('other', 'Other settings'),
    StateCategory('artifacts', 'Generated artifacts'),
    StateCategory('artifacts.pdf', 'Scanned-PDF OCR volumes',
        parentId: 'artifacts'),
    StateCategory('artifacts.ocr', 'Subtitle OCR bitmaps',
        parentId: 'artifacts'),
    StateCategory('artifacts.fonts', 'Imported fonts',
        parentId: 'artifacts'),
  ];

  /// Ids of the settings categories, in [UiSettingsExport.categories]
  /// order (the two tables are index-aligned).
  static List<String> get settingsIds => [
        for (final category in categories)
          if (category.parentId == null && category.id != 'artifacts')
            category.id,
      ];

  /// Every id that carries data (the artifacts parent has no own
  /// data — per the contract, the parent id alone means "own data
  /// only", which for us is empty).
  static Set<String> get allIds => {
        ...settingsIds,
        ...artifactDirs.keys,
      };

  /// The `id<TAB>label[<TAB>parent]` listing for LIST_CATEGORIES.
  static String categoriesListing() => categories
      .map((category) => category.parentId == null
          ? '${category.id}\t${category.label}'
          : '${category.id}\t${category.label}\t${category.parentId}')
      .join('\n');

  /// Validate an `items` CSV; returns the unknown tokens (empty = ok).
  static List<String> unknownItems(String items) => items
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .where((item) =>
          !allIds.contains(item) && item != 'artifacts')
      .toList();

  /// Resolve an `items` CSV to concrete data-carrying ids.
  /// Absent/empty = everything.
  static Set<String> resolveItems(String? items) {
    if (items == null || items.trim().isEmpty) {
      return allIds;
    }
    final tokens = items
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet();
    // The artifacts parent alone contributes no data of its own.
    tokens.remove('artifacts');
    return tokens;
  }

  /// Run the export: write one ZIP into [directory] and return it.
  /// [onProgress] receives (text, current, total, unit) with real
  /// counts, already throttle-friendly (call sites throttle).
  static Future<File> run({
    required Box box,
    required Set<String> ids,
    required String directory,
    required String appVersion,
    File? embedBundle,
    void Function(String text, int current, int total, String unit)?
        onProgress,
  }) async {
    Directory(directory).createSync(recursive: true);
    final timestamp =
        DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final zipTarget =
        File(path.join(directory, '$filePrefix$timestamp.zip'));

    final selectedSettings =
        settingsIds.where(ids.contains).toList();
    final selectedArtifactDirs = [
      for (final entry in artifactDirs.entries)
        if (ids.contains(entry.key)) entry,
    ];

    // Enumerate artifact files up front for a real total.
    final appDocDir = await getApplicationDocumentsDirectory();
    final artifactFiles = <MapEntry<String, File>>[];
    for (final entry in selectedArtifactDirs) {
      final dir = Directory(path.join(appDocDir.path, entry.value));
      if (!dir.existsSync()) {
        continue;
      }
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        final relative =
            path.relative(file.path, from: appDocDir.path);
        artifactFiles.add(MapEntry('artifacts/$relative', file));
      }
    }

    final writer = ZipFileWriter();
    try {
      await writer.create(zipTarget);

      // Manifest + settings categories.
      final byLabel = UiSettingsExport.categorise(box);
      final labels = UiSettingsExport.categories;
      final manifest = {
        'format': format,
        'version': version,
        'app': 'shiroikuma.jisho',
        'appVersion': appVersion,
        'createdTs': DateTime.now().toIso8601String(),
        'categories': [
          ...selectedSettings,
          for (final e in selectedArtifactDirs) e.key,
          if (embedBundle != null) 'app_data',
        ],
      };
      await writer.writeData('manifest.json',
          Uint8List.fromList(utf8.encode(jsonEncode(manifest))));

      for (var i = 0; i < selectedSettings.length; i++) {
        final id = selectedSettings[i];
        final labelIndex = settingsIds.indexOf(id);
        final data = byLabel[labels[labelIndex].key] ?? {};
        onProgress?.call('区分 ${i + 1}/${selectedSettings.length} — $id',
            i + 1, selectedSettings.length, '区分');
        await writer.writeData('$id.json',
            Uint8List.fromList(utf8.encode(jsonEncode(data))));
      }

      // Artifact files with real counts.
      for (var i = 0; i < artifactFiles.length; i++) {
        onProgress?.call(
            'ファイル ${i + 1}/${artifactFiles.length}',
            i + 1,
            artifactFiles.length,
            'ファイル');
        await writer.writeFile(
            artifactFiles[i].key, artifactFiles[i].value);
      }

      // Embedded cross-device bundle: stored uncompressed — it is
      // already a DEFLATE zip; recompressing would double the time
      // for zero gain.
      if (embedBundle != null) {
        final size = embedBundle.lengthSync();
        onProgress?.call('連携データ ${humanSize(size)}', size, size,
            'bytes');
        await writer.writeFile(bundleEntry, embedBundle,
            compress: false);
      }
    } finally {
      await writer.close();
    }
    return zipTarget;
  }

  /// Import selected [ids] from a state ZIP: settings merge per key
  /// (never clear), artifact entries overwrite same-named files.
  /// Returns id → restored count (keys or files).
  static Future<Map<String, int>> import({
    required Box box,
    required File archive,
    required Set<String> ids,
  }) async {
    final summary = <String, int>{};
    final appDocDir = await getApplicationDocumentsDirectory();
    final reader = ZipFileReader();
    try {
      await reader.open(archive);
      final entries = await reader.entries();
      final names = {for (final entry in entries) entry.name};
      if (!names.contains('manifest.json')) {
        throw const FormatException(
            'No 白い熊 辞書 state export found in that file.');
      }
      for (final id in settingsIds.where(ids.contains)) {
        if (!names.contains('$id.json')) {
          continue;
        }
        final temp = File(path.join(
            appDocDir.path, 'stateImport_$id.json'));
        await reader.readToFile('$id.json', temp);
        final data =
            jsonDecode(temp.readAsStringSync()) as Map<String, dynamic>;
        temp.deleteSync();
        var count = 0;
        for (final entry in data.entries) {
          box.put(entry.key, entry.value);
          count++;
        }
        summary[id] = count;
      }
      for (final artifactEntry in artifactDirs.entries.where(
          (entry) => ids.contains(entry.key))) {
        final prefix = 'artifacts/${artifactEntry.value}/';
        var count = 0;
        for (final entry in entries) {
          if (entry.isDir || !entry.name.startsWith(prefix)) {
            continue;
          }
          final target = File(path.join(appDocDir.path,
              entry.name.substring('artifacts/'.length)));
          target.parent.createSync(recursive: true);
          await reader.readToFile(entry.name, target);
          count++;
        }
        summary[artifactEntry.key] = count;
      }
    } finally {
      await reader.close();
    }
    return summary;
  }

  /// Human size for the reply (`4.6 MB`, `1.20 GB`).
  static String humanSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}
