import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:shiroikumanojisho/creator.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/src/media/types/dictionary_media_type.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The page shown after performing a recursive dictionary lookup.
class RecursiveDictionaryPage extends BasePage {
  /// Create an instance of this page.
  const RecursiveDictionaryPage({
    required this.searchTerm,
    required this.killOnPop,
    this.onUpdateQuery,
    super.key,
  });

  /// The initial search term that this page searches on initialisation.
  final String searchTerm;

  /// If true, popping will exit the application.
  final bool killOnPop;

  /// Used to track changes to the query.
  final Function(String)? onUpdateQuery;

  @override
  BasePageState<RecursiveDictionaryPage> createState() =>
      _RecursiveDictionaryPageState();
}

class _RecursiveDictionaryPageState
    extends BasePageState<RecursiveDictionaryPage> {
  /// Current search query. Replaces the FloatingSearchBarController
  /// from the previous design. A plain ValueNotifier is enough —
  /// the AppBar title rebuilds on change via a
  /// ValueListenableBuilder, and `search()` reads/writes it
  /// directly.
  final ValueNotifier<String> _queryNotifier = ValueNotifier<String>('');

  DictionarySearchResult? _result;

  bool _isSearching = false;
  late bool _isCreatorOpen;

  @override
  void initState() {
    super.initState();

    _isCreatorOpen = appModelNoUpdate.isCreatorOpen;

    _queryNotifier.value = widget.searchTerm;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      appModel.addToSearchHistory(
        historyKey: DictionaryMediaType.instance.uniqueKey,
        searchTerm: widget.searchTerm,
      );

      appModelNoUpdate.dictionarySearchAgainNotifier.addListener(searchAgain);
      search(widget.searchTerm);
    });
  }

  @override
  void dispose() {
    appModelNoUpdate.dictionarySearchAgainNotifier
        .removeListener(searchAgain);
    _queryNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!appModel.isDatabaseOpen) {
      return const SizedBox.shrink();
    }

    Color? backgroundColor = theme.colorScheme.background;
    if (appModel.overrideDictionaryColor != null && !_isCreatorOpen) {
      if ((appModel.overrideDictionaryTheme ?? theme).brightness ==
          Brightness.dark) {
        backgroundColor =
            JidoujishoColor.lighten(appModel.overrideDictionaryColor!, 0.025);
      } else {
        backgroundColor =
            JidoujishoColor.darken(appModel.overrideDictionaryColor!, 0.025);
      }
    }

    return Theme(
      data: !_isCreatorOpen ? appModel.overrideDictionaryTheme ?? theme : theme,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: backgroundColor,
        appBar: _buildMinimalAppBar(),
        body: SafeArea(
          top: false,
          child: _buildBody(),
        ),
      ),
    );
  }

  /// Lean top bar: a title showing the current search term, a
  /// half-screen toggle, and a magnifying glass that opens a
  /// search dialog. No embedded text field — the page is a
  /// result viewer, not an input surface. Refining the search is
  /// an explicit gesture (tap magnifying glass → dialog) so the
  /// soft keyboard only rises when the user actually asks for it.
  ///
  /// Replaces the old FloatingSearchBar-based top bar. That
  /// package auto-focused its internal TextField on open, raising
  /// the keyboard unbidden on every word lookup; and its
  /// multi-stage WillPopScope handling required two back presses
  /// to exit. Both issues are structurally gone with this simpler
  /// AppBar design.
  PreferredSizeWidget _buildMinimalAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: ValueListenableBuilder<String>(
        valueListenable: _queryNotifier,
        builder: (context, query, _) {
          return JidoujishoMarquee(
            text: query.isEmpty ? t.search_ellipsis : query,
            style: TextStyle(
              fontSize: textTheme.titleMedium?.fontSize,
              fontWeight: FontWeight.bold,
            ),
          );
        },
      ),
      bottom: _isSearching
          ? const PreferredSize(
              preferredSize: Size.fromHeight(2),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : null,
      actions: [
        JidoujishoIconButton(
          tooltip: 'Switch to half-screen dictionary',
          icon: Icons.fullscreen_exit,
          onTap: () {
            appModel.toggleAutoFullScreenDictionary();
            if (widget.killOnPop) {
              appModel.shutdown();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        JidoujishoIconButton(
          tooltip: t.search,
          icon: Icons.search,
          onTap: _showSearchDialog,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  /// Builds the body: results, search history, placeholders, or a
  /// bare progress indicator depending on state. Mirrors the
  /// previous `buildFloatingSearchBody` dispatch logic but without
  /// the FloatingSearchBar transition parameter — we are no
  /// longer inside a FloatingSearchBar.
  Widget _buildBody() {
    if (appModel.dictionaries.isEmpty) {
      return buildImportDictionariesPlaceholderMessage();
    }
    final String currentQuery = _queryNotifier.value;
    if (currentQuery.isEmpty) {
      if (appModel
          .getSearchHistory(historyKey: DictionaryMediaType.instance.uniqueKey)
          .isEmpty) {
        return buildEnterSearchTermPlaceholderMessage();
      } else {
        return JidoujishoSearchHistory(
          uniqueKey: DictionaryMediaType.instance.uniqueKey,
          onSearchTermSelect: (searchTerm) {
            _queryNotifier.value = searchTerm;
            search(searchTerm);
          },
          onUpdate: () {
            setState(() {});
          },
        );
      }
    }
    if (_isSearching) {
      if (_result != null) {
        if (_result!.headings.isNotEmpty) {
          return buildSearchResult();
        } else {
          return buildNoSearchResultsPlaceholderMessage();
        }
      } else {
        return const SizedBox.shrink();
      }
    }
    if (_result == null || _result!.headings.isEmpty) {
      return buildNoSearchResultsPlaceholderMessage();
    }

    return buildSearchResult();
  }

  /// Opens a modal dialog with a text field prefilled to the
  /// current query. Submitting the form runs the search and
  /// closes the dialog; the user can also tap outside or hit the
  /// back button to cancel without searching. The dialog's
  /// TextField autofocuses — which raises the keyboard — because
  /// that's exactly what the user asked for by tapping the
  /// magnifying glass. No fighting the keyboard here.
  Future<void> _showSearchDialog() async {
    final TextEditingController editingController =
        TextEditingController(text: _queryNotifier.value);
    final FocusNode dialogFocus = FocusNode();
    try {
      final String? submitted = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(t.search),
            content: TextField(
              controller: editingController,
              focusNode: dialogFocus,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                Navigator.pop(dialogContext, value.trim());
              },
              decoration: InputDecoration(
                hintText: t.search_ellipsis,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(t.dialog_cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(
                    dialogContext, editingController.text.trim()),
                child: Text(t.search),
              ),
            ],
          );
        },
      );
      if (submitted != null && submitted.isNotEmpty) {
        _queryNotifier.value = submitted;
        search(submitted);
      }
    } finally {
      editingController.dispose();
      dialogFocus.dispose();
    }
  }

  void searchAgain() {
    _result = null;
    search(_queryNotifier.value);
  }

  Duration get historyDelay => Duration.zero;

  void onQueryChanged(String query) async {
    if (!appModel.autoSearchEnabled) {
      return;
    }

    if (mounted) {
      search(query);
    }
  }

  bool _showMore = false;
  String lastQuery = '';

  void search(
    String query, {
    int? overrideMaximumTerms,
  }) async {
    if (lastQuery == query && overrideMaximumTerms == null) {
      return;
    } else {
      lastQuery = query;
    }

    overrideMaximumTerms ??= appModel.maximumTerms;

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    try {
      _result = await appModel.searchDictionary(
        searchTerm: query,
        searchWithWildcards: true,
        overrideMaximumTerms: overrideMaximumTerms,
      );
    } finally {
      if (_result != null) {
        if (query == _queryNotifier.value) {
          if (mounted) {
            setState(() {
              _isSearching = false;
              _showMore = _result!.headings.length < overrideMaximumTerms!;
            });
          }
          Future.delayed(historyDelay, () async {
            if (query == _queryNotifier.value) {
              appModel.addToSearchHistory(
                historyKey: DictionaryMediaType.instance.uniqueKey,
                searchTerm: _queryNotifier.value,
              );
            }
            if (_result!.headings.isNotEmpty) {
              appModel.addToDictionaryHistory(result: _result!);
            }
          });
        }
      }
    }
  }

  @override
  void onSearch(String searchTerm, {String? sentence = ''}) async {
    await appModel.openRecursiveDictionarySearch(
      searchTerm: searchTerm,
      killOnPop: false,
      onUpdateQuery: widget.onUpdateQuery,
    );
  }

  void showDeleteSearchHistoryPrompt() async {
    Widget alertDialog = AlertDialog(
      title: Text(t.clear_search_title),
      content: Text(t.clear_browser_description),
      actions: <Widget>[
        TextButton(
          child: Text(
            t.dialog_clear,
            style: TextStyle(
              color: theme.colorScheme.primary,
            ),
          ),
          onPressed: () async {
            appModel.clearSearchHistory(
                historyKey: DictionaryMediaType.instance.uniqueKey);
            _queryNotifier.value = '';

            if (mounted) {
              Navigator.pop(context);
              setState(() {});
            }
          },
        ),
        TextButton(
          child: Text(t.dialog_cancel),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );

    await showDialog(
      context: context,
      builder: (context) => alertDialog,
    );
  }

  Widget buildSearchResult() {
    Color? cardColor;
    if (!_isCreatorOpen) {
      cardColor = appModel.overrideDictionaryColor?.withOpacity(1);
    }

    return DictionaryResultPage(
      cardColor: cardColor,
      onSearch: onSearch,
      onStash: onStash,
      onShare: onShare,
      result: _result!,
      footerWidget: footerWidget,
    );
  }

  Widget? get footerWidget {
    if (_showMore) {
      return null;
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: Spacing.of(context).insets.all.small,
        child: Tooltip(
          message: t.show_more,
          child: InkWell(
            onTap: _isSearching
                ? null
                : () async {
                    search(
                      _queryNotifier.value,
                      overrideMaximumTerms:
                          _result!.headingIds.length + appModel.maximumTerms,
                    );
                  },
            child: Container(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              width: double.maxFinite,
              child: Padding(
                padding: Spacing.of(context).insets.all.normal,
                child: Text(
                  t.show_more,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: (textTheme.labelMedium?.fontSize)! * 0.9,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Get padding meant for a placeholder message in a floating body.
  EdgeInsets get floatingBodyPadding => EdgeInsets.only(
        top: (MediaQuery.of(context).size.height / 2) -
            (AppBar().preferredSize.height * 2),
      );

  Widget buildEnterSearchTermPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: Icons.search,
        message: t.enter_search_term,
      ),
    );
  }

  Widget buildImportDictionariesPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: Icons.auto_stories_rounded,
        message: t.dictionaries_menu_empty,
      ),
    );
  }

  Widget buildNoSearchResultsPlaceholderMessage() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: Icons.search_off,
        message: t.no_search_results,
      ),
    );
  }
}
