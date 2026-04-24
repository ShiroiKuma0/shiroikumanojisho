import 'package:change_notifier_builder/change_notifier_builder.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shiroikumanojisho/language.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// Appears at startup as the portal from which a user may select media and
/// broadly select their activity of choice. The page characteristically has
/// an [AppBar] and a [BottomNavigationBar].
class HomePage extends BasePage {
  /// Construct an instance of the [HomePage].
  const HomePage({
    super.key,
  });

  @override
  BasePageState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends BasePageState<HomePage>
    with WidgetsBindingObserver {
  late final List<Widget> mediaTypeBodies;
  late final List<BottomNavigationBarItem> navBarItems;

  String get appName => appModel.packageInfo.appName;
  String get appVersion {
    // Show the pubspec `X.Y.Z+N` form in the app bar so dev iterations
    // are visually distinguishable from releases (release has no +N).
    //
    // `PackageInfo.buildNumber` on Android returns the manifest
    // `versionCode` as a string. In this project `versionCode` is
    // packed in `android/app/build.gradle` as
    // `X*1_000_000 + Y*10_000 + Z*100 + N` so Android sees a strictly
    // monotonic integer across releases and dev iterations. Concat-
    // enating it raw would render `1.0.2+1000200` in the title bar,
    // which is what prompted this function. Recover pubspec's `N` as
    // `versionCode % 100` — the Z*100 term and everything above it is
    // a multiple of 100, and N is clamped to 0..99 at the gradle
    // layer, so the low two digits are exactly N.
    //
    // Legacy note: pre-packing builds used `versionCode = 100*N +
    // abi_offset` and maxed out around ~2500. Those installs show a
    // nonsense `+N` under this rule until overwritten by the next
    // install, which is fine — any new build has versionCode
    // >= 1_000_000 and renders correctly.
    final info = appModel.packageInfo;
    if (info.buildNumber.isEmpty) return info.version;
    final code = int.tryParse(info.buildNumber);
    if (code == null) return info.version;
    final pubspecN = code % 100;
    if (pubspecN == 0) return info.version;
    return '${info.version}+$pubspecN';
  }

  int get currentHomeTabIndex => appModel.currentHomeTabIndex;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    appModelNoUpdate.databaseCloseNotifier.addListener(refresh);

    /// Populate and define the tabs and their respective content bodies based
    /// on the media types specified and ordered by [AppModel]. As [ref.watch]
    /// cannot be used here, [ref.read] is used instead, via [appModelNoUpdate].
    mediaTypeBodies = List.unmodifiable(
        appModelNoUpdate.mediaTypes.values.map((mediaType) => mediaType.home));
    navBarItems = List.unmodifiable(
      appModelNoUpdate.mediaTypes.values.map(
        (mediaType) => BottomNavigationBarItem(
          activeIcon: Icon(mediaType.icon),
          icon: Icon(mediaType.outlinedIcon),
          label: t[mediaType.uniqueKey],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      appModel.populateDefaultMapping(appModel.targetLanguage);
      appModel.populateBookmarks();
      if (appModel.isFirstTimeSetup) {
        await appModel.showLanguageMenu();
        appModel.setLastSelectedDictionaryFormat(
            appModel.targetLanguage.standardFormat);

        appModel.setFirstTimeSetupFlag();
      }
    });
  }

  void refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appModelNoUpdate.databaseCloseNotifier.removeListener(refresh);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (AppLifecycleState.resumed == state) {
      /// Keep the search database ready.
      debugPrint('Lifecycle Resumed');
      appModel.searchDictionary(
        searchTerm: appModel.targetLanguage.helloWorld,
        searchWithWildcards: false,
        useCache: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!appModel.isDatabaseOpen) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: buildAppBar(),
        body: SafeArea(
          child: buildBody(),
        ),
        bottomNavigationBar: buildBottomNavigationBar(),
      ),
    );
  }

  PreferredSizeWidget? buildAppBar() {
    return AppBar(
      leading: buildLeading(),
      title: buildTitle(),
      actions: buildActions(),
      titleSpacing: 8,
    );
  }

  Widget buildBody() {
    return IndexedStack(
      index: currentHomeTabIndex,
      children: mediaTypeBodies,
    );
  }

  Widget? buildBottomNavigationBar() {
    return BottomNavigationBar(
      onTap: switchTab,
      currentIndex: currentHomeTabIndex,
      items: navBarItems,
      selectedFontSize: textTheme.labelSmall!.fontSize!,
      unselectedFontSize: textTheme.labelSmall!.fontSize!,
    );
  }

  void switchTab(int index) async {
    MediaType mediaType = appModelNoUpdate.mediaTypes.values.toList()[index];
    if (index == currentHomeTabIndex) {
      mediaType.floatingSearchBarController.close();

      if (mediaType.scrollController.hasClients) {
        if (mediaType.scrollController.offset > 5000) {
          mediaType.scrollController.jumpTo(0);
        } else {
          mediaType.scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
        }
      }
    } else {
      await appModel.setCurrentHomeTabIndex(index);
      setState(() {});

      if (mediaType is DictionaryMediaType && appModel.shouldRefreshTabs) {
        appModel.shouldRefreshTabs = false;
        mediaType.refreshTab();
      }
    }
  }

  Widget? buildLeading() {
    return ChangeNotifierBuilder(
      notifier: appModel.incognitoNotifier,
      builder: (context, notifier, _) {
        return Padding(
          padding: Spacing.of(context).insets.onlyLeft.normal,
          child: Image.asset('assets/meta/icon.png'),
        );
      },
    );
  }

  Widget buildTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          appName,
          style: textTheme.titleLarge,
        ),
        const Space.extraSmall(),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () => StorageBenchmarkDialog.show(context, appModel),
          child: Text(
            appVersion,
            style: textTheme.labelSmall!.copyWith(
              letterSpacing: 0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> buildActions() {
    return [
      buildLanguageButton(),
      buildCreatorButton(),
      buildShowMenuButton(),
    ];
  }

  Widget buildResumeButton() {
    return JidoujishoIconButton(
      tooltip: t.resume_last_media,
      icon: Icons.update,
      enabled: false,
      onTap: resumeAction,
    );
  }

  Widget buildCreatorButton() {
    return JidoujishoIconButton(
      tooltip: t.card_creator,
      icon: Icons.note_add_outlined,
      onTap: () => appModel.openCreator(
        ref: ref,
        killOnPop: false,
      ),
    );
  }

  /// Quick language-switcher: a globe icon in the app bar that opens a
  /// popup listing every configured language which has at least one
  /// imported dictionary tagged to it (`Dictionary.primaryLanguage ==
  /// language.languageCode`). Selecting a language calls
  /// [AppModel.setTargetLanguage] — same pipeline that the dictionary
  /// menu's target-language setter uses — so the rest of the app
  /// (reader, dictionary search, UI text direction) reacts normally.
  /// The current target language is rendered with a trailing check.
  Widget buildLanguageButton() {
    List<Language> candidates = _eligibleLanguages();

    // If zero or one language is eligible there's nothing meaningful
    // to switch between — suppress the icon so it doesn't clutter the
    // app bar. The user's setup is effectively single-language.
    if (candidates.length < 2) {
      return const SizedBox.shrink();
    }

    final Language current = appModel.targetLanguage;
    return PopupMenuButton<Language>(
      splashRadius: 20,
      padding: EdgeInsets.zero,
      tooltip: t.target_language,
      icon: Icon(
        Icons.language,
        color: theme.iconTheme.color,
        size: 24,
      ),
      color: Theme.of(context).popupMenuTheme.color,
      onSelected: (Language chosen) async {
        if (chosen.languageCode == current.languageCode) return;
        await appModel.setTargetLanguage(chosen);
        if (mounted) setState(() {});
      },
      itemBuilder: (context) => candidates.map((lang) {
        final bool selected = lang.languageCode == current.languageCode;
        return PopupMenuItem<Language>(
          value: lang,
          child: Row(
            children: [
              Icon(
                selected ? Icons.check : Icons.language,
                size: textTheme.bodyMedium?.fontSize,
                color: selected ? theme.colorScheme.primary : null,
              ),
              const Space.normal(),
              Expanded(
                child: Text(
                  lang.languageName,
                  style: TextStyle(
                    fontWeight:
                        selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Returns every language in `appModel.languages` that has at least
  /// one imported dictionary applicable to it under the same
  /// inclusion logic the search pipeline uses (`AppModel.
  /// searchDictionary`): a dictionary applies to language X if its
  /// `primaryLanguage` equals X (v3 schema, set at import time), or
  /// if `primaryLanguage` is empty and X is not in `hiddenLanguages`
  /// (legacy pre-v3 heuristic for dictionaries imported before the
  /// field existed). Always includes the current target language
  /// regardless, so the user never "loses" their current language
  /// from the menu.
  List<Language> _eligibleLanguages() {
    final dicts = appModel.dictionaries;
    final String currentCode = appModel.targetLanguage.languageCode;
    return appModel.languages.values.where((lang) {
      if (lang.languageCode == currentCode) return true;
      return dicts.any((d) {
        if (d.primaryLanguage.isNotEmpty) {
          return d.primaryLanguage == lang.languageCode;
        }
        return !d.hiddenLanguages.contains(lang.languageCode);
      });
    }).toList();
  }

  Widget buildShowMenuButton() {
    return PopupMenuButton<VoidCallback>(
      splashRadius: 20,
      padding: EdgeInsets.zero,
      tooltip: t.show_menu,
      icon: Icon(
        Icons.more_vert,
        color: theme.iconTheme.color,
        size: 24,
      ),
      color: Theme.of(context).popupMenuTheme.color,
      onSelected: (value) => value(),
      itemBuilder: (context) => getMenuItems(),
    );
  }

  PopupMenuItem<VoidCallback> buildPopupItem({
    required String label,
    required Function() action,
    IconData? icon,
    Color? color,
  }) {
    return PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          if (icon != null)
            Icon(
              icon,
              size: textTheme.bodyMedium?.fontSize,
              color: color,
            ),
          if (icon != null) const Space.normal(),
          Text(
            label,
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }

  void resumeAction() {}

  void openMenu(TapDownDetails details) async {
    RelativeRect position = RelativeRect.fromLTRB(
        details.globalPosition.dx, details.globalPosition.dy, 0, 0);
    Function()? selectedAction = await showMenu(
      context: context,
      position: position,
      items: getMenuItems(),
    );

    selectedAction?.call();

    if (selectedAction == null) {
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusScope.of(context).unfocus();
      });
    }
  }

  void browseToGithub() async {
    launchUrl(
      Uri.parse('https://github.com/ShiroiKuma0/jidoujisho2'),
      mode: LaunchMode.externalApplication,
    );
  }

  void navigateToLicensePage() async {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Theme(
          data: theme.copyWith(
            cardColor: theme.colorScheme.background,
          ),
          child: LicensePage(
            applicationName: appModel.packageInfo.appName,
            applicationVersion: appModel.packageInfo.version,
            applicationLegalese: t.legalese,
            applicationIcon: Padding(
              padding: Spacing.of(context).insets.all.normal,
              child: Image.asset(
                'assets/meta/icon.png',
                height: 128,
                width: 128,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void showUiTextColorPicker() {
    Color newColor = Color(appModel.darkThemeTextColor);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: Color(appModel.darkThemeTextColor),
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
              appModel.setDarkThemeTextColor(newColor.value);
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
      ),
    );
  }

  Future<void> clearReaderCacheAction() async {
    final estimate = appModel.getReaderCacheSize();

    String formatBytes(int b) {
      if (b < 1024) return '$b B';
      if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
      if (b < 1024 * 1024 * 1024) {
        return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
      }
      return '${(b / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear reader cache'),
        content: Text(
            'This will free roughly ${formatBytes(estimate)} of WebView '
            'cache used by the ebook reader. Imported books and your reading '
            'progress are not affected.\n\nContinue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final freed = appModel.clearReaderCaches();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cache cleared'),
        content: Text('Freed ${formatBytes(freed)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<PopupMenuItem<VoidCallback>> getMenuItems() {
    return [
      buildPopupItem(
        label:
            appModel.isDarkMode ? t.options_theme_light : t.options_theme_dark,
        icon: appModel.isDarkMode ? Icons.light_mode : Icons.dark_mode,
        action: appModel.toggleDarkMode,
      ),
      // if ((appModel.androidDeviceInfo.version.sdkInt ?? 0) >= 33)
      //   buildPopupItem(
      //     label: optionsPipMode,
      //     icon: Icons.picture_in_picture,
      //     action: () {
      //       appModel.usePictureInPicture(ref: ref);
      //     },
      //   ),
      buildPopupItem(
        label: t.options_dictionaries,
        icon: Icons.auto_stories_rounded,
        action: appModel.showDictionaryMenu,
      ),
      buildPopupItem(
        label: t.options_enhancements,
        icon: Icons.auto_fix_high,
        action: appModel.openCreatorEnhancementsEditor,
      ),
      buildPopupItem(
        label: t.options_language,
        icon: Icons.translate,
        action: appModel.showLanguageMenu,
      ),
      buildPopupItem(
        label: t.options_profiles,
        icon: Icons.switch_account,
        action: appModel.showProfilesMenu,
      ),
      buildPopupItem(
        label: t.options_ui_text_color,
        icon: Icons.format_color_text,
        action: showUiTextColorPicker,
      ),
      buildPopupItem(
        label: t.options_github,
        icon: Icons.code,
        action: browseToGithub,
      ),
      buildPopupItem(
        label: 'Backup data',
        icon: Icons.backup,
        action: () => AppBackupRestore.createBackup(
          appModel: appModel,
          context: context,
        ),
      ),
      buildPopupItem(
        label: 'Restore data',
        icon: Icons.restore,
        action: () => AppBackupRestore.restoreBackup(
          appModel: appModel,
          context: context,
        ),
      ),
      buildPopupItem(
        label: 'Clear reader cache',
        icon: Icons.cleaning_services,
        action: clearReaderCacheAction,
      ),
      buildPopupItem(
        label: t.options_attribution,
        icon: Icons.info,
        action: navigateToLicensePage,
      ),
    ];
  }
}
