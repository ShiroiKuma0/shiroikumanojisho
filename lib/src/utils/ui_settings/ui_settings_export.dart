import 'dart:convert';
import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Category-split export/import of the app's settings (the flat Hive
/// `appModel` box), modelled on the Kōjiki export engine: JSON per
/// category, merge-never-clear import, device-local keys excluded in
/// both directions.
class UiSettingsExport {
  /// Export filename prefix — the latest-export scan filters on this.
  static const String exportPrefix = 'shiroikuma-jisho-ui_';

  /// Generated-artifacts archive prefix (scanned-PDF OCR volumes,
  /// subtitle-OCR bitmap stores, imported fonts).
  static const String artifactsPrefix = 'shiroikuma-jisho-artifacts_';

  /// Cross-device bundle prefix (AppExportImport's naming).
  static const String bundlePrefix = 'shiroikuma-jisho-export_';

  /// Pre-2026-07-25 bundle prefix — still recognised on import so old
  /// bundles keep working.
  static const String legacyBundlePrefix = 'shiroikumanojisho_export_';

  /// App-documents subdirectories that count as generated artifacts.
  static const List<String> artifactDirectories = [
    'scannedPdf',
    'ocrSubtitles',
    'fonts',
  ];

  /// Keys that never travel: device-local paths and machine state.
  static const List<String> _excludedKeys = [
    'ui_export_directory',
    'custom_storage_path',
  ];

  static const List<String> _excludedPrefixes = [
    'last_picked_directory',
  ];

  /// Ordered category names with their key predicates. A key belongs
  /// to the FIRST matching category; the final category is the
  /// catch-all so every settable key travels.
  static final List<MapEntry<String, bool Function(String)>> categories = [
    MapEntry(
        'UI theme (colours · fonts · shapes)',
        (key) =>
            key.startsWith('ui_') ||
            key == 'dark_theme_text_color' ||
            key == 'is_dark_mode'),
    MapEntry(
        'Player & subtitles',
        (key) =>
            key.startsWith('player_') ||
            key.startsWith('subtitle') ||
            key.startsWith('secondary_subtitle') ||
            key.startsWith('blur_') ||
            key.contains('playback')),
    MapEntry(
        'Reader & audio toolbar',
        (key) =>
            key.contains('reader') ||
            key.contains('ttu') ||
            key.contains('toolbar') ||
            key.contains('mokuro') ||
            key.startsWith('pdf_')),
    MapEntry(
        'Dictionary & search',
        (key) =>
            key.contains('dictionary') ||
            key.contains('search') ||
            key.contains('index_prewarm') ||
            key.contains('maximum_terms')),
    MapEntry(
        'Creator & Anki',
        (key) =>
            key.contains('anki') ||
            key.contains('creator') ||
            key.contains('export_') ||
            key.contains('field') ||
            key.contains('enhancement')),
    MapEntry('Other settings', (key) => true),
  ];

  /// Split every exportable key in [box] into ordered categories.
  static Map<String, Map<String, dynamic>> categorise(Box box) {
    final result = <String, Map<String, dynamic>>{
      for (final category in categories) category.key: <String, dynamic>{},
    };
    for (final key in box.keys) {
      final keyName = key.toString();
      if (_excludedKeys.contains(keyName) ||
          _excludedPrefixes.any(keyName.startsWith)) {
        continue;
      }
      final value = box.get(key);
      if (!_isJsonSafe(value)) {
        continue;
      }
      for (final category in categories) {
        if (category.value(keyName)) {
          result[category.key]![keyName] = value;
          break;
        }
      }
    }
    return result;
  }

  static bool _isJsonSafe(dynamic value) {
    try {
      jsonEncode(value);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Newest settings-export file in [directory], or null.
  static File? latestExport(String directory) =>
      latestMatching(directory, prefix: exportPrefix, suffix: '.json');

  /// Newest export of ANY era in [directory]: the current
  /// `shiroikuma-jisho_<ts>.zip`, or legacy `shiroikuma-jisho-ui_`
  /// zip/json. Null when none.
  static File? latestAnyExport(String directory) {
    File? newest;
    for (final candidate in [
      latestMatching(directory,
          prefix: 'shiroikuma-jisho_', suffix: '.zip'),
      latestMatching(directory, prefix: exportPrefix, suffix: '.zip'),
      latestMatching(directory, prefix: exportPrefix, suffix: '.json'),
    ]) {
      if (candidate == null) {
        continue;
      }
      if (newest == null ||
          candidate.statSync().modified
              .isAfter(newest.statSync().modified)) {
        newest = candidate;
      }
    }
    return newest;
  }

  /// Newest artifacts archive in [directory], or null.
  static File? latestArtifacts(String directory) =>
      latestMatching(directory, prefix: artifactsPrefix, suffix: '.zip');

  /// Newest cross-device bundle in [directory] (either naming era),
  /// or null.
  static File? latestBundle(String directory) {
    final current =
        latestMatching(directory, prefix: bundlePrefix, suffix: '.zip');
    final legacy = latestMatching(directory,
        prefix: legacyBundlePrefix, suffix: '.zip');
    if (current == null) {
      return legacy;
    }
    if (legacy == null) {
      return current;
    }
    return current.statSync().modified.isAfter(legacy.statSync().modified)
        ? current
        : legacy;
  }

  /// Newest file in [directory] matching [prefix]/[suffix], or null.
  static File? latestMatching(String directory,
      {required String prefix, required String suffix}) {
    if (directory.isEmpty) {
      return null;
    }
    final dir = Directory(directory);
    if (!dir.existsSync()) {
      return null;
    }
    File? newest;
    DateTime newestTime = DateTime.fromMillisecondsSinceEpoch(0);
    for (final entity in dir.listSync()) {
      if (entity is! File) {
        continue;
      }
      final name = path.basename(entity.path);
      if (!name.startsWith(prefix) || !name.endsWith(suffix)) {
        continue;
      }
      final modified = entity.statSync().modified;
      if (modified.isAfter(newestTime)) {
        newestTime = modified;
        newest = entity;
      }
    }
    return newest;
  }

  /// Zip the generated in-app artifacts ([artifactDirectories] under
  /// app documents — OCR'd PDF volumes with their corrections, subtitle
  /// OCR bitmap stores, imported fonts) into [directory]. Returns the
  /// archive, or null when there is nothing to export.
  static Future<File?> exportArtifacts({
    required String directory,
    void Function(String)? onProgress,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final files = <File>[];
    for (final name in artifactDirectories) {
      final dir = Directory(path.join(appDocDir.path, name));
      if (!dir.existsSync()) {
        continue;
      }
      files.addAll(dir.listSync(recursive: true).whereType<File>());
    }
    if (files.isEmpty) {
      return null;
    }
    final timestamp =
        DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final zip =
        File(path.join(directory, '$artifactsPrefix$timestamp.zip'));
    await ZipFile.createFromFiles(
      sourceDir: appDocDir,
      files: files,
      zipFile: zip,
    );
    return zip;
  }

  /// Extract an artifacts archive back into app documents, overwriting
  /// same-named files (merge — nothing else is deleted).
  static Future<void> importArtifacts({
    required File archive,
    void Function(String)? onProgress,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    await ZipFile.extractToDirectory(
      zipFile: archive,
      destinationDir: appDocDir,
      onExtracting: (entry, progress) {
        onProgress?.call('${progress.toStringAsFixed(0)}%');
        return ZipFileOperation.includeItem;
      },
    );
  }

  /// Write the selected [selectedCategories] of [box] to a timestamped
  /// JSON file in [directory]. Returns the created file.
  static File exportTo({
    required Box box,
    required String directory,
    required Set<String> selectedCategories,
    required String appVersion,
  }) {
    final all = categorise(box);
    final payload = <String, dynamic>{
      'format': 'shiroikuma-jisho-ui-export',
      'version': 1,
      'app': appVersion,
      'createdTs': DateTime.now().toIso8601String(),
      'categories': {
        for (final entry in all.entries)
          if (selectedCategories.contains(entry.key)) entry.key: entry.value,
      },
    };
    final timestamp =
        DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final file =
        File(path.join(directory, '$exportPrefix$timestamp.json'));
    file.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(payload));
    return file;
  }

  /// Merge the selected categories of [file] into [box]. Keys absent
  /// from the export keep their current values; unknown categories are
  /// ignored. Returns a per-category restored-key-count summary.
  static Map<String, int> importFrom({
    required Box box,
    required File file,
    required Set<String> selectedCategories,
  }) {
    final payload = jsonDecode(file.readAsStringSync());
    if (payload is! Map || payload['format'] != 'shiroikuma-jisho-ui-export') {
      throw const FormatException(
          'No 白い熊 辞書 settings export found in that file.');
    }
    final categoriesJson = payload['categories'] as Map<String, dynamic>;
    final summary = <String, int>{};
    for (final entry in categoriesJson.entries) {
      if (!selectedCategories.contains(entry.key)) {
        continue;
      }
      var count = 0;
      for (final keyValue in (entry.value as Map<String, dynamic>).entries) {
        if (_excludedKeys.contains(keyValue.key) ||
            _excludedPrefixes.any(keyValue.key.startsWith)) {
          continue;
        }
        box.put(keyValue.key, keyValue.value);
        count++;
      }
      summary[entry.key] = count;
    }
    return summary;
  }
}
