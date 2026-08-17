import 'package:flutter/material.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// A template for a single media type's tab body content in the main menu.
/// Has a floating search bar which can be customised depending on the
/// current selected media source.
abstract class BaseTabPage extends BasePage {
  /// Create an instance of this tab page.
  const BaseTabPage({
    super.key,
  });

  @override
  BaseTabPageState<BaseTabPage> createState();
}

/// A base class for providing all tabs in the main menu. In large part, this
/// was implemented to define shortcuts for common lengthy methods across UI
/// code.
abstract class BaseTabPageState<T extends BaseTabPage> extends BasePageState {
  @override
  void initState() {
    super.initState();
    mediaType.tabRefreshNotifier.addListener(refresh);
  }

  /// Refresh this tab.
  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      mediaSource.buildHistoryPage(),
      buildFloatingSearchBar(),
    ]);
  }

  /// Each tab in the home page represents a media type.
  MediaType get mediaType;

  /// Get the active media source for the current media type.
  MediaSource get mediaSource =>
      appModel.getCurrentSourceForMediaType(mediaType: mediaType);

  /// Whether or not the search bar is currently in focus.
  bool _isSearchBarFocused = false;

  /// The search bar to show at the topmost of the tab body. When selected,
  /// [buildSearchBarBody] will take the place of the remainder tab body, or
  /// the elements below the search bar when unselected.
  Widget buildFloatingSearchBar() {
    return mediaSource.buildBar() ??
        FloatingSearchBar(
          isScrollControlled: true,
          hint: mediaSource.getLocalisedSourceName(appModel),
          title: buildSourcePill(),
          centerTitle: true,
          controller: mediaType.floatingSearchBarController,
          builder: (_, _) => const SizedBox.shrink(),
          borderRadius: BorderRadius.zero,
          elevation: 0,
          backgroundColor: appModel.isDarkMode
              ? const Color.fromARGB(255, 30, 30, 30)
              : const Color.fromARGB(255, 229, 229, 229),
          backdropColor: appModel.isDarkMode ? Colors.black : Colors.white,
          accentColor: theme.colorScheme.primary,
          scrollPadding: const EdgeInsets.only(top: 6, bottom: 56),
          transitionDuration: Duration.zero,
          margins: const EdgeInsets.symmetric(horizontal: 6),
          width: double.maxFinite,
          transition: SlideFadeFloatingSearchBarTransition(),
          automaticallyImplyBackButton: false,
          onFocusChanged: (focused) => onFocusChanged(focused: focused),
          leadingActions: [
            buildOpenSourceButton(),
            buildBackButton(),
          ],
          actions: [
            ...mediaSource.getActions(
              context: context,
              ref: ref,
              appModel: appModel,
            ),
            ...buildCardCreatorActions(),
          ],
        );
  }

  /// The source indicator, centred in the bar: the active source's
  /// name and icon in bold, ringed by a rounded border in the UI
  /// theme's own colours (yellow out of the box). It replaces the
  /// grey left-aligned hint text, which was easy to read past — the
  /// point of the pill is that "am I in the EPUB reader or the PDF
  /// reader?" is answerable at a glance.
  ///
  /// Tapping it opens the source picker. The source's own open
  /// action lives on the leading icon instead — see
  /// [buildOpenSourceButton].
  Widget buildSourcePill() {
    final ui = appModel.uiTheme;
    final Color accent = Color(ui.textColor);
    final Color border = Color(ui.borderColor);
    final double fontSize = textTheme.titleSmall?.fontSize ?? 14;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: showSourcePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: border, width: 1.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                mediaSource.icon,
                color: accent,
                size: fontSize + 2,
              ),
              const SizedBox(width: 8),
              // Flexible so a long source name ellipsises inside the
              // pill rather than overflowing the bar on a narrow
              // screen (the Palma is ~720px with up to four actions
              // to the right of the pill).
              Flexible(
                child: Text(
                  mediaSource.getLocalisedSourceName(appModel),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Leading action: opens the current source — its file picker, the
  /// TTU library manager, the browser, whatever "use this source"
  /// means for it. This is the action tapping the bar itself has
  /// always run; it moved onto this icon when the centred pill took
  /// over the bar's tap area for switching sources.
  ///
  /// Browse-only sources (the merged libraries) have nothing to open,
  /// so they get no button rather than a dead one.
  Widget buildOpenSourceButton() {
    if (mediaSource.isBrowseOnly) {
      return const FloatingSearchBarAction(child: SizedBox.shrink());
    }

    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: textTheme.titleLarge?.fontSize,
        tooltip: mediaSource.getLocalisedSourceName(appModel),
        icon: mediaSource.icon,
        onTap: () => mediaSource.onSearchBarTap(
          context: context,
          ref: ref,
          appModel: appModel,
        ),
      ),
    );
  }

  /// Swap the current active [MediaSource] via the picker dialog.
  void showSourcePicker() async {
    await showDialog(
      context: context,
      builder: (context) => MediaSourcePickerDialogPage(
        mediaType: mediaType,
      ),
    );
    mediaType.refreshTab();
  }

  /// The Anki card creator action, tacked onto the end of the source
  /// bar's actions. It used to live in the app bar, where the active
  /// source's add button now sits instead; it is off by default, as
  /// the creator is also reachable from dictionary results, and shows
  /// here only when enabled on the 白い熊 辞書 UI page.
  List<Widget> buildCardCreatorActions() {
    if (!appModel.showCardCreatorButton) {
      return const [];
    }

    return [
      FloatingSearchBarAction(
        child: JidoujishoIconButton(
          size: textTheme.titleLarge?.fontSize,
          tooltip: t.card_creator,
          icon: Icons.note_add_outlined,
          onTap: () => appModel.openCreator(
            ref: ref,
            killOnPop: false,
          ),
        ),
      ),
    ];
  }

  /// Respond to tapping to the search bar and execute an action if the source
  /// does not implement search.
  void onFocusChanged({required bool focused}) async {
    _isSearchBarFocused = focused;

    if (!_isSearchBarFocused) {
      mediaType.floatingSearchBarController.close();
      setState(() {});
    } else {
      if (!mediaSource.implementsSearch) {
        final focusScope = FocusScope.of(context);
        await mediaSource.onSearchBarTap(
          context: context,
          ref: ref,
          appModel: appModel,
        );
        mediaType.floatingSearchBarController.clear();
        mediaType.floatingSearchBarController.close();
        setState(() {});
        focusScope.unfocus();
      }
    }
  }

  /// The body to show when the search bar is currently selected.
  Widget buildSearchBarBody(
      BuildContext context, Animation<double> transition) {
    return Container();
  }

  /// Allows user to swap the current active [MediaSource]. Still the
  /// leading action on search-driven bars ([BaseMediaSearchBar]),
  /// whose input field cannot give up its space to a source pill.
  Widget buildChangeSourceButton() {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: textTheme.titleLarge?.fontSize,
        tooltip: t.change_source,
        icon: mediaSource.icon,
        onTap: showSourcePicker,
      ),
    );
  }

  /// Allows user to close the [FloatingSearchBar] when open.
  Widget buildBackButton() {
    return FloatingSearchBarAction(
      showIfOpened: true,
      showIfClosed: false,
      child: JidoujishoIconButton(
        size: textTheme.titleLarge?.fontSize,
        tooltip: t.back,
        icon: Icons.arrow_back,
        onTap: () {
          mediaType.floatingSearchBarController.close();
        },
      ),
    );
  }
}
