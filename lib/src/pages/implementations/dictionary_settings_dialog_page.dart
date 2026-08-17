import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The content of the dialog used for managing dictionary settings.
class DictionarySettingsDialogPage extends BasePage {
  /// Create an instance of this page.
  const DictionarySettingsDialogPage({super.key});

  @override
  BasePageState createState() => _DictionaryDialogPageState();
}

class _DictionaryDialogPageState extends BasePageState {
  late TextEditingController _debounceDelayController;
  late TextEditingController _maximumTermsController;

  /// Label size for every row in this dialog. Deliberately larger
  /// than the theme's body text — this is a settings sheet read at
  /// arm's length on an e-ink screen, not running prose.
  static const double _labelFontSize = 19;

  TextStyle get _labelStyle => TextStyle(
        fontSize: _labelFontSize,
        height: 1.1,
        color: Theme.of(context).appBarTheme.foregroundColor,
      );

  @override
  void initState() {
    super.initState();

    _debounceDelayController = TextEditingController(
        text: appModelNoUpdate.searchDebounceDelay.toString());
    _maximumTermsController =
        TextEditingController(text: appModelNoUpdate.maximumTerms.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Tight: the dialog's own padding used to eat as much height
      // as two rows of settings.
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: buildContent(),
      actions: actions,
    );
  }

  List<Widget> get actions => [
        buildCloseButton(),
      ];

  Widget buildCloseButton() {
    return TextButton(
      child: Text(t.dialog_close),
      onPressed: () => Navigator.pop(context),
    );
  }

  Widget buildContent() {
    ScrollController contentController = ScrollController();

    return SizedBox(
      width: double.maxFinite,
      child: RawScrollbar(
        thickness: 3,
        thumbVisibility: true,
        controller: contentController,
        child: SingleChildScrollView(
          controller: contentController,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildAutoSearchSwitch(),
              buildAutoFullScreenDictionarySwitch(),
              buildDictionaryFontSizeSwipeSwitch(),
              const JidoujishoDivider(),
              // Fonts and sizes moved to the 白い熊 辞書 UI page, where
              // the rest of the app's typography lives; this row is
              // the way back to them.
              buildTypographyLink(),
              const JidoujishoDivider(),
              buildDebounceDelayField(),
              buildMaximumTermsField(),
              buildIndexPrewarmMode(),
              buildManageDuplicateChecks(),
            ],
          ),
        ),
      ),
    );
  }

  /// One label-plus-switch line, packed tight: the switch gives up
  /// its 48px tap target and the row carries no vertical padding, so
  /// the rows sit directly under each other.
  Widget buildSwitchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Expanded(child: Text(label, style: _labelStyle)),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget buildAutoSearchSwitch() {
    return buildSwitchRow(
      label: t.auto_search,
      value: appModel.autoSearchEnabled,
      onChanged: (value) {
        appModel.toggleAutoSearchEnabled();
        setState(() {});
      },
    );
  }

  Widget buildAutoFullScreenDictionarySwitch() {
    return buildSwitchRow(
      label: 'Open dictionary full-screen on tap',
      value: appModel.autoFullScreenDictionary,
      onChanged: (value) {
        appModel.toggleAutoFullScreenDictionary();
        setState(() {});
      },
    );
  }

  Widget buildDictionaryFontSizeSwipeSwitch() {
    return buildSwitchRow(
      label: 'Left-edge font-size swipe gesture',
      value: appModel.dictionaryFontSizeSwipeEnabled,
      onChanged: (value) {
        appModel.setDictionaryFontSizeSwipeEnabled(value);
        setState(() {});
      },
    );
  }

  Widget buildDebounceDelayField() {
    return TextField(
      onChanged: (value) {
        int newDelay =
            int.tryParse(value) ?? appModel.defaultSearchDebounceDelay;
        if (newDelay.isNegative) {
          newDelay = appModel.defaultSearchDebounceDelay;
          _debounceDelayController.text = newDelay.toString();
        }

        appModel.setSearchDebounceDelay(newDelay);
      },
      controller: _debounceDelayController,
      keyboardType: TextInputType.number,
      style: _labelStyle,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 2, bottom: 4),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixText: t.unit_milliseconds,
        suffixIcon: JidoujishoIconButton(
          tooltip: t.reset,
          size: 18,
          onTap: () async {
            _debounceDelayController.text =
                appModel.defaultSearchDebounceDelay.toString();
            appModel
                .setSearchDebounceDelay(appModel.defaultSearchDebounceDelay);
            FocusScope.of(context).unfocus();
          },
          icon: Icons.undo,
        ),
        labelText: t.auto_search_debounce_delay,
      ),
    );
  }

  /// Opens the 白い熊 辞書 UI page at its Dictionary section, which
  /// holds the heading/entry/translation fonts and the two sizes
  /// this dialog used to carry.
  Widget buildTypographyLink() {
    return InkWell(
      onTap: openDictionaryTypography,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.text_fields,
              size: _labelFontSize,
              color: activeTextColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Fonts and sizes — 白い熊 辞書 UI',
                  style: _labelStyle),
            ),
            Icon(
              Icons.chevron_right,
              size: _labelFontSize,
              color: activeTextColor,
            ),
          ],
        ),
      ),
    );
  }

  void openDictionaryTypography() {
    // Grab the navigator that owns the page stack before this dialog
    // pops itself off it.
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (context) =>
            const JishoUiSettingsPage(initialSection: 'Dictionary'),
      ),
    );
  }

  Widget buildMaximumTermsField() {
    return TextField(
      onChanged: (value) {
        int newAmount = int.tryParse(value) ??
            appModel.defaultMaximumDictionaryTermsInResult;
        if (newAmount.isNegative) {
          newAmount = appModel.defaultMaximumDictionaryTermsInResult;
          _maximumTermsController.text = newAmount.toString();
        }

        appModel.setMaximumTerms(newAmount);
        appModel.clearDictionaryResultsCache();
      },
      controller: _maximumTermsController,
      keyboardType: TextInputType.number,
      style: _labelStyle,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.only(top: 2, bottom: 4),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: JidoujishoIconButton(
          tooltip: t.reset,
          size: 18,
          onTap: () async {
            _maximumTermsController.text =
                appModel.defaultMaximumDictionaryTermsInResult.toString();
            appModel.setMaximumTerms(
                appModel.defaultMaximumDictionaryTermsInResult);
            FocusScope.of(context).unfocus();
          },
          icon: Icons.undo,
        ),
        labelText: t.maximum_terms,
      ),
    );
  }

  Color get activeButtonColor =>
      Theme.of(context).unselectedWidgetColor.withValues(alpha: 0.1);
  Color get inactiveButtonColor =>
      Theme.of(context).unselectedWidgetColor.withValues(alpha: 0.05);
  Color get activeTextColor => Theme.of(context).appBarTheme.foregroundColor!;
  Color get inactiveTextColor => Theme.of(context).unselectedWidgetColor;

  /// A three-way radio group for [IndexPrewarmMode]. Renders the
  /// section title, then three rows of (Radio, label) for the three
  /// enum values in a fixed order: app-launch, book-open, off.
  /// Changing the selection persists the new value via
  /// [AppModel.setIndexPrewarmMode] and rebuilds the local widget so
  /// the radio dot reflects the new state.
  Widget buildIndexPrewarmMode() {
    final ValueNotifier<IndexPrewarmMode> notifier =
        ValueNotifier<IndexPrewarmMode>(appModel.indexPrewarmMode);

    Widget row(IndexPrewarmMode mode, String label) {
      return InkWell(
        onTap: () async {
          await appModel.setIndexPrewarmMode(mode);
          notifier.value = mode;
        },
        child: Row(
          children: [
            Radio<IndexPrewarmMode>(
              value: mode,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: _labelStyle)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            t.index_prewarm_title,
            style: _labelStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        // RadioGroup (the 3.32+ replacement for per-Radio groupValue/
        // onChanged) owns the selection state for the three rows.
        ValueListenableBuilder<IndexPrewarmMode>(
          valueListenable: notifier,
          builder: (_, value, _) {
            return RadioGroup<IndexPrewarmMode>(
              groupValue: value,
              onChanged: (m) async {
                if (m == null) return;
                await appModel.setIndexPrewarmMode(m);
                notifier.value = m;
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row(IndexPrewarmMode.onAppLaunch,
                      t.index_prewarm_on_app_launch),
                  row(IndexPrewarmMode.onBookOpen,
                      t.index_prewarm_on_book_open),
                  row(IndexPrewarmMode.off, t.index_prewarm_off),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildManageDuplicateChecks() {
    return InkWell(
      onTap: showDuplicateChecksPage,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        width: double.infinity,
        color: activeButtonColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_sharp,
              size: _labelFontSize,
              color: activeTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              t.manage_duplicate_checks,
              style: _labelStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  void showDuplicateChecksPage() async {
    if (mounted) {
      List<String> duplicateCheckModels = appModel.duplicateCheckModels;
      List<String> models = await appModel.getModelList();
      Map<String, bool> items = Map<String, bool>.fromEntries(
          models.map((e) => MapEntry(e, duplicateCheckModels.contains(e))));
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => SwitchSettingsPage<String>(
            items: items,
            generateLabel: (item) => item,
            onSave: (selection) {
              List<String> newDuplicateCheckModels = selection.entries
                  .where((e) => e.value)
                  .map((e) => e.key)
                  .toList();
              appModel.setDuplicateCheckModels(newDuplicateCheckModels);

              if (!duplicateCheckModels.equals(newDuplicateCheckModels)) {
                appModel.refresh();
              }
            },
          ),
        );
      }
    }
  }
}
