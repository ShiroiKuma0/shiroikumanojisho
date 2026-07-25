import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
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
  late TextEditingController _dictionaryFontSizeController;
  late TextEditingController _dictionaryHeadingFontSizeController;
  late TextEditingController _maximumTermsController;

  @override
  void initState() {
    super.initState();

    _debounceDelayController = TextEditingController(
        text: appModelNoUpdate.searchDebounceDelay.toString());
    _dictionaryFontSizeController = TextEditingController(
        text: appModelNoUpdate.dictionaryFontSize.toString());
    _dictionaryHeadingFontSizeController = TextEditingController(
        text: appModelNoUpdate.dictionaryHeadingFontSize.toString());

    _maximumTermsController =
        TextEditingController(text: appModelNoUpdate.maximumTerms.toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: MediaQuery.of(context).orientation == Orientation.portrait
          ? Spacing.of(context).insets.exceptBottom.big
          : Spacing.of(context).insets.exceptBottom.normal,
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
              const Space.small(),
              const JidoujishoDivider(),
              buildDebounceDelayField(),
              buildDictionaryFontSizeField(),
              buildDictionaryHeadingFontSizeField(),
              buildMaximumTermsField(),
              const Space.normal(),
              buildIndexPrewarmMode(),
              const Space.normal(),
              buildManageDuplicateChecks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAutoSearchSwitch() {
    ValueNotifier<bool> notifier =
        ValueNotifier<bool>(appModel.autoSearchEnabled);

    return Row(
      children: [
        Expanded(
          child: Text(t.auto_search),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (_, value, _) {
            return Switch(
              value: value,
              onChanged: (value) {
                appModel.toggleAutoSearchEnabled();
                notifier.value = appModel.autoSearchEnabled;
              },
            );
          },
        )
      ],
    );
  }

  Widget buildAutoFullScreenDictionarySwitch() {
    ValueNotifier<bool> notifier =
        ValueNotifier<bool>(appModel.autoFullScreenDictionary);

    return Row(
      children: [
        const Expanded(
          child: Text('Open dictionary full-screen on tap'),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (_, value, _) {
            return Switch(
              value: value,
              onChanged: (v) {
                appModel.toggleAutoFullScreenDictionary();
                notifier.value = appModel.autoFullScreenDictionary;
              },
            );
          },
        )
      ],
    );
  }

  Widget buildDictionaryFontSizeSwipeSwitch() {
    ValueNotifier<bool> notifier =
        ValueNotifier<bool>(appModel.dictionaryFontSizeSwipeEnabled);

    return Row(
      children: [
        const Expanded(
          child: Text('Left-edge font-size swipe gesture'),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (_, value, _) {
            return Switch(
              value: value,
              onChanged: (v) {
                appModel.setDictionaryFontSizeSwipeEnabled(v);
                notifier.value = v;
              },
            );
          },
        )
      ],
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
      decoration: InputDecoration(
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

  Widget buildDictionaryFontSizeField() {
    return TextField(
      onChanged: (value) {
        double newSize =
            double.tryParse(value) ?? appModel.defaultDictionaryFontSize;
        if (newSize.isNegative) {
          newSize = appModel.defaultDictionaryFontSize;
          _dictionaryFontSizeController.text = newSize.toString();
        }

        appModel.setDictionaryFontSize(newSize);
      },
      controller: _dictionaryFontSizeController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixText: t.unit_pixels,
        suffixIcon: JidoujishoIconButton(
          tooltip: t.reset,
          size: 18,
          onTap: () async {
            _dictionaryFontSizeController.text =
                appModel.defaultDictionaryFontSize.toString();
            appModel.setDictionaryFontSize(appModel.defaultDictionaryFontSize);
            FocusScope.of(context).unfocus();
          },
          icon: Icons.undo,
        ),
        labelText: t.dictionary_font_size,
      ),
    );
  }

  Widget buildDictionaryHeadingFontSizeField() {
    return TextField(
      onChanged: (value) {
        double newSize =
            double.tryParse(value) ?? appModel.defaultDictionaryHeadingFontSize;
        if (newSize.isNegative) {
          newSize = appModel.defaultDictionaryHeadingFontSize;
          _dictionaryHeadingFontSizeController.text = newSize.toString();
        }
        appModel.setDictionaryHeadingFontSize(newSize);
      },
      controller: _dictionaryHeadingFontSizeController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixText: t.unit_pixels,
        suffixIcon: JidoujishoIconButton(
          tooltip: t.reset,
          size: 18,
          onTap: () async {
            _dictionaryHeadingFontSizeController.text =
                appModel.defaultDictionaryHeadingFontSize.toString();
            appModel.setDictionaryHeadingFontSize(appModel.defaultDictionaryHeadingFontSize);
            FocusScope.of(context).unfocus();
          },
          icon: Icons.undo,
        ),
        labelText: t.dictionary_heading_font_size,
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
      decoration: InputDecoration(
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
            Radio<IndexPrewarmMode>(value: mode),
            Expanded(child: Text(label)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: Spacing.of(context).insets.onlyLeft.small,
          child: Text(
            t.index_prewarm_title,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
        padding: Spacing.of(context).insets.vertical.normal,
        alignment: Alignment.center,
        width: double.infinity,
        color: activeButtonColor,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_sharp,
              size: textTheme.titleSmall?.fontSize,
              color: activeTextColor,
            ),
            const Space.small(),
            Text(
              t.manage_duplicate_checks,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: activeTextColor,
              ),
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
