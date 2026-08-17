import 'dart:io';

import 'package:async_zip/async_zip.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:restart_app/restart_app.dart';

import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/src/utils/misc/app_export_import.dart';
import 'package:shiroikumanojisho/src/utils/ui_settings/state_export.dart';
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
  const JishoUiSettingsPage({this.initialSection, super.key});

  /// Section header to scroll to when the page opens, matched by its
  /// exact title (e.g. 'Dictionary'). Lets other screens link into
  /// their own part of a long page instead of dropping the user at
  /// the top of it. Null opens at the top, as before.
  final String? initialSection;

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

  /// One key per section header, filled in as the headers build.
  /// [JishoUiSettingsPage.initialSection] scrolls to the matching one.
  final Map<String, GlobalKey> _sectionKeys = {};

  /// 保存復元 automation controls, backed by native SharedPreferences
  /// over the automation channel (never part of any export).
  static const MethodChannel _automationChannel =
      MethodChannel('shiroikuma.jisho/automation');
  bool _automationEnabled = false;
  String _automationToken = '';

  @override
  void initState() {
    super.initState();
    _refreshLatestExport();
    _loadAutomationState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToInitialSection());
  }

  /// Jump to [JishoUiSettingsPage.initialSection] once the page has
  /// laid out — the keys do not have contexts before the first frame.
  void _scrollToInitialSection() {
    final String? section = widget.initialSection;
    if (section == null) {
      return;
    }
    final BuildContext? target = _sectionKeys[section]?.currentContext;
    if (target == null) {
      return;
    }
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
    );
  }

  void _loadAutomationState() async {
    final enabled =
        await _automationChannel.invokeMethod<bool>('isEnabled') ?? false;
    final token =
        await _automationChannel.invokeMethod<String>('getToken') ?? '';
    if (mounted) {
      setState(() {
        _automationEnabled = enabled;
        _automationToken = token;
      });
    }
  }

  String _abbreviatedToken() {
    if (_automationToken.length < 16) {
      return 'Tap to copy';
    }
    return '${_automationToken.substring(0, 8)}…'
        '${_automationToken.substring(_automationToken.length - 8)}'
        ' — tap to copy';
  }

  void _copyToken() async {
    await Clipboard.setData(ClipboardData(text: _automationToken));
    Fluttertoast.showToast(msg: 'Token copied to clipboard.');
  }

  void _regenerateToken() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Regenerate token?'),
        content: const Text(
            'Pasted copies (自由作業盤\'s 保存復元の設定) must be '
            'updated afterwards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final token = await _automationChannel
        .invokeMethod<String>('regenerateToken');
    if (mounted) {
      setState(() => _automationToken = token ?? '');
    }
  }

  void _refreshLatestExport() {
    setState(() {
      _latestExport =
          UiSettingsExport.latestAnyExport(ui.exportDirectory);
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
            _row(
              title: 'Automation export',
              summary: 'Sister-app tasks (自由作業盤 保存復元) may trigger '
                  'this app\'s export via the token-gated intent.',
              trailing: Switch(
                value: _automationEnabled,
                onChanged: (enabled) async {
                  await _automationChannel
                      .invokeMethod('setEnabled', {'enabled': enabled});
                  setState(() => _automationEnabled = enabled);
                },
              ),
            ),
            _row(
              title: 'Automation token',
              summary: _abbreviatedToken(),
              trailing: TextButton(
                onPressed: _regenerateToken,
                child: const Text('Regenerate'),
              ),
              onTap: _copyToken,
            ),
            _sectionHeader('Toolbars'),
            _row(
              title: 'Anki card creator button',
              summary: 'Show the card creator at the end of the source '
                  'bar. The app bar slot it used to hold now carries the '
                  "current Reader source's add button.",
              trailing: Switch(
                value: appModel.showCardCreatorButton,
                onChanged: (enabled) {
                  appModel.showCardCreatorButton = enabled;
                  setState(() {});
                },
              ),
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
            _colorRow('Accent (switches · checkboxes)', () => ui.accentColor,
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
            _sectionHeader('Dictionary'),
            _subHeader('Fonts'),
            _dictionaryFontRow(
              title: 'Heading',
              summary: 'The term itself, with its furigana.',
              read: () => appModel.dictionaryHeadingFontFamily,
              write: (family) =>
                  appModel.dictionaryHeadingFontFamily = family,
            ),
            _dictionaryFontRow(
              title: 'Entry',
              summary: 'Definitions written in the target language '
                  '(国語辞典).',
              read: () => appModel.dictionaryEntryFontFamily,
              write: (family) => appModel.dictionaryEntryFontFamily = family,
            ),
            _dictionaryFontRow(
              title: 'Translation',
              summary: 'Glosses in another language (JMdict and other '
                  'bilingual dictionaries).',
              read: () => appModel.dictionaryTranslationFontFamily,
              write: (family) =>
                  appModel.dictionaryTranslationFontFamily = family,
            ),
            _subHeader('Sizes'),
            _sliderRow(
              title: 'Heading',
              inset: _insetRowL2,
              value: appModel.dictionaryHeadingFontSize,
              min: 10,
              max: 60,
              display: (value) => value.round().toString(),
              onChanged: (value) {
                appModel.setDictionaryHeadingFontSize(value.roundToDouble());
                setState(() {});
              },
            ),
            _sliderRow(
              title: 'Entry',
              inset: _insetRowL2,
              value: appModel.dictionaryFontSize,
              min: 10,
              max: 60,
              display: (value) => value.round().toString(),
              onChanged: (value) {
                appModel.setDictionaryFontSize(value.roundToDouble());
                setState(() {});
              },
            ),
            _sliderRow(
              title: 'Translation',
              inset: _insetRowL2,
              value: appModel.dictionaryTranslationFontSize,
              min: 10,
              max: 60,
              display: (value) => value.round().toString(),
              onChanged: (value) {
                appModel
                    .setDictionaryTranslationFontSize(value.roundToDouble());
                setState(() {});
              },
            ),
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
      // The key is what [widget.initialSection] scrolls to.
      key: _sectionKeys.putIfAbsent(title, () => GlobalKey()),
      padding: EdgeInsets.only(top: first ? 8 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!first)
            Container(
              height: 1,
              margin: const EdgeInsets.only(top: 6),
              color: _accent.withValues(alpha: 0.35),
            ),
          Padding(
            padding: const EdgeInsets.only(
                left: _insetHeading, top: 4, bottom: 0),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 23,
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
          left: _insetSubHeading, top: 4, bottom: 0),
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
            EdgeInsets.only(left: inset, right: 16, top: 1, bottom: 1),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 19, height: 1.1, color: _accent)),
                  if (summary != null)
                    Text(summary,
                        style: TextStyle(
                            fontSize: 15, height: 1.1, color: _dim)),
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
      padding: EdgeInsets.only(left: inset, right: 16, top: 0, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(fontSize: 19, height: 1.1, color: _accent)),
          Row(
            children: [
              Expanded(
                // A Slider lays itself out at 48px tall whatever the
                // track looks like; capping the box is what actually
                // closes the gap between rows.
                child: SizedBox(
                  height: 30,
                  child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    // Tight slider: no huge default paddings.
                    trackHeight: 3,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    // The page's own colours rather than Material's
                    // red-on-grey: the accent colour drives switches,
                    // but a slider reads as part of the text it sits
                    // under, so it takes the text colour.
                    activeTrackColor: _accent,
                    inactiveTrackColor: _accent.withValues(alpha: 0.25),
                    thumbColor: _accent,
                    overlayColor: _accent.withValues(alpha: 0.15),
                    activeTickMarkColor: _accent,
                    inactiveTickMarkColor: _accent.withValues(alpha: 0.4),
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
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44),
                child: Text(
                  display(value),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 17, color: _accent),
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

  /// One of the three dictionary font rows. Shows the family
  /// currently in force, rendered in that family so the row is its
  /// own sample, and opens the shared picker on tap.
  Widget _dictionaryFontRow({
    required String title,
    required String summary,
    required String Function() read,
    required void Function(String family) write,
  }) {
    final String family = read();
    return _row(
      title: title,
      summary: summary,
      inset: _insetRowL2,
      onTap: () => _showFontPicker(
        title: '$title font',
        read: read,
        write: write,
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(
          family.isEmpty ? 'App font' : family,
          style: TextStyle(
            fontSize: 14,
            color: _accent,
            fontFamily: family.isEmpty ? null : family,
          ),
        ),
      ),
    );
  }

  /// Font chooser over the imported fonts plus the system default.
  ///
  /// Drives the app-wide font by default; pass [read]/[write] to
  /// point it at another setting instead — the three dictionary
  /// fonts share this picker, and its "Import font…" action, rather
  /// than each growing its own.
  void _showFontPicker({
    String title = 'Font',
    String Function()? read,
    void Function(String family)? write,
  }) async {
    final String Function() current = read ?? () => ui.fontFamily;
    final void Function(String) select =
        write ?? (family) => ui.fontFamily = family;

    await showDialog(
      context: context,
      builder: (context) {
        final families = ['', ...ui.externalFontFamilies];
        return AlertDialog(
          title: Text(title),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final family in families)
                  InkWell(
                    onTap: () {
                      select(family);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      child: Text(
                        '${current() == family ? '✓  ' : ''}'
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
              onPressed: () => _importFont(
                title: title,
                read: read,
                write: select,
              ),
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

  void _importFont({
    String title = 'Font',
    String Function()? read,
    void Function(String family)? write,
  }) async {
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
    (write ?? (f) => ui.fontFamily = f)(family);
    Fluttertoast.showToast(msg: 'Imported "$family"');
    if (mounted) {
      // Rebuild the open font list with the new entry.
      Navigator.pop(context);
      _showFontPicker(title: title, read: read, write: write);
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

  static const String _categoryAppData = 'app_data';

  /// Selection by state-export id; settings + artifact children all on,
  /// the heavyweight cross-device bundle deliberately OFF by default.
  late final Set<String> _selected = {...StateExport.allIds};

  List<String> get _allSelectable => [
        ...StateExport.allIds,
        _categoryAppData,
      ];

  bool get _allSelected => _selected.length == _allSelectable.length;

  Set<String> get _selectedState =>
      _selected.intersection(StateExport.allIds);

  @override
  Widget build(BuildContext context) {
    final latest =
        UiSettingsExport.latestAnyExport(ui.exportDirectory);
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
                      _selected.addAll(_allSelectable);
                    }
                  });
                },
              ),
              for (final category in StateExport.categories)
                if (category.id == 'artifacts')
                  // Parent header row: toggles all three children.
                  _checkboxRow(
                    label: category.label,
                    value: StateExport.artifactDirs.keys
                        .every(_selected.contains),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _selected.addAll(StateExport.artifactDirs.keys);
                        } else {
                          _selected
                              .removeAll(StateExport.artifactDirs.keys);
                        }
                      });
                    },
                  )
                else
                  _checkboxRow(
                    label: category.label,
                    indent: category.parentId != null,
                    value: _selected.contains(category.id),
                    onChanged: (checked) {
                      setState(() {
                        if (checked ?? false) {
                          _selected.add(category.id);
                        } else {
                          _selected.remove(category.id);
                        }
                      });
                    },
                  ),
              _checkboxRow(
                label: 'App data (cross-device bundle)',
                value: _selected.contains(_categoryAppData),
                onChanged: (checked) {
                  setState(() {
                    if (checked ?? false) {
                      _selected.add(_categoryAppData);
                    } else {
                      _selected.remove(_categoryAppData);
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
    bool indent = false,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: EdgeInsets.only(left: indent ? 32 : 8, top: 2, bottom: 2),
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
      // One zip always: when the cross-device bundle is ticked it is
      // built first (its own progress dialog; quiet suppresses its
      // success dialog) into shared tmp, then embedded uncompressed
      // as app_data.zip and the staging copy removed.
      File? bundleTemp;
      if (_selected.contains(_categoryAppData)) {
        bundleTemp = await AppExportImport.exportData(
          appModel: widget.appModel,
          context: context,
          quiet: true,
        );
        if (bundleTemp == null) {
          // Its own failure dialog already showed; keep the panel.
          return;
        }
      }
      final file = await StateExport.run(
        box: widget.appModel.preferences,
        ids: _selectedState,
        directory: ui.exportDirectory,
        appVersion: widget.appModel.packageInfo.version,
        embedBundle: bundleTemp,
      );
      try {
        bundleTemp?.deleteSync();
      } catch (_) {}
      final saved = <String>[path.basename(file.path)];
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
    // The directory's newest state export serves the state ids; the
    // newest bundle serves app_data. A file picker is the fallback
    // when no directory is set.
    File? file;
    if (ui.exportDirectory.isNotEmpty) {
      final dir = Directory(ui.exportDirectory);
      final candidates = !dir.existsSync()
          ? <File>[]
          : (dir
              .listSync()
              .whereType<File>()
              .where((f) =>
                  (path.basename(f.path)
                          .startsWith(StateExport.filePrefix) &&
                      f.path.endsWith('.zip')) ||
                  (path.basename(f.path)
                          .startsWith(UiSettingsExport.exportPrefix) &&
                      (f.path.endsWith('.zip') ||
                          f.path.endsWith('.json'))))
              .toList()
            ..sort((a, b) => b
                .statSync()
                .modified
                .compareTo(a.statSync().modified)));
      if (candidates.isEmpty &&
          !_selected.contains(_categoryAppData)) {
        Fluttertoast.showToast(msg: 'No export in this directory yet.');
        return;
      }
      if (candidates.isEmpty) {
        // State export missing but the bundle is still wanted.
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
    final wantsState = _selectedState.isNotEmpty;
    if (wantsState && file == null && ui.exportDirectory.isNotEmpty) {
      return;
    }

    final summary = <String, int>{};
    try {
      if (wantsState && file != null) {
        if (file.path.endsWith('.zip')) {
          summary.addAll(await StateExport.import(
            box: widget.appModel.preferences,
            archive: file,
            ids: _selectedState,
          ));
        } else {
          // Legacy pre-state single-JSON export: its categories are
          // keyed by display label; import them all.
          summary.addAll(UiSettingsExport.importFrom(
            box: widget.appModel.preferences,
            file: file,
            selectedCategories: {
              for (final category in UiSettingsExport.categories)
                category.key,
            },
          ));
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
      // Prefer the bundle embedded in the chosen export zip; fall
      // back to a legacy standalone bundle file in the directory.
      File? bundle;
      File? extracted;
      if (file != null && file.path.endsWith('.zip')) {
        final reader = ZipFileReader();
        try {
          await reader.open(file);
          final names = {
            for (final entry in await reader.entries()) entry.name,
          };
          if (names.contains(StateExport.bundleEntry)) {
            extracted = File(
                '/storage/emulated/0/tmp/shiroikuma-jisho-app_data_'
                'import.zip');
            await reader.readToFile(StateExport.bundleEntry, extracted);
            bundle = extracted;
          }
        } finally {
          await reader.close();
        }
      }
      bundle ??= UiSettingsExport.latestBundle(ui.exportDirectory);
      if (bundle == null) {
        Fluttertoast.showToast(
            msg: 'No cross-device bundle in this export.');
        return;
      }
      if (!mounted) {
        return;
      }
      // importData confirms, replaces data wholesale, and exits the
      // app itself; the extracted staging copy is reclaimed by the
      // next shared-tmp cleanup if the exit wins the race.
      await AppExportImport.importData(
        appModel: widget.appModel,
        context: context,
        bundle: bundle,
      );
      try {
        extracted?.deleteSync();
      } catch (_) {}
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
