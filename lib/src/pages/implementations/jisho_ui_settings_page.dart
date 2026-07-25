import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:restart_app/restart_app.dart';

import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/src/utils/misc/app_export_import.dart';
import 'package:shiroikumanojisho/src/utils/ui_settings/ui_settings_export.dart';

/// The 白い熊 辞書 UI settings page: every attribute of the black/yellow
/// UI — colours, fonts, sizes, borders — settable with live preview
/// (the running theme re-renders on every tick), plus the top
/// Export/Import section. Layout and visual language follow the
/// sister repos: kxkb page structure (bold underlined headings with
/// word-width underlines, thin hairline spacers, deep indents, tight
/// rows), Kōjiki export/import flow, Arcanechat pill button row.
class JishoUiSettingsPage extends BasePage {
  /// Create an instance of this page.
  const JishoUiSettingsPage({super.key});

  @override
  BasePageState createState() => _JishoUiSettingsPageState();
}

class _JishoUiSettingsPageState extends BasePageState<JishoUiSettingsPage> {
  UiThemeSettings get ui => appModel.uiTheme;

  /// kxkb indent ladder.
  static const double _insetHeading = 36;
  static const double _insetSubHeading = 54;
  static const double _insetRow = 72;
  static const double _insetRowL2 = 90;

  static const Color _warnRed = Color(0xFFFF5252);

  Color get _accent => Color(ui.textColor);
  Color get _dim => _accent.withValues(alpha: 0.7);
  Color get _border => Color(ui.borderColor);

  /// Latest-export display, refreshed on open and after exports.
  File? _latestExport;

  @override
  void initState() {
    super.initState();
    _refreshLatestExport();
  }

  void _refreshLatestExport() {
    setState(() {
      _latestExport = UiSettingsExport.latestExport(ui.exportDirectory);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('白い熊 辞書 UI'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionHeader('Export / Import', first: true),
            _buildDirectoryBox(insetLeft: _insetRow),
            _buildLatestExportLine(insetLeft: _insetRow),
            _row(
              title: 'Export / Import…',
              summary:
                  'Save or load every setting — colours, fonts, player, '
                  'reader, dictionary — as selectable categories.',
              onTap: _showExportImportPanel,
            ),
            _sectionHeader('Colours'),
            _colorRow('Background', () => ui.backgroundColor,
                (color) => ui.backgroundColor = color),
            _colorRow(
                'Text', () => ui.textColor, (color) => ui.textColor = color),
            _colorRow(
                'Icons', () => ui.iconColor, (color) => ui.iconColor = color),
            _colorRow('Borders', () => ui.borderColor,
                (color) => ui.borderColor = color),
            _colorRow('Accent (sliders · switches)', () => ui.accentColor,
                (color) => ui.accentColor = color),
            _sectionHeader('Typography'),
            _row(
              title: 'Font',
              summary: ui.fontFamily.isEmpty ? 'System default' : ui.fontFamily,
              onTap: _showFontPicker,
            ),
            _sliderRow(
              title: 'Weight',
              inset: _insetRow,
              value: ui.fontWeight.toDouble(),
              min: 100,
              max: 900,
              divisions: 8,
              display: (value) => value.round().toString(),
              onChanged: (value) =>
                  ui.fontWeight = (value / 100).round() * 100,
            ),
            _sliderRow(
              title: 'Text size (%)',
              inset: _insetRow,
              value: ui.fontScale.toDouble(),
              min: 50,
              max: 200,
              display: (value) => value.round().toString(),
              onChanged: (value) => ui.fontScale = value.round(),
            ),
            _buildFontSample(),
            _sectionHeader('Shapes & borders'),
            _subHeader('Dialogs'),
            _sliderRow(
              title: 'Border width',
              inset: _insetRowL2,
              value: ui.dialogBorderWidth,
              min: 0,
              max: 8,
              display: (value) => value.toStringAsFixed(1),
              onChanged: (value) =>
                  ui.dialogBorderWidth = (value * 2).round() / 2,
            ),
            _sliderRow(
              title: 'Corner radius',
              inset: _insetRowL2,
              value: ui.dialogCornerRadius,
              min: 0,
              max: 24,
              display: (value) => value.round().toString(),
              onChanged: (value) => ui.dialogCornerRadius = value.roundToDouble(),
            ),
            _subHeader('Buttons'),
            _sliderRow(
              title: 'Border width',
              inset: _insetRowL2,
              value: ui.buttonBorderWidth,
              min: 0,
              max: 8,
              display: (value) => value.toStringAsFixed(1),
              onChanged: (value) =>
                  ui.buttonBorderWidth = (value * 2).round() / 2,
            ),
            _sliderRow(
              title: 'Corner radius',
              inset: _insetRowL2,
              value: ui.buttonCornerRadius,
              min: 0,
              max: 50,
              display: (value) => value.round().toString(),
              onChanged: (value) =>
                  ui.buttonCornerRadius = value.roundToDouble(),
            ),
            _buildShapeSample(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ─── kxkb building blocks ───

  Widget _sectionHeader(String title, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!first)
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 10),
              color: _accent.withValues(alpha: 0.35),
            ),
          Padding(
            padding: const EdgeInsets.only(
                left: _insetHeading, top: 8, bottom: 2),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _accent,
                    ),
                  ),
                  Container(
                    height: 2.5,
                    margin: const EdgeInsets.only(top: 2),
                    color: _accent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          left: _insetSubHeading, top: 10, bottom: 2),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _accent,
              ),
            ),
            Container(
              height: 1.5,
              margin: const EdgeInsets.only(top: 2),
              color: _accent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row({
    required String title,
    String? summary,
    Widget? trailing,
    VoidCallback? onTap,
    double inset = _insetRow,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            EdgeInsets.only(left: inset, right: 16, top: 5, bottom: 5),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 16, color: _accent)),
                  if (summary != null)
                    Text(summary,
                        style: TextStyle(fontSize: 13, color: _dim)),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _sliderRow({
    required String title,
    required double inset,
    required double value,
    required double min,
    required double max,
    required String Function(double) display,
    required ValueChanged<double> onChanged,
    int? divisions,
  }) {
    return Padding(
      padding: EdgeInsets.only(left: inset, right: 16, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: _accent)),
          Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    // Tight slider: no huge default paddings.
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: value.clamp(min, max),
                    min: min,
                    max: max,
                    divisions: divisions,
                    onChanged: (newValue) {
                      onChanged(newValue);
                      setState(() {});
                    },
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: Text(
                  display(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 15, color: _accent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Colour rows and picker ───

  String _hex(int color) =>
      '#${color.toRadixString(16).toUpperCase().padLeft(8, '0')}';

  Widget _colorRow(
      String title, int Function() getter, ValueChanged<int> setter) {
    return _row(
      title: title,
      summary: _hex(getter()),
      trailing: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Color(getter()),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _border, width: 1.5),
        ),
      ),
      onTap: () async {
        await showDialog(
          context: context,
          builder: (context) => _RgbaColorPickerDialog(
            appModel: appModel,
            initial: getter(),
            onChanged: (color) {
              setter(color);
              setState(() {});
            },
          ),
        );
        setState(() {});
      },
    );
  }

  // ─── Typography ───

  Widget _buildFontSample() {
    return Padding(
      padding: const EdgeInsets.only(
          left: _insetRow, right: 16, top: 6, bottom: 4),
      child: Text(
        'AaIiMmOoQqWw 012 白い熊相撲道 あいうえお',
        style: TextStyle(
          fontSize: 16 * ui.fontScale / 100,
          fontFamily: ui.fontFamily.isEmpty ? null : ui.fontFamily,
          fontWeight: ui.fontWeightValue,
          color: _accent,
        ),
      ),
    );
  }

  void _showFontPicker() async {
    await showDialog(
      context: context,
      builder: (context) {
        final families = ['', ...ui.externalFontFamilies];
        return AlertDialog(
          title: const Text('Font'),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final family in families)
                  InkWell(
                    onTap: () {
                      ui.fontFamily = family;
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Text(
                        '${ui.fontFamily == family ? '✓  ' : ''}'
                        '${family.isEmpty ? 'System default' : family}',
                        style: TextStyle(
                          fontSize: 18,
                          color: _accent,
                          fontFamily: family.isEmpty ? null : family,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _importFont,
              child: const Text('Import font…'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
    setState(() {});
  }

  void _importFont() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    final pickedPath = picked?.files.single.path;
    if (pickedPath == null) {
      return;
    }
    final family = await ui.importFont(File(pickedPath));
    if (family == null) {
      Fluttertoast.showToast(msg: 'Not a .ttf/.otf font file.');
      return;
    }
    ui.fontFamily = family;
    Fluttertoast.showToast(msg: 'Imported "$family"');
    if (mounted) {
      // Rebuild the open font list with the new entry.
      Navigator.pop(context);
      _showFontPicker();
    }
  }

  // ─── Shapes preview ───

  Widget _buildShapeSample() {
    return Padding(
      padding: const EdgeInsets.only(
          left: _insetRow, right: 16, top: 8, bottom: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Color(ui.backgroundColor),
              borderRadius: BorderRadius.circular(ui.dialogCornerRadius),
              border: ui.dialogBorderWidth <= 0
                  ? null
                  : Border.all(
                      color: _border, width: ui.dialogBorderWidth),
            ),
            child: Text('Dialog',
                style: TextStyle(fontSize: 13, color: _accent)),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {},
            child: const Text('Button'),
          ),
        ],
      ),
    );
  }

  // ─── Export / Import ───

  Widget _buildDirectoryBox({required double insetLeft}) {
    final directory = ui.exportDirectory;
    final isSet = directory.isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(
          left: insetLeft, right: 16, top: 6, bottom: 6),
      child: InkWell(
        onTap: _pickExportDirectory,
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _border, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export directory (tap to choose)',
                  style: TextStyle(fontSize: 12, color: _accent)),
              Text(
                isSet ? directory : 'Not set — tap to choose a directory',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isSet ? _accent : _warnRed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLatestExportLine({required double insetLeft}) {
    final directory = ui.exportDirectory;
    String text;
    bool warn;
    if (directory.isEmpty) {
      text = 'No directory set yet — pick one to enable one-tap export.';
      warn = true;
    } else if (_latestExport == null) {
      text = 'No export in this directory yet.';
      warn = true;
    } else {
      final modified = _latestExport!.statSync().modified;
      text = 'Last export: '
          '${DateFormat('yyyy-MM-dd HH:mm:ss').format(modified)}';
      warn = false;
    }
    return Padding(
      padding: EdgeInsets.only(left: insetLeft + 2, right: 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: warn ? _warnRed : _accent.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  void _pickExportDirectory() async {
    final directory = await FilePicker.getDirectoryPath(
      initialDirectory:
          ui.exportDirectory.isEmpty ? null : ui.exportDirectory,
    );
    if (directory == null) {
      return;
    }
    ui.exportDirectory = directory;
    _refreshLatestExport();
  }

  void _showExportImportPanel() async {
    await showDialog(
      context: context,
      builder: (context) => _ExportImportPanel(
        appModel: appModel,
        onDirectoryChanged: _refreshLatestExport,
        onExported: _refreshLatestExport,
        closeSettingsPage: () {
          if (mounted) {
            Navigator.of(this.context).pop();
          }
        },
      ),
    );
    _refreshLatestExport();
  }
}

/// The Kōjiki-style Export/Import panel: bordered black box, directory
/// box, latest-export status, Select all + category checkboxes, and the
/// Arcanechat pill row (Cancel left; Import · Export right).
class _ExportImportPanel extends StatefulWidget {
  const _ExportImportPanel({
    required this.appModel,
    required this.onDirectoryChanged,
    required this.onExported,
    required this.closeSettingsPage,
  });

  final AppModel appModel;
  final VoidCallback onDirectoryChanged;
  final VoidCallback onExported;
  final VoidCallback closeSettingsPage;

  @override
  State<_ExportImportPanel> createState() => _ExportImportPanelState();
}

class _ExportImportPanelState extends State<_ExportImportPanel> {
  UiThemeSettings get ui => widget.appModel.uiTheme;

  static const Color _warnRed = Color(0xFFFF5252);

  Color get _accent => Color(ui.textColor);
  Color get _border => Color(ui.borderColor);

  static const String _categoryAppData = 'App data (cross-device bundle)';
  static const String _categoryArtifacts =
      'Generated artifacts (OCR volumes · bitmaps · fonts)';

  /// Settings categories all on; artifacts on; the heavyweight
  /// cross-device bundle deliberately OFF by default.
  late final Set<String> _selected = {
    for (final category in UiSettingsExport.categories) category.key,
    _categoryArtifacts,
  };

  List<String> get _allCategories => [
        for (final category in UiSettingsExport.categories) category.key,
        _categoryAppData,
        _categoryArtifacts,
      ];

  bool get _allSelected => _selected.length == _allCategories.length;

  Set<String> get _selectedSettings => {
        for (final category in UiSettingsExport.categories)
          if (_selected.contains(category.key)) category.key,
      };

  @override
  Widget build(BuildContext context) {
    final latest = UiSettingsExport.latestExport(ui.exportDirectory);
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'Export / Import — 白い熊 辞書',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _accent,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Save or load every setting — colours, fonts, player, '
                'reader, dictionary — as selectable categories.',
                style: TextStyle(
                    fontSize: 13,
                    color: _accent.withValues(alpha: 0.85)),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final directory = await FilePicker.getDirectoryPath(
                    initialDirectory: ui.exportDirectory.isEmpty
                        ? null
                        : ui.exportDirectory,
                  );
                  if (directory != null) {
                    ui.exportDirectory = directory;
                    widget.onDirectoryChanged();
                    setState(() {});
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border, width: 2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Export directory (tap to choose)',
                          style:
                              TextStyle(fontSize: 12, color: _accent)),
                      Text(
                        ui.exportDirectory.isEmpty
                            ? 'Not set — tap to choose a directory'
                            : ui.exportDirectory,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ui.exportDirectory.isEmpty
                              ? _warnRed
                              : _accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                ui.exportDirectory.isEmpty
                    ? 'No directory set yet — pick one to enable '
                        'one-tap export.'
                    : latest == null
                        ? 'No export in this directory yet.'
                        : 'Last export: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(latest.statSync().modified)}',
                style: TextStyle(
                  fontSize: 14,
                  color: ui.exportDirectory.isEmpty || latest == null
                      ? _warnRed
                      : _accent.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Container(height: 1, color: _accent.withValues(alpha: 0.4)),
              _checkboxRow(
                label: 'Select all',
                bold: true,
                value: _allSelected,
                onChanged: (checked) {
                  setState(() {
                    _selected.clear();
                    if (checked ?? false) {
                      _selected.addAll(_allCategories);
                    }
                  });
                },
              ),
              for (final category in _allCategories)
                _checkboxRow(
                  label: category,
                  value: _selected.contains(category),
                  onChanged: (checked) {
                    setState(() {
                      if (checked ?? false) {
                        _selected.add(category);
                      } else {
                        _selected.remove(category);
                      }
                    });
                  },
                ),
              const SizedBox(height: 8),
              Container(height: 1, color: _accent.withValues(alpha: 0.4)),
              const SizedBox(height: 14),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _onImport,
                    child: const Text('Import'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _onExport,
                    child: const Text('Export'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _checkboxRow({
    required String label,
    required bool value,
    required ValueChanged<bool?> onChanged,
    bool bold = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: value,
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: _accent,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onExport() async {
    if (_selected.isEmpty) {
      Fluttertoast.showToast(msg: 'Select at least one category.');
      return;
    }
    if (ui.exportDirectory.isEmpty) {
      Fluttertoast.showToast(
          msg: 'Set an export directory first (tap the box above).');
      return;
    }
    try {
      final saved = <String>[];
      if (_selectedSettings.isNotEmpty) {
        final file = UiSettingsExport.exportTo(
          box: widget.appModel.preferences,
          directory: ui.exportDirectory,
          selectedCategories: _selectedSettings,
          appVersion: widget.appModel.packageInfo.version,
        );
        saved.add(path.basename(file.path));
      }
      if (_selected.contains(_categoryArtifacts)) {
        final zip = await UiSettingsExport.exportArtifacts(
          directory: ui.exportDirectory,
          appVersion: widget.appModel.packageInfo.version,
        );
        saved.add(zip == null
            ? 'Artifacts: nothing to export yet.'
            : path.basename(zip.path));
      }
      if (_selected.contains(_categoryAppData)) {
        // The heavyweight bundle drives its own progress dialog;
        // quiet suppresses its success dialog so ours runs the chain.
        final bundle = await AppExportImport.exportData(
          appModel: widget.appModel,
          context: context,
          outputDirectory: ui.exportDirectory,
          quiet: true,
        );
        if (bundle == null) {
          // Its own failure dialog already showed; keep the panel.
          return;
        }
        saved.add(path.basename(bundle.path));
      }
      widget.onExported();
      if (!mounted) {
        return;
      }
      // Success dialog; OK closes the chain: info → panel → page.
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            '✓ Export complete',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.bold, color: _accent),
          ),
          content: Text(
            'Saved:\n${saved.join('\n')}',
            style: TextStyle(fontSize: 14, color: _accent),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.pop(context);
      }
      widget.closeSettingsPage();
    } catch (e) {
      Fluttertoast.showToast(msg: 'Export failed: $e');
    }
  }

  void _onImport() async {
    if (_selected.isEmpty) {
      Fluttertoast.showToast(msg: 'Select at least one category.');
      return;
    }
    // Choose among the directory's exports, newest first; fall back to
    // a file picker when no directory is set. Only needed when settings
    // categories are ticked — artifacts/bundle use latest-of-kind.
    File? file;
    if (_selectedSettings.isEmpty) {
      // No settings JSON wanted.
    } else if (ui.exportDirectory.isNotEmpty) {
      final dir = Directory(ui.exportDirectory);
      final candidates = !dir.existsSync()
          ? <File>[]
          : (dir
              .listSync()
              .whereType<File>()
              .where((f) =>
                  path.basename(f.path).startsWith(
                      UiSettingsExport.exportPrefix) &&
                  f.path.endsWith('.json'))
              .toList()
            ..sort((a, b) => b
                .statSync()
                .modified
                .compareTo(a.statSync().modified)));
      if (candidates.isEmpty && _selected.length == _selectedSettings.length) {
        Fluttertoast.showToast(msg: 'No export in this directory yet.');
        return;
      }
      if (candidates.isEmpty) {
        // Settings JSON missing but artifacts/bundle still wanted.
        file = null;
      } else
      file = await showDialog<File>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import which export?'),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final candidate in candidates)
                  InkWell(
                    onTap: () => Navigator.pop(dialogContext, candidate),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Text(
                        path.basename(candidate.path),
                        style: TextStyle(fontSize: 14, color: _accent),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } else {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      final pickedPath = picked?.files.single.path;
      if (pickedPath != null) {
        file = File(pickedPath);
      }
    }
    final wantsSettings = _selectedSettings.isNotEmpty;
    if (wantsSettings && file == null) {
      return;
    }

    final summary = <String, int>{};
    try {
      if (wantsSettings && file != null) {
        summary.addAll(UiSettingsExport.importFrom(
          box: widget.appModel.preferences,
          file: file,
          selectedCategories: _selectedSettings,
        ));
      }
      if (_selected.contains(_categoryArtifacts)) {
        final archive =
            UiSettingsExport.latestArtifacts(ui.exportDirectory);
        if (archive == null) {
          summary[_categoryArtifacts] = 0;
        } else {
          await UiSettingsExport.importArtifacts(archive: archive);
          summary[_categoryArtifacts] = 1;
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Import failed: $e');
      return;
    }
    await ui.loadExternalFonts();
    widget.appModel.notifyListeners();

    // The cross-device bundle import runs LAST: it confirms, replaces
    // the app's data wholesale, and exits the app itself — no chain
    // to close after it.
    if (_selected.contains(_categoryAppData)) {
      final bundle = UiSettingsExport.latestBundle(ui.exportDirectory);
      if (bundle == null) {
        Fluttertoast.showToast(
            msg: 'No cross-device bundle in this directory yet.');
        return;
      }
      if (!mounted) {
        return;
      }
      await AppExportImport.importData(
        appModel: widget.appModel,
        context: context,
        bundle: bundle,
      );
      return;
    }

    if (!mounted) {
      return;
    }
    final summaryText = summary.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join('\n');
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          '✓ Import — 100% success',
          style: TextStyle(
              fontSize: 19, fontWeight: FontWeight.bold, color: _accent),
        ),
        content: Text(
          'Restored:\n\n$summaryText\n\nRestart to apply everything.',
          style: TextStyle(fontSize: 14, color: _accent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Later'),
          ),
          TextButton(
            onPressed: Restart.restartApp,
            child: const Text('Restart now'),
          ),
        ],
      ),
    );
    // "Later": close the chain — panel, then settings page.
    if (mounted) {
      Navigator.pop(context);
    }
    widget.closeSettingsPage();
  }
}

/// The kxkb colour picker: recent-colour swatch row, live hex preview
/// bar, four A/R/G/B sliders (0–255, live apply on every tick), Cancel
/// reverts, OK keeps and records the colour as recent.
class _RgbaColorPickerDialog extends StatefulWidget {
  const _RgbaColorPickerDialog({
    required this.appModel,
    required this.initial,
    required this.onChanged,
  });

  final AppModel appModel;
  final int initial;
  final ValueChanged<int> onChanged;

  @override
  State<_RgbaColorPickerDialog> createState() =>
      _RgbaColorPickerDialogState();
}

class _RgbaColorPickerDialogState extends State<_RgbaColorPickerDialog> {
  late int _alpha = (widget.initial >> 24) & 0xFF;
  late int _red = (widget.initial >> 16) & 0xFF;
  late int _green = (widget.initial >> 8) & 0xFF;
  late int _blue = widget.initial & 0xFF;

  int get _color =>
      (_alpha << 24) | (_red << 16) | (_green << 8) | _blue;

  Color get _accent => Color(widget.appModel.uiTheme.textColor);
  Color get _border => Color(widget.appModel.uiTheme.borderColor);

  void _apply() => widget.onChanged(_color);

  @override
  Widget build(BuildContext context) {
    final recents = widget.appModel.uiTheme.recentColors;
    final luminance =
        0.299 * _red + 0.587 * _green + 0.114 * _blue;
    final previewTextColor =
        (luminance < 128 || _alpha < 128) ? Colors.white : Colors.black;

    return AlertDialog(
      title: const Text('Pick a colour'),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final recent in recents)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _alpha = (recent >> 24) & 0xFF;
                        _red = (recent >> 16) & 0xFF;
                        _green = (recent >> 8) & 0xFF;
                        _blue = recent & 0xFF;
                      });
                      _apply();
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(recent),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: _border, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              constraints: const BoxConstraints(minHeight: 52),
              alignment: Alignment.center,
              color: Color(_color),
              child: Text(
                '#${_color.toRadixString(16).toUpperCase().padLeft(8, '0')}',
                style: TextStyle(fontSize: 16, color: previewTextColor),
              ),
            ),
            const SizedBox(height: 18),
            for (final channel in [
              ('A', _alpha, (int value) => _alpha = value),
              ('R', _red, (int value) => _red = value),
              ('G', _green, (int value) => _green = value),
              ('B', _blue, (int value) => _blue = value),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(channel.$1,
                          style: TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12),
                        ),
                        child: Slider(
                          value: channel.$2.toDouble(),
                          min: 0,
                          max: 255,
                          onChanged: (value) {
                            setState(() {
                              channel.$3(value.round());
                            });
                            _apply();
                          },
                        ),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 34),
                      child: Text(
                        channel.$2.toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 14, color: _accent),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Revert to the opening colour.
            widget.onChanged(widget.initial);
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            _apply();
            widget.appModel.uiTheme.pushRecentColor(_color);
            Navigator.pop(context);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
