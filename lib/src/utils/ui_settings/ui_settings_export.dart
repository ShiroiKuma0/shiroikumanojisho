import 'dart:convert';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;

/// Category-split export/import of the app's settings (the flat Hive
/// `appModel` box), modelled on the Kōjiki export engine: JSON per
/// category, merge-never-clear import, device-local keys excluded in
/// both directions.
class UiSettingsExport {
  /// Export filename prefix — the latest-export scan filters on this.
  static const String exportPrefix = 'shiroikuma-jisho-ui_';

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

  /// Newest export file in [directory], or null.
  static File? latestExport(String directory) {
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
      if (!name.startsWith(exportPrefix) || !name.endsWith('.json')) {
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
    final file = File(path.join(
        directory, '$exportPrefix${appVersion}_$timestamp.json'));
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
