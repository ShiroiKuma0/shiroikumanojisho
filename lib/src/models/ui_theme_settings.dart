import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Preference-backed knobs for the app-wide black/yellow UI, surfaced on
/// the 白い熊 辞書 UI settings page and consumed by [AppModel.darkTheme].
///
/// Modelled on the sister repos' UI pages (kxkb/kojiki): every attribute
/// is a plain Hive-backed value with a black/yellow default, mutating
/// notifies the app model so the running theme re-renders immediately
/// (the whole app IS the live preview).
class UiThemeSettings {
  /// Wrap the given open preferences [box]; [notify] is invoked after
  /// every mutation to re-theme the app.
  UiThemeSettings({required Box box, required VoidCallback notify})
      : _box = box,
        _notify = notify;

  final Box _box;
  final VoidCallback _notify;

  /// Default recent-color seeds, most-recent-first: black, yellow,
  /// white, dim-yellow — the kxkb picker's seed set.
  static const List<int> _recentSeeds = [
    0xFF000000,
    0xFFFFFF00,
    0xFFFFFFFF,
    0xFFC8C800,
  ];

  // ─── Colors ───

  /// Panel/background color for every surface (scaffold, canvas, cards,
  /// dialogs, bars).
  int get backgroundColor =>
      _box.get('ui_background_color', defaultValue: 0xFF000000);
  set backgroundColor(int value) {
    _box.put('ui_background_color', value);
    _notify();
  }

  /// UI text color. Reuses the pre-existing `dark_theme_text_color` key
  /// (the old standalone picker wrote it) with the default flipped to
  /// the black/yellow identity.
  int get textColor =>
      _box.get('dark_theme_text_color', defaultValue: 0xFFFFFF00);
  set textColor(int value) {
    _box.put('dark_theme_text_color', value);
    _notify();
  }

  /// Icon color (toolbar and body icons).
  int get iconColor => _box.get('ui_icon_color', defaultValue: 0xFFFFFF00);
  set iconColor(int value) {
    _box.put('ui_icon_color', value);
    _notify();
  }

  /// Border color: dialog frames, pill button outlines, input focus.
  int get borderColor => _box.get('ui_border_color', defaultValue: 0xFFFFFF00);
  set borderColor(int value) {
    _box.put('ui_border_color', value);
    _notify();
  }

  /// Accent color: sliders, switches, selection highlights, primary.
  /// Defaults to the app's long-standing red accents.
  int get accentColor => _box.get('ui_accent_color', defaultValue: 0xFFFFFF00);
  set accentColor(int value) {
    _box.put('ui_accent_color', value);
    _notify();
  }

  // ─── Typography ───

  /// Font family name, '' = the target language's default family.
  /// External fonts registered via [loadExternalFonts] are addressed by
  /// their file basename.
  String get fontFamily => _box.get('ui_font_family', defaultValue: '');
  set fontFamily(String value) {
    _box.put('ui_font_family', value);
    _notify();
  }

  /// Global text scale, percent (50–200).
  int get fontScale => _box.get('ui_font_scale', defaultValue: 100);
  set fontScale(int value) {
    _box.put('ui_font_scale', value);
    _notify();
  }

  /// Base font weight, 100–900 in hundreds.
  int get fontWeight => _box.get('ui_font_weight', defaultValue: 400);
  set fontWeight(int value) {
    _box.put('ui_font_weight', value);
    _notify();
  }

  /// The [FontWeight] for [fontWeight].
  FontWeight get fontWeightValue =>
      FontWeight.values[(fontWeight ~/ 100 - 1).clamp(0, 8)];

  // ─── Shapes and borders ───

  /// Dialog frame border width, dp; 0 removes the border.
  double get dialogBorderWidth =>
      _box.get('ui_dialog_border_width', defaultValue: 2.0);
  set dialogBorderWidth(double value) {
    _box.put('ui_dialog_border_width', value);
    _notify();
  }

  /// Dialog corner radius, dp.
  double get dialogCornerRadius =>
      _box.get('ui_dialog_corner_radius', defaultValue: 16.0);
  set dialogCornerRadius(double value) {
    _box.put('ui_dialog_corner_radius', value);
    _notify();
  }

  /// Pill (TextButton) outline width, dp; 0 removes the outline.
  double get buttonBorderWidth =>
      _box.get('ui_button_border_width', defaultValue: 1.5);
  set buttonBorderWidth(double value) {
    _box.put('ui_button_border_width', value);
    _notify();
  }

  /// Pill (TextButton) corner radius, dp; high values read as stadium.
  double get buttonCornerRadius =>
      _box.get('ui_button_corner_radius', defaultValue: 24.0);
  set buttonCornerRadius(double value) {
    _box.put('ui_button_corner_radius', value);
    _notify();
  }

  // ─── Export directory ───

  /// Plain filesystem directory for UI-settings exports; '' = unset.
  /// Device-local by design — deliberately excluded from exports.
  String get exportDirectory =>
      _box.get('ui_export_directory', defaultValue: '');
  set exportDirectory(String value) {
    _box.put('ui_export_directory', value);
    _notify();
  }

  // ─── Recent colors (picker presets) ───

  /// Most-recent-first, deduped, max 8, seeded like the kxkb picker.
  List<int> get recentColors => List<int>.from(
      _box.get('ui_recent_colors', defaultValue: _recentSeeds));

  /// Record [color] as most recent.
  void pushRecentColor(int color) {
    final colors = recentColors;
    colors.remove(color);
    colors.insert(0, color);
    _box.put('ui_recent_colors', colors.take(8).toList());
  }

  // ─── External fonts ───

  /// Families registered by [loadExternalFonts] this session, by
  /// display name (file basename without extension).
  final List<String> externalFontFamilies = [];

  /// The on-device directory external fonts are imported into.
  static Future<Directory> fontsDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(appDocDir.path, 'fonts'));
  }

  /// Register every `.ttf`/`.otf` in the fonts directory with the
  /// engine, keyed by basename. Safe to call repeatedly (re-loading an
  /// already-registered family is a no-op at the engine level); bad
  /// files are skipped silently, matching the kxkb behavior.
  Future<void> loadExternalFonts() async {
    externalFontFamilies.clear();
    final dir = await fontsDirectory();
    if (!dir.existsSync()) {
      return;
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => const ['.ttf', '.otf']
            .contains(path.extension(file.path).toLowerCase()))
        .toList()
      ..sort((a, b) =>
          a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    for (final file in files) {
      final family = path.basenameWithoutExtension(file.path);
      try {
        final loader = FontLoader(family)
          ..addFont(Future.value(
              ByteData.sublistView(file.readAsBytesSync())));
        await loader.load();
        externalFontFamilies.add(family);
      } catch (e) {
        // Unparseable font: skip, keep the rest.
        debugPrint('loadExternalFonts: skipped $family: $e');
      }
    }
  }

  /// Copy [source] (a picked .ttf/.otf) into the fonts directory and
  /// register it. Returns the family name, or null if rejected.
  Future<String?> importFont(File source) async {
    final extension = path.extension(source.path).toLowerCase();
    if (!const ['.ttf', '.otf'].contains(extension)) {
      return null;
    }
    final dir = await fontsDirectory();
    dir.createSync(recursive: true);
    final target = File(path.join(dir.path, path.basename(source.path)));
    source.copySync(target.path);
    await loadExternalFonts();
    return path.basenameWithoutExtension(target.path);
  }
}
