import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shiroikumanojisho/utils.dart';

/// Per-book reader appearance settings.
class ReaderAppearanceSettings {
  int fontColor;
  int backgroundColor;
  String fontWeight; // 'Thin', 'Normal', 'Bold'
  int marginLeft;
  int marginTop;
  int marginRight;
  int marginBottom;
  double paragraphSpacing;
  double lineSpacing;
  String fontFamily;
  String fontFamilySecondary;
  /// Per-book font size in CSS pixels. Stored in the
  /// `ttu_settings_<key>` Hive entry's JSON-encoded map under the
  /// `fontSize` key — the same place TTU's gesture-driven font-size
  /// adjustments persist to and the same place
  /// `_buildFontSizeUserScript` reads at webview construction. The
  /// dialog's UI is just a third writer to that same key, so all
  /// three pathways stay in sync without a bridging migration.
  ///
  /// NOT stored in an `rs_fontSize_<key>` entry like the other rs_*
  /// settings — that would create two sources of truth and require
  /// gesture and userscript to read both. Single key wins.
  int fontSize;
  /// Writing mode for the book content. `'horizontal'` maps to
  /// CSS `writing-mode: horizontal-tb` (standard left-to-right,
  /// top-to-bottom). `'vertical'` maps to CSS
  /// `writing-mode: vertical-rl` (top-to-bottom in columns,
  /// right-to-left column flow — standard for Japanese novels).
  /// Per-book and independent for primary vs. translation books.
  String writingMode;

  ReaderAppearanceSettings({
    this.fontColor = 0xFFFFFF00,
    this.backgroundColor = 0xFF000000,
    this.fontWeight = 'Normal',
    this.marginLeft = 0,
    this.marginTop = 0,
    this.marginRight = 0,
    this.marginBottom = 0,
    this.paragraphSpacing = 0.6,
    this.lineSpacing = 1.0,
    this.fontFamily = '',
    this.fontFamilySecondary = '',
    this.fontSize = 20,
    this.writingMode = 'horizontal',
  });

  /// Load settings from Hive box for a given book key.
  ///
  /// [isSecondary] and [languageCode] inform the default value of
  /// [writingMode] for books that have never had an explicit writing
  /// mode saved. Japanese primary books default to vertical —
  /// matching how Japanese novels are typeset; every other
  /// combination (Japanese translation books, all non-Japanese
  /// books) defaults to horizontal. Once the user toggles the mode
  /// the per-book saved value takes precedence over these defaults.
  static ReaderAppearanceSettings load(
    Box box,
    String bookKey, {
    bool isSecondary = false,
    String languageCode = '',
  }) {
    final String defaultWritingMode =
        (!isSecondary && languageCode == 'ja') ? 'vertical' : 'horizontal';
    return ReaderAppearanceSettings(
      fontColor: box.get('rs_fontColor_$bookKey', defaultValue: 0xFFFFFF00),
      backgroundColor:
          box.get('rs_bgColor_$bookKey', defaultValue: 0xFF000000),
      fontWeight:
          box.get('rs_fontWeight_$bookKey', defaultValue: 'Normal'),
      marginLeft: box.get('rs_marginL_$bookKey', defaultValue: 0),
      marginTop: box.get('rs_marginT_$bookKey', defaultValue: 0),
      marginRight: box.get('rs_marginR_$bookKey', defaultValue: 0),
      marginBottom: box.get('rs_marginB_$bookKey', defaultValue: 0),
      paragraphSpacing:
          (box.get('rs_paraSpacing_$bookKey', defaultValue: 0.6) as num)
              .toDouble(),
      lineSpacing:
          (box.get('rs_lineSpacing_$bookKey', defaultValue: 1.0) as num)
              .toDouble(),
      fontFamily: box.get('rs_fontFamily_$bookKey', defaultValue: ''),
      fontFamilySecondary:
          box.get('rs_fontFamily2_$bookKey', defaultValue: ''),
      fontSize: _loadFontSizeFromTtuSettings(box, bookKey),
      writingMode: box.get('rs_writingMode_$bookKey',
          defaultValue: defaultWritingMode),
    );
  }

  /// Read the per-book font size from the JSON-encoded
  /// `ttu_settings_<bookKey>` Hive entry. That entry is a map of
  /// stringified TTU localStorage keys; we pull `fontSize` out of
  /// it. Falls back to 20 (TTU's default) if the entry is missing,
  /// malformed, or doesn't include a fontSize.
  static int _loadFontSizeFromTtuSettings(Box box, String bookKey) {
    const int fallback = 20;
    final dynamic stored = box.get('ttu_settings_$bookKey');
    if (stored is! String) return fallback;
    try {
      final dynamic parsed = jsonDecode(stored);
      if (parsed is! Map) return fallback;
      final dynamic raw = parsed['fontSize'];
      if (raw == null) return fallback;
      final int? parsedInt = int.tryParse(raw.toString());
      return parsedInt ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Save settings to Hive box.
  Future<void> save(Box box, String bookKey) async {
    await box.put('rs_fontColor_$bookKey', fontColor);
    await box.put('rs_bgColor_$bookKey', backgroundColor);
    await box.put('rs_fontWeight_$bookKey', fontWeight);
    await box.put('rs_marginL_$bookKey', marginLeft);
    await box.put('rs_marginT_$bookKey', marginTop);
    await box.put('rs_marginR_$bookKey', marginRight);
    await box.put('rs_marginB_$bookKey', marginBottom);
    await box.put('rs_paraSpacing_$bookKey', paragraphSpacing);
    await box.put('rs_lineSpacing_$bookKey', lineSpacing);
    await box.put('rs_fontFamily_$bookKey', fontFamily);
    await box.put('rs_fontFamily2_$bookKey', fontFamilySecondary);
    await _saveFontSizeToTtuSettings(box, bookKey);
    await box.put('rs_writingMode_$bookKey', writingMode);
  }

  /// Persist [fontSize] into the JSON-encoded `ttu_settings_<bookKey>`
  /// Hive entry alongside the other TTU localStorage values. Reads
  /// the existing map first so other keys (writingMode, fontFamily
  /// groups, etc.) are preserved; only the fontSize field is
  /// updated. Creates the entry with a fontSize-only map if it
  /// didn't exist yet — TTU's defaults will kick in for the
  /// untouched keys at next module init.
  Future<void> _saveFontSizeToTtuSettings(Box box, String bookKey) async {
    final String hiveKey = 'ttu_settings_$bookKey';
    Map<String, String> updated = {};
    final dynamic stored = box.get(hiveKey);
    if (stored is String) {
      try {
        final dynamic parsed = jsonDecode(stored);
        if (parsed is Map) {
          updated = {
            for (final entry in parsed.entries)
              entry.key.toString(): entry.value.toString(),
          };
        }
      } catch (_) {}
    }
    updated['fontSize'] = fontSize.toString();
    await box.put(hiveKey, jsonEncode(updated));
  }

  /// Generate CSS to inject into the WebView.
  String toCss() {
    String fc =
        '#${(fontColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    String bg =
        '#${(backgroundColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    String fw;
    switch (fontWeight) {
      case 'Thin':
        fw = '300';
        break;
      case 'Bold':
        fw = '700';
        break;
      default:
        fw = '400';
    }

    // Build primary and secondary font-family declarations. The
    // original implementation only set TTU's `--font-family-serif`
    // / `--font-family-sans-serif` CSS variables, which TTU's
    // current build ignores in favor of direct font-family rules
    // driven by its own `fontFamilyGroupOne`/`Two` localStorage
    // settings. Changing the Reader-appearance fonts therefore had
    // no visible effect.
    //
    // Our fix: emit an explicit high-specificity rule that targets
    // `.book-content` (primary — applied to all book body text) and
    // a more specific rule for `[class*="sans"]` / `[class*="gothic"]`
    // descendants (secondary — for elements that EPUB authors
    // tagged as sans-serif). Both use `!important` so TTU's own
    // font-family rules can't override us. The CSS variables are
    // preserved as a belt-and-suspenders layer in case TTU's CSS
    // references them somewhere we haven't mapped.
    String primaryRule = '';
    if (fontFamily.isNotEmpty) {
      primaryRule = '''
        .book-content,
        .book-content p,
        .book-content div,
        .book-content span {
          font-family: "$fontFamily", "Noto Serif JP", serif !important;
        }
      ''';
    }
    String secondaryRule = '';
    if (fontFamilySecondary.isNotEmpty) {
      secondaryRule = '''
        .book-content [class*="sans"],
        .book-content [class*="gothic"],
        .book-content [style*="sans-serif"],
        .book-content [style*="Gothic"] {
          font-family: "$fontFamilySecondary", "Noto Sans JP", sans-serif !important;
        }
      ''';
    }

    String fontFamilyVarCss = '';
    if (fontFamily.isNotEmpty) {
      fontFamilyVarCss =
          '--font-family-serif: "$fontFamily", "Noto Serif JP", serif;';
    }
    String fontFamily2VarCss = '';
    if (fontFamilySecondary.isNotEmpty) {
      fontFamily2VarCss =
          '--font-family-sans-serif: "$fontFamilySecondary", "Noto Sans JP", sans-serif;';
    }

    // Writing mode: horizontal-tb for Latin-style flow,
    // vertical-rl for Japanese vertical novels. Applied at the
    // document root and on .book-content so TTU's column layout
    // picks the right axis regardless of where it reads the
    // writing-mode from. `!important` so we win over TTU's own
    // writingMode-driven rules, which might be toggled by TTU's
    // settings page in the same session.
    final String wmValue =
        writingMode == 'vertical' ? 'vertical-rl' : 'horizontal-tb';
    final String writingModeCss = '''
      html, body, .book-content {
        writing-mode: $wmValue !important;
      }
    ''';

    return '''
      .book-content {
        color: $fc !important;
        font-size: ${fontSize}px !important;
        font-weight: $fw !important;
        line-height: $lineSpacing !important;
        $fontFamilyVarCss
        $fontFamily2VarCss
      }
      $writingModeCss
      $primaryRule
      $secondaryRule
      body { background-color: $bg !important; }
      .py-8 {
        padding-top: ${marginTop}px !important;
        padding-bottom: ${marginBottom}px !important;
      }
      .px-4, .md\\:px-8 {
        padding-left: ${marginLeft}px !important;
        padding-right: ${marginRight}px !important;
      }
      .book-content p, .book-content div {
        /* margin-block-end is the writing-mode-aware "after this
           block" logical margin. In horizontal-tb it maps to
           margin-bottom (the existing, expected behavior). In
           vertical-rl (Japanese vertical novels) it maps to
           margin-left, which is the correct direction for
           paragraph separation in right-to-left column flow.
           Using only the logical property — and not also forcing
           margin-bottom — avoids double-margin / cascade conflicts
           and produces correct spacing in both writing modes. */
        margin-block-end: ${paragraphSpacing}em !important;
      }
    ''';
  }
}

const Color _y = Color(0xFFFFFF00);

/// Dialog for editing reader appearance settings.
class ReaderSettingsDialog extends StatefulWidget {
  const ReaderSettingsDialog({
    required this.settings,
    super.key,
  });

  final ReaderAppearanceSettings settings;

  @override
  State<ReaderSettingsDialog> createState() => _ReaderSettingsDialogState();
}

class _ReaderSettingsDialogState extends State<ReaderSettingsDialog> {
  late ReaderAppearanceSettings _s;

  late TextEditingController _marginLController;
  late TextEditingController _marginTController;
  late TextEditingController _marginRController;
  late TextEditingController _marginBController;
  late TextEditingController _paraSpacingController;
  late TextEditingController _lineSpacingController;
  late TextEditingController _fontFamilyController;
  late TextEditingController _fontFamily2Controller;
  late TextEditingController _fontSizeController;

  final List<String> _fontWeights = ['Thin', 'Normal', 'Bold'];

  /// Fonts bundled with the ッツ Ebook Reader. Keeping this in sync with
  /// the reader's own font list (see `_app/immutable/chunks/fonts-*.js`)
  /// lets users pick any of them from the appearance dialog without
  /// having to import a TTF/OTF file themselves.
  static const List<String> _predefinedFonts = [
    'Genei Koburi Mincho v5',
    'Klee One',
    'Klee One SemiBold',
    'Noto Sans JP',
    'Noto Serif JP',
    'Shippori Mincho',
  ];

  @override
  void initState() {
    super.initState();
    _s = ReaderAppearanceSettings(
      fontColor: widget.settings.fontColor,
      backgroundColor: widget.settings.backgroundColor,
      fontWeight: widget.settings.fontWeight,
      marginLeft: widget.settings.marginLeft,
      marginTop: widget.settings.marginTop,
      marginRight: widget.settings.marginRight,
      marginBottom: widget.settings.marginBottom,
      paragraphSpacing: widget.settings.paragraphSpacing,
      lineSpacing: widget.settings.lineSpacing,
      fontFamily: widget.settings.fontFamily,
      fontFamilySecondary: widget.settings.fontFamilySecondary,
      fontSize: widget.settings.fontSize,
      writingMode: widget.settings.writingMode,
    );
    _marginLController =
        TextEditingController(text: _s.marginLeft.toString());
    _marginTController =
        TextEditingController(text: _s.marginTop.toString());
    _marginRController =
        TextEditingController(text: _s.marginRight.toString());
    _marginBController =
        TextEditingController(text: _s.marginBottom.toString());
    _paraSpacingController =
        TextEditingController(text: _s.paragraphSpacing.toString());
    _lineSpacingController =
        TextEditingController(text: _s.lineSpacing.toString());
    _fontFamilyController =
        TextEditingController(text: _s.fontFamily);
    _fontFamily2Controller =
        TextEditingController(text: _s.fontFamilySecondary);
    _fontSizeController =
        TextEditingController(text: _s.fontSize.toString());

    // When this page is pushed from the immersive-mode reader, the
    // previous route (WebView) can retain the touch/focus claim long
    // enough that TextField taps here don't request IME until some
    // other focusable widget (like the DropdownButton) is interacted
    // with and dismissed. A post-frame unfocus explicitly tears down
    // any stale focus ownership and establishes this route as the
    // active focus scope, making the TextFields responsive on the
    // first tap instead of requiring a dropdown-open-and-close first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _marginLController.dispose();
    _marginTController.dispose();
    _marginRController.dispose();
    _marginBController.dispose();
    _paraSpacingController.dispose();
    _lineSpacingController.dispose();
    _fontFamilyController.dispose();
    _fontFamily2Controller.dispose();
    _fontSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickFont(TextEditingController controller) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (result == null || result.files.single.path == null) return;
    try {
      // Import into the shared user-fonts store. This copies the file
      // into our fonts directory, extracts the canonical family name
      // from the OpenType `name` table, and persists an index entry
      // so the reader page can re-inject `@font-face` rules for every
      // imported font on WebView load. Registering with Flutter's
      // FontLoader as well keeps the font usable in any Flutter-side
      // UI that reads the same setting (though in practice the reader
      // content lives in the WebView).
      final entry = await UserFontsStore.instance.addFont(
        sourcePath: result.files.single.path!,
      );
      final bytes = await UserFontsStore.instance.readBytes(entry);
      if (bytes != null) {
        final loader = FontLoader(entry.name);
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
        await loader.load();
      }
      controller.text = entry.name;
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black,
          content: Text(
            'Added font: ${entry.name}',
            style: const TextStyle(color: _y),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.black,
          content: Text(
            'Could not add font: $e',
            style: const TextStyle(color: _y),
          ),
        ),
      );
    }
  }

  void _showColorPicker(
      String label, Color current, ValueChanged<Color> onPick) {
    Color chosen = current;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: current,
            paletteType: PaletteType.hueWheel,
            onColorChanged: (c) => chosen = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _y)),
          ),
          TextButton(
            onPressed: () {
              onPick(chosen);
              Navigator.pop(ctx);
            },
            child: const Text('OK', style: TextStyle(color: _y)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: _y,
        iconTheme: const IconThemeData(color: _y),
        title: const Text('Reader appearance',
            style: TextStyle(color: _y)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: _y),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: _y),
            tooltip: 'Apply',
            onPressed: () {
              _s.marginLeft =
                  int.tryParse(_marginLController.text) ?? _s.marginLeft;
              _s.marginTop =
                  int.tryParse(_marginTController.text) ?? _s.marginTop;
              _s.marginRight =
                  int.tryParse(_marginRController.text) ?? _s.marginRight;
              _s.marginBottom =
                  int.tryParse(_marginBController.text) ?? _s.marginBottom;
              _s.paragraphSpacing =
                  double.tryParse(_paraSpacingController.text) ??
                      _s.paragraphSpacing;
              _s.lineSpacing =
                  double.tryParse(_lineSpacingController.text) ??
                      _s.lineSpacing;
              _s.fontFamily = _fontFamilyController.text.trim();
              _s.fontFamilySecondary = _fontFamily2Controller.text.trim();
              // Font size is clamped: under 8 is unreadable; over 200
              // breaks the column layout in TTU on small viewports.
              // If the user typed garbage we keep the previous value.
              final int? parsedFontSize =
                  int.tryParse(_fontSizeController.text.trim());
              if (parsedFontSize != null) {
                _s.fontSize = parsedFontSize.clamp(8, 200);
              }
              Navigator.pop(context, _s);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Font color
              _colorRow('Font color', Color(_s.fontColor), (c) {
                setState(() => _s.fontColor = c.value);
              }),
              const SizedBox(height: 12),

              // Background color
              _colorRow('Background color', Color(_s.backgroundColor), (c) {
                setState(() => _s.backgroundColor = c.value);
              }),
              const SizedBox(height: 16),

              // Font weight
              const Text('Font weight',
                  style: TextStyle(color: _y, fontSize: 13)),
              const SizedBox(height: 4),
              DropdownButton<String>(
                value: _s.fontWeight,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: _y),
                isExpanded: true,
                items: _fontWeights
                    .map((w) => DropdownMenuItem(
                        value: w,
                        child: Text(w,
                            style: const TextStyle(color: _y))))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _s.fontWeight = v);
                },
              ),
              const SizedBox(height: 16),

              // Writing mode: horizontal-tb vs vertical-rl. Per-book
              // setting; our toCss() emits `writing-mode: ... !important`
              // on html/body/.book-content so whatever the user picks
              // here wins over TTU's own writingMode setting.
              const Text('Writing mode',
                  style: TextStyle(color: _y, fontSize: 13)),
              const SizedBox(height: 4),
              DropdownButton<String>(
                value: _s.writingMode,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: _y),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'horizontal',
                      child: Text('Horizontal',
                          style: TextStyle(color: _y))),
                  DropdownMenuItem(
                      value: 'vertical',
                      child: Text('Vertical',
                          style: TextStyle(color: _y))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _s.writingMode = v);
                },
              ),
              const SizedBox(height: 16),

              // Primary font — applied to body text in the book.
              // The CSS we inject carries `!important` so this value
              // wins over TTU's own fontFamilyGroupOne setting. TTU's
              // font UI stays visible on its settings page, but
              // changing it there has no visible effect — this is
              // where fonts are actually controlled.
              _fontField('Primary font', _fontFamilyController),
              const SizedBox(height: 12),

              // Secondary font — applied to elements tagged as
              // sans-serif (e.g. some headings in mixed-typography
              // EPUBs). Leave blank to inherit the primary font.
              _fontField('Secondary font', _fontFamily2Controller),
              const SizedBox(height: 16),

              // Font size (px). Same value the gesture-driven
              // pinch/swipe adjusts; both writers persist into the
              // ttu_settings_<key> Hive entry. After tapping Apply,
              // _applyReaderSettings re-injects the appearance CSS
              // including this size, so the change shows up
              // immediately in the open book.
              _numberField('Font size (px)', _fontSizeController,
                  decimal: false, resetValue: '20'),
              const SizedBox(height: 12),

              // Line spacing
              _numberField('Line spacing', _lineSpacingController,
                  decimal: true, resetValue: '1'),
              const SizedBox(height: 12),

              // Paragraph spacing
              _numberField(
                  'Paragraph spacing (em)', _paraSpacingController,
                  decimal: true, resetValue: '0.6'),
              const SizedBox(height: 16),

              // Margins
              const Text('Page margins (px)',
                  style: TextStyle(color: _y, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _marginField('Left', _marginLController)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _marginField('Top', _marginTController)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _marginField('Right', _marginRController)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _marginField('Bottom', _marginBController)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _colorRow(
      String label, Color color, ValueChanged<Color> onChanged) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(color: _y, fontSize: 13)),
        ),
        GestureDetector(
          onTap: () => _showColorPicker(label, color, (c) {
            onChanged(c);
          }),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: _y, width: 1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _marginField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: _y, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _y, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _y)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _y)),
      ),
    );
  }

  Future<void> _pickPredefinedFont(TextEditingController controller) async {
    await UserFontsStore.instance.initialise();

    // Build the row list from current state. Extracted into a closure
    // so the dialog can recompute it after an in-dialog deletion and
    // rebuild without having to tear the whole dialog down.
    List<_PickerRow> buildRows() {
      final bundled = _predefinedFonts
          .map((n) => _PickerRow(name: n, isBundled: true))
          .toList();
      final custom = UserFontsStore.instance
          .list()
          .map((e) => _PickerRow(name: e.name, isBundled: false))
          .toList();
      // De-dup by name — if a user imported a font with the exact same
      // name as a bundled one, the bundled entry wins (it's already
      // registered and cheaper to use).
      final seen = <String>{};
      final rows = <_PickerRow>[];
      for (final row in [...bundled, ...custom]) {
        if (seen.add(row.name)) rows.add(row);
      }
      return rows;
    }

    String? selected = await showDialog<String>(
      context: context,
      builder: (ctx) {
        // StatefulBuilder so the inner list can refresh after the user
        // deletes a custom font, without closing the picker.
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final rows = buildRows();
            return AlertDialog(
              backgroundColor: Colors.black,
              title: const Text('Pick a font',
                  style: TextStyle(color: _y, fontSize: 14)),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final row = rows[i];
                    final bool isCurrent = controller.text == row.name;
                    // Trailing widgets: current-selection check + a
                    // delete icon for custom rows. Row.onTap selects
                    // the font; the delete icon has its own tap
                    // handler that stops propagation via its own
                    // InkWell and won't fire the row's onTap.
                    final trailingChildren = <Widget>[];
                    if (isCurrent) {
                      trailingChildren.add(
                        const Icon(Icons.check, color: _y, size: 18),
                      );
                    }
                    if (!row.isBundled) {
                      if (trailingChildren.isNotEmpty) {
                        trailingChildren.add(const SizedBox(width: 4));
                      }
                      trailingChildren.add(
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: _y, size: 18),
                          tooltip: 'Remove imported font',
                          splashRadius: 16,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          onPressed: () async {
                            final confirmed =
                                await _confirmRemoveFont(row.name);
                            if (!confirmed) return;
                            await UserFontsStore.instance
                                .removeByName(row.name);
                            // If the font just removed was the active
                            // selection in this controller, clear it
                            // so the CSS falls back to the default
                            // stack instead of leaving a reference to
                            // a font that no longer exists.
                            if (controller.text == row.name) {
                              controller.text = '';
                            }
                            setDialogState(() {});
                            if (!mounted) return;
                            setState(() {});
                          },
                        ),
                      );
                    }
                    return ListTile(
                      dense: true,
                      title: Text(
                        row.name,
                        style: TextStyle(
                          color: _y,
                          fontSize: 14,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        row.isBundled ? 'bundled' : 'custom',
                        style: const TextStyle(color: _y, fontSize: 11),
                      ),
                      trailing: trailingChildren.isEmpty
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: trailingChildren,
                            ),
                      onTap: () => Navigator.of(ctx).pop(row.name),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: _y)),
                ),
              ],
            );
          },
        );
      },
    );
    if (selected != null && selected.isNotEmpty) {
      setState(() {
        controller.text = selected;
      });
      FocusScope.of(context).unfocus();
    }
  }

  /// Confirmation dialog for removing an imported font. Returns true
  /// if the user confirmed the deletion.
  Future<bool> _confirmRemoveFont(String name) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text('Remove font?',
            style: TextStyle(color: _y, fontSize: 14)),
        content: Text(
          'Remove "$name" from imported fonts? The file will be deleted '
          'from this device. Books that reference this font will fall '
          'back to the default font until you import it again.',
          style: const TextStyle(color: _y, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: _y)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: _y)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _fontField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: _y, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _y, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _y)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _y)),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            JidoujishoIconButton(
              size: 18,
              icon: Icons.text_fields,
              tooltip: 'Pick predefined font',
              enabledColor: _y,
              onTap: () => _pickPredefinedFont(controller),
            ),
            JidoujishoIconButton(
              size: 18,
              icon: Icons.font_download,
              tooltip: 'Pick font file',
              enabledColor: _y,
              onTap: () => _pickFont(controller),
            ),
            JidoujishoIconButton(
              size: 18,
              icon: Icons.undo,
              tooltip: 'Reset',
              enabledColor: _y,
              onTap: () {
                controller.text = '';
                FocusScope.of(context).unfocus();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController controller,
      {bool decimal = false, String? resetValue}) {
    return TextField(
      controller: controller,
      keyboardType:
          TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(color: _y, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _y, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _y)),
        focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: _y)),
        suffixIcon: resetValue != null
            ? IconButton(
                icon: const Icon(Icons.undo, color: _y, size: 18),
                onPressed: () => controller.text = resetValue,
              )
            : null,
      ),
    );
  }
}

/// Single row in the merged font-picker dialog — groups a display
/// name with a bundled/custom flag so the list can show both
/// categories together without a separate section header per group.
class _PickerRow {
  const _PickerRow({required this.name, required this.isBundled});

  final String name;
  final bool isBundled;
}
