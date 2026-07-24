import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:spaces/spaces.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:io';

/// The content of the dialog when editing [SecondarySubtitleOptions].
class SecondarySubtitleOptionsDialogPage extends BasePage {
  /// Create an instance of this page.
  const SecondarySubtitleOptionsDialogPage({
    required this.notifier,
    super.key,
  });

  /// Notifier for the secondary subtitle options.
  final ValueNotifier<SecondarySubtitleOptions> notifier;

  @override
  BasePageState createState() => _SecondarySubtitleOptionsDialogPage();
}

class _SecondarySubtitleOptionsDialogPage
    extends BasePageState<SecondarySubtitleOptionsDialogPage> {
  late SecondarySubtitleOptions _options;

  late final TextEditingController _fontSizeController;
  late final TextEditingController _fontNameController;
  late final TextEditingController _fontColorController;
  late final TextEditingController _outlineColorController;
  late final TextEditingController _opacityController;
  late final TextEditingController _widthController;
  late final TextEditingController _blurController;
  late final TextEditingController _verticalOffsetController;

  List<String> fontWeights = ['Thin', 'Normal', 'Bold'];
  int fontWeightIdx = 1;

  @override
  void initState() {
    super.initState();
    _options = widget.notifier.value;

    fontWeightIdx = fontWeights.indexOf(_options.fontWeight);
    _fontSizeController =
        TextEditingController(text: _options.fontSize.toString());
    _fontNameController = TextEditingController(text: _options.fontName.trim());
    _fontColorController =
        TextEditingController(text: '#${_options.fontColor.toRadixString(16)}');
    _outlineColorController = TextEditingController(
        text: '#${_options.subtitleOutlineColor.toRadixString(16)}');
    _opacityController = TextEditingController(
        text: _options.subtitleBackgroundOpacity.toString());
    _widthController =
        TextEditingController(text: _options.subtitleOutlineWidth.toString());
    _blurController = TextEditingController(
        text: _options.subtitleBackgroundBlurRadius.toString());
    _verticalOffsetController =
        TextEditingController(text: _options.verticalOffset.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? Spacing.of(context).insets.exceptBottom.big
          : Spacing.of(context).insets.exceptBottom.normal.copyWith(
                left: Spacing.of(context).spaces.semiBig,
                right: Spacing.of(context).spaces.semiBig,
              ),
      actionsPadding: Spacing.of(context).insets.exceptBottom.normal.copyWith(
            left: Spacing.of(context).spaces.normal,
            right: Spacing.of(context).spaces.normal,
            bottom: Spacing.of(context).spaces.normal,
            top: Spacing.of(context).spaces.extraSmall,
          ),
      content: buildContent(),
      actions: actions,
    );
  }

  Widget buildContent() {
    ScrollController scrollController = ScrollController();
    return RawScrollbar(
      thickness: 3,
      thumbVisibility: true,
      controller: scrollController,
      child: Padding(
        padding: Spacing.of(context).insets.onlyRight.normal,
        child: SingleChildScrollView(
          controller: scrollController,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * (1 / 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _fontSizeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_font_size,
                    suffixIcon: JidoujishoIconButton(
                      size: 18,
                      tooltip: t.reset,
                      onTap: () async {
                        _fontSizeController.text = '20.0';
                        FocusScope.of(context).unfocus();
                      },
                      icon: Icons.undo,
                    ),
                    suffixText: t.unit_pixels,
                  ),
                ),
                TextField(
                  controller: _widthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_outline_width,
                    suffixText: t.unit_pixels,
                    suffixIcon: JidoujishoIconButton(
                      size: 18,
                      tooltip: t.reset,
                      onTap: () async {
                        _widthController.text = '3.0';
                        FocusScope.of(context).unfocus();
                      },
                      icon: Icons.undo,
                    ),
                  ),
                ),
                TextField(
                  controller: _blurController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_subtitle_background_blur_radius,
                    suffixText: t.unit_pixels,
                    suffixIcon: JidoujishoIconButton(
                      size: 18,
                      tooltip: t.reset,
                      onTap: () async {
                        _blurController.text = '0.0';
                        FocusScope.of(context).unfocus();
                      },
                      icon: Icons.undo,
                    ),
                  ),
                ),
                TextField(
                  controller: _opacityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_subtitle_background_opacity,
                    suffixIcon: JidoujishoIconButton(
                      size: 18,
                      tooltip: t.reset,
                      onTap: () async {
                        _opacityController.text = '0.0';
                        FocusScope.of(context).unfocus();
                      },
                      icon: Icons.undo,
                    ),
                  ),
                ),
                TextField(
                  controller: _fontNameController,
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_font_name,
                    suffixIcon: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        JidoujishoIconButton(
                          size: 18,
                          tooltip: t.google_fonts,
                          onTap: () async {
                            pickFontFile();
                          },
                          icon: Icons.font_download,
                        ),
                        JidoujishoIconButton(
                          size: 18,
                          tooltip: t.reset,
                          onTap: () async {
                            _fontNameController.text = '';
                            FocusScope.of(context).unfocus();
                          },
                          icon: Icons.undo,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: _fontColorController,
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_font_color,
                    suffixIcon: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        JidoujishoIconButton(
                          size: 18,
                          tooltip: t.pick_color,
                          onTap: () async {
                            showColorPicker('Font');
                          },
                          icon: Icons.color_lens,
                        ),
                        JidoujishoIconButton(
                          size: 18,
                          tooltip: t.reset,
                          onTap: () async {
                            _fontColorController.text = '';
                            FocusScope.of(context).unfocus();
                          },
                          icon: Icons.undo,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                const Space.small(),
                Padding(
                  padding: Spacing.of(context).insets.onlyTop.small,
                  child: Text(
                    t.player_option_font_weight,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.hintColor,
                    ),
                  ),
                ),
                JidoujishoDropdown<String>(
                  options: fontWeights,
                  initialOption: fontWeights[fontWeightIdx],
                  generateLabel: (weight) => weight,
                  onChanged: (weight) {
                    fontWeightIdx = fontWeights.indexOf(weight ?? 'Normal');
                    setState(() {});
                  },
                ),
                Container(height: 0.45, color: Colors.black87),
                const Space.small(),
                TextField(
                  controller: _outlineColorController,
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_outline_color,
                    suffixIcon: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        JidoujishoIconButton(
                          size: 18,
                          tooltip: t.pick_color,
                          onTap: () async {
                            showColorPicker('Outline');
                          },
                          icon: Icons.color_lens,
                        ),
                        JidoujishoIconButton(
                          size: 18,
                          tooltip: t.reset,
                          onTap: () async {
                            _outlineColorController.text = '';
                            FocusScope.of(context).unfocus();
                          },
                          icon: Icons.undo,
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                TextField(
                  controller: _verticalOffsetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    labelText: t.player_option_vertical_offset,
                    suffixText: t.unit_pixels,
                    suffixIcon: JidoujishoIconButton(size: 18, tooltip: t.reset,
                      onTap: () async { _verticalOffsetController.text = '0.0'; FocusScope.of(context).unfocus(); },
                      icon: Icons.undo),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> setValues({required bool saveOptions}) async {
    String fontSizeText = _fontSizeController.text;
    double? newFontSize = double.tryParse(fontSizeText);

    String fontColorText = _fontColorController.text;
    int? newFontColor = int.tryParse(fontColorText.replaceFirst('#', '0x'));

    String outlineColorText = _outlineColorController.text;
    int? newOutlineColor =
        int.tryParse(outlineColorText.replaceFirst('#', '0x'));

    String newFontName = _fontNameController.text.trim();

    String opacityText = _opacityController.text;
    double? newOpacity = double.tryParse(opacityText);

    String widthText = _widthController.text;
    double? newWidth = double.tryParse(widthText);

    String blurText = _blurController.text;
    double? newBlur = double.tryParse(blurText);

    String verticalOffsetText = _verticalOffsetController.text;
    double? newVerticalOffset = double.tryParse(verticalOffsetText);

    if (newFontSize != null &&
        newFontColor != null &&
        newOutlineColor != null &&
        newOpacity != null &&
        newWidth != null &&
        newBlur != null &&
        newVerticalOffset != null &&
        (newOpacity <= 1 && newOpacity >= 0) &&
        newFontSize >= 0 &&
        newWidth >= 0 &&
        newBlur >= 0) {
      SecondarySubtitleOptions options = SecondarySubtitleOptions(
        fontName: newFontName,
        fontSize: newFontSize,
        fontColor: newFontColor,
        fontWeight: fontWeights[fontWeightIdx],
        subtitleBackgroundOpacity: newOpacity,
        subtitleOutlineWidth: newWidth,
        subtitleOutlineColor: newOutlineColor,
        subtitleBackgroundBlurRadius: newBlur,
        verticalOffset: newVerticalOffset,
      );

      widget.notifier.value = options;

      if (saveOptions) {
        appModel.setSecondarySubtitleOptions(options);
      }

      Navigator.pop(context);
    }
  }

  List<Widget> get actions => [
        buildSaveButton(),
        buildSetButton(),
      ];

  Widget buildSaveButton() {
    return TextButton(
      onPressed: executeSave,
      child: Text(t.dialog_save),
    );
  }

  Widget buildSetButton() {
    return TextButton(
      onPressed: executeSet,
      child: Text(t.dialog_set),
    );
  }

  void executeSave() async {
    await setValues(saveOptions: true);
  }

  void executeSet() async {
    await setValues(saveOptions: false);
  }

  Future<bool> pickFontFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'],
    );
    if (result != null) {
      File file = File(result.files.single.path ?? '');
      Directory appDirectory = await getApplicationDocumentsDirectory();
      String savedFilePath =
          '${appDirectory.path}/${result.files.single.name.split('.').first}';
      File newFile = File(savedFilePath);
      await newFile.writeAsBytes(await file.readAsBytes());
      _fontNameController.text = result.files.single.name.split('.').first;
      var custom = FontLoader(_fontNameController.text);
      Uint8List bytes = await newFile.readAsBytes();
      custom.addFont(Future.value(ByteData.view(bytes.buffer)));
      await custom.load();
      return true;
    }
    return false;
  }

  void showColorPicker(String target) {
    Color newColor = target == 'Font'
        ? Color(_options.fontColor)
        : Color(_options.subtitleOutlineColor);
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: target == 'Font'
                    ? Color(_options.fontColor)
                    : Color(_options.subtitleOutlineColor),
                paletteType: PaletteType.hueWheel,
                onColorChanged: (value) {
                  newColor = value;
                },
              ),
            ),
            actions: [
              TextButton(
                child: Text(t.dialog_save),
                onPressed: () {
                  if (target == 'Font') {
                    _fontColorController.text =
                        '#${newColor.value.toRadixString(16)}';
                  } else {
                    _outlineColorController.text =
                        '#${newColor.value.toRadixString(16)}';
                  }
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(t.dialog_cancel),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }
}
