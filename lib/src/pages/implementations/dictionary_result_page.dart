import 'dart:async';

import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:spaces/spaces.dart';
import 'package:shiroikumanojisho/creator.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/pages.dart';

/// Returns the widget for a [DictionarySearchResult] which returns a
/// scrollable list of each [DictionaryEntry] in its mappings.
class DictionaryResultPage extends BasePage {
  /// Create the widget of a [DictionarySearchResult].
  const DictionaryResultPage({
    required this.result,
    required this.onSearch,
    required this.onStash,
    required this.onShare,
    this.cardColor,
    this.scrollController,
    this.opacity = 1,
    this.updateHistory = true,
    this.spaceBeforeFirstResult = true,
    this.footerWidget,
    super.key,
  });

  /// The result made from a dictionary database search.
  final DictionarySearchResult result;

  /// Action to be done upon selecting the search option.
  final Function(String) onSearch;

  /// Action to be done upon selecting the stash option.
  final Function(String) onStash;

  /// Action to be done upon selecting the share option.
  final Function(String) onShare;

  /// Whether or not to update dictionary history upon viewing this result.
  final bool updateHistory;

  /// Whether or not to put a space before the first result.
  final bool spaceBeforeFirstResult;

  /// Override color for the background color for [DictionaryTermPage].
  final Color? cardColor;

  /// Opacity for entries.
  final double opacity;

  /// Allows controlling the scroll position of the page.
  final ScrollController? scrollController;

  /// Optional footer for use for showing more.
  final Widget? footerWidget;

  @override
  BasePageState<DictionaryResultPage> createState() =>
      _DictionaryResultPageState();
}

class _DictionaryResultPageState extends BasePageState<DictionaryResultPage> {
  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
  }

  @override
  void dispose() {
    _hideIndicatorTimer?.cancel();
    _indicatorVisible.dispose();
    _indicatorSize.dispose();
    super.dispose();
  }

  late ScrollController _scrollController;

  Map<DictionaryHeading, Map<Dictionary, ExpandableController>>
      expandableControllersByHeading = {};

  // Font-size swipe state.
  //
  // The left 15% of the widget's width is a vertical-drag strip
  // that adjusts the dictionary's font size — entry body and
  // heading scaled proportionally, preserving whatever ratio the
  // user has set (defaults to 22:16 ≈ 1.375 but respects any
  // custom ratio established via the Dictionary settings dialog).
  // The ratio is captured once at the start of each drag so the
  // heading:entry relationship stays stable through the swipe.
  //
  // App-wide persistence (setDictionaryFontSize + refresh()) is
  // throttled to ~50 ms because the structured-content rebuild
  // triggered by appModel.refresh() is the main cost path — on a
  // long entry list even 20 fps rebuilds can blow the frame
  // budget, so making the indicator depend on the same rebuild
  // cadence makes the label lag the finger and the user can't
  // hit a specific target size. To decouple, the indicator uses
  // ValueNotifiers that drive tiny ValueListenableBuilder
  // subtrees at the leaves; updating them does not rebuild the
  // dictionary content, only the overlay pill's label and
  // visibility. The structured-content rebuild still runs at the
  // throttled 20 fps so the actual text resize is smooth without
  // janking the UI thread.
  double _gestureEntryFontSize = 16;
  double _gestureRatio = 22.0 / 16.0;
  final ValueNotifier<bool> _indicatorVisible = ValueNotifier<bool>(false);
  final ValueNotifier<double> _indicatorSize = ValueNotifier<double>(16);
  DateTime? _lastRefreshAt;
  Timer? _hideIndicatorTimer;

  static const double _fontSizeMin = 8;
  static const double _fontSizeMax = 60;
  static const double _headingSizeMax = 80;
  static const Duration _refreshThrottle = Duration(milliseconds: 50);

  void _onFontDragUpdate(DragUpdateDetails d) {
    // First tick of a new drag: capture starting entry size and
    // the current heading:entry ratio. `_lastRefreshAt` doubles
    // as the first-tick marker because it's nulled in
    // `_onFontDragEnd` and throttling below also reads it.
    if (_lastRefreshAt == null) {
      _gestureEntryFontSize = appModel.dictionaryFontSize;
      final double headingNow = appModel.dictionaryHeadingFontSize;
      _gestureRatio = _gestureEntryFontSize > 0
          ? headingNow / _gestureEntryFontSize
          : (22.0 / 16.0);
    }

    final double step = -d.delta.dy / 12;
    _gestureEntryFontSize = (_gestureEntryFontSize + step)
        .clamp(_fontSizeMin, _fontSizeMax);
    final double newHeading = (_gestureEntryFontSize * _gestureRatio)
        .clamp(_fontSizeMin, _headingSizeMax);

    // Overlay updates take the fast path — they do not call
    // setState so the dictionary subtree is untouched.
    _indicatorSize.value = _gestureEntryFontSize;
    _indicatorVisible.value = true;

    final DateTime now = DateTime.now();
    if (_lastRefreshAt == null ||
        now.difference(_lastRefreshAt!) >= _refreshThrottle) {
      appModel.setDictionaryFontSize(_gestureEntryFontSize);
      appModel.setDictionaryHeadingFontSize(newHeading);
      appModel.refresh();
      _lastRefreshAt = now;
    }
  }

  void _onFontDragEnd(DragEndDetails d) {
    // Always commit the final value regardless of throttle so the
    // drag's last few ticks (if they landed inside the throttle
    // window) aren't lost.
    final double finalHeading = (_gestureEntryFontSize * _gestureRatio)
        .clamp(_fontSizeMin, _headingSizeMax);
    appModel.setDictionaryFontSize(_gestureEntryFontSize);
    appModel.setDictionaryHeadingFontSize(finalHeading);
    appModel.refresh();
    _lastRefreshAt = null;
    _hideIndicatorTimer?.cancel();
    _hideIndicatorTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _indicatorVisible.value = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    AnkiMapping lastSelectedMapping = appModel.lastSelectedMapping;

    Map<int, DictionaryHeading> headingsById = Map.fromEntries(
      widget.result.headings.map(
        (heading) => MapEntry(heading.id, heading),
      ),
    );

    List<DictionaryHeading> headings =
        widget.result.headingIds.map((id) => headingsById[id]!).toList();

    List<Dictionary> dictionaries = appModel.dictionaries;
    Map<String, bool> dictionaryNamesByHidden = Map<String, bool>.fromEntries(
        dictionaries
            .map((e) => MapEntry(e.name, e.isHidden(appModel.targetLanguage))));
    Map<String, bool> dictionaryNamesByCollapsed =
        Map<String, bool>.fromEntries(dictionaries.map(
            (e) => MapEntry(e.name, e.isCollapsed(appModel.targetLanguage))));
    Map<String, int> dictionaryNamesByOrder = Map<String, int>.fromEntries(
        dictionaries.map((e) => MapEntry(e.name, e.order)));

    for (DictionaryHeading heading in headings) {
      expandableControllersByHeading.putIfAbsent(heading, () => {});
      for (DictionaryEntry entry in heading.entries) {
        Dictionary dictionary = entry.dictionary.value!;
        expandableControllersByHeading[heading]?.putIfAbsent(
          dictionary,
          () => ExpandableController(
            initialExpanded: !dictionaryNamesByCollapsed[dictionary.name]!,
          ),
        );
      }
    }

    final Widget content = MediaQuery(
      data: MediaQuery.of(context).removePadding(
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
      ),
      child: RawScrollbar(
        thumbVisibility: true,
        thickness: 3,
        controller: _scrollController,
        child: Padding(
          padding: Spacing.of(context).insets.onlyRight.extraSmall,
          child: CustomScrollView(
            cacheExtent: 999999999999999,
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                  padding: widget.spaceBeforeFirstResult
                      ? Spacing.of(context).insets.onlyTop.normal
                      : EdgeInsets.zero),
              ...headings
                  .map((heading) => DictionaryTermPage(
                        lastSelectedMapping: lastSelectedMapping,
                        opacity: widget.opacity,
                        cardColor: widget.cardColor,
                        heading: heading,
                        onSearch: widget.onSearch,
                        onStash: widget.onStash,
                        onShare: widget.onShare,
                        expandableControllers:
                            expandableControllersByHeading[heading]!,
                        dictionaryNamesByHidden: dictionaryNamesByHidden,
                        dictionaryNamesByOrder: dictionaryNamesByOrder,
                      ))
                  .toList(),
              if (widget.footerWidget != null) widget.footerWidget!,
            ],
          ),
        ),
      ),
    );

    // Left 15% of the screen width is a vertical-drag strip for
    // font sizing. Matches the reader's edge-gesture ergonomics:
    // screen-width-referenced so the strip is the same physical
    // width whether the dictionary is full-screen on the home tab
    // or in a narrower popup over the reader. `translucent` hit
    // test lets taps and horizontal swipes pass through to the
    // scroll view; only vertical drags are intercepted, and only
    // inside the strip region.
    final double fontStripWidth =
        MediaQuery.of(context).size.width * 0.15;

    return Stack(
      children: [
        content,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: fontStripWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragUpdate: _onFontDragUpdate,
            onVerticalDragEnd: _onFontDragEnd,
          ),
        ),
        // Font-size indicator pill. Listens on two notifiers so
        // the finger-tracking label repaints at gesture rate
        // without pulling the dictionary subtree into the
        // rebuild. Centered within the dictionary's local bounds
        // (not the screen) so it stays inside popup bounds when
        // the dictionary is shown in a modal.
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<bool>(
              valueListenable: _indicatorVisible,
              builder: (context, visible, child) {
                if (!visible) return const SizedBox.shrink();
                return child!;
              },
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.format_size,
                          color: Color(0xFFFFFF00), size: 28),
                      const SizedBox(height: 4),
                      ValueListenableBuilder<double>(
                        valueListenable: _indicatorSize,
                        builder: (context, size, _) {
                          return Text(
                            '${size.round()}px',
                            style: const TextStyle(
                                color: Color(0xFFFFFF00),
                                fontSize: 14),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
