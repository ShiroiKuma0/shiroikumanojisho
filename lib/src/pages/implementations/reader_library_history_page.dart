import 'package:flutter/material.dart';
// For AsyncValue's `valueOrNull` — it lives on an extension, not on
// the class, so it is not in scope through the barrels alone.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiroikumanojisho/language.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The tab body for [ReaderLibrarySource] — one shelf holding every
/// imported book regardless of which source owns it, each tile badged
/// with that source's icon. Tapping a tile opens it with its own
/// source (see [BaseHistoryPageState.buildMediaItem]), so the shelf
/// itself never has to know how to display anything.
class ReaderLibraryHistoryPage extends HistoryReaderPage {
  /// Create an instance of this tab page.
  const ReaderLibraryHistoryPage({
    super.key,
  });

  @override
  BaseHistoryPageState<BaseHistoryPage> createState() =>
      _ReaderLibraryHistoryPageState();
}

class _ReaderLibraryHistoryPageState<T extends HistoryReaderPage>
    extends HistoryReaderPageState {
  @override
  MediaType get mediaType => ReaderMediaType.instance;

  @override
  ReaderLibrarySource get mediaSource => ReaderLibrarySource.instance;

  @override
  bool get showSourceBadge => true;

  @override
  void initState() {
    super.initState();
    mediaType.tabRefreshNotifier.addListener(refresh);
  }

  @override
  void dispose() {
    mediaType.tabRefreshNotifier.removeListener(refresh);
    super.dispose();
  }

  /// Refresh the page and respond to history changes.
  void refresh() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<MediaItem> items = _shelf();

    if (items.isEmpty) {
      return buildPlaceholder();
    } else {
      return buildHistory(items);
    }
  }

  /// Every book, newest-read first.
  ///
  /// The three sources are read differently on purpose. EPUBs live in
  /// the TTU reader's IndexedDB rather than this app's database, so
  /// they come from the same provider the EPUB tab uses — which
  /// yields the whole library, including books never opened here.
  /// Scanned PDFs and mokuro volumes have no such external library:
  /// their imports go straight into the Isar history, which is
  /// therefore the complete list for them.
  ///
  /// A ッツ scan has to boot the whole reader in a webview before it
  /// can answer, so the shelf never waits on it: it takes the cached
  /// listing (written by the last successful scan) and lets the live
  /// result replace it when it lands.
  List<MediaItem> _shelf() {
    final Language language = appModel.targetLanguage;
    final List<MediaItem> epubs =
        ref.watch(ttuBooksProvider(language)).valueOrNull ??
            ReaderTtuSource.instance.cachedBooks(language: language);

    final List<MediaItem> grouped = [
      ...epubs,
      ...appModel
          .getMediaSourceHistory(mediaSource: ReaderScannedPdfSource.instance)
          .reversed,
      ...appModel
          .getMediaSourceHistory(mediaSource: ReaderMokuroSource.instance)
          .reversed,
    ];

    // Recency across sources: an Isar row is written every time a
    // book is opened and its auto-increment id only ever grows, so
    // the id doubles as a last-opened stamp without adding a field to
    // the schema. Books with no row (an EPUB sitting in the TTU
    // library that has never been opened here) score 0 and settle
    // after everything that has been read, in their group order —
    // hence the index tiebreak, since Dart's sort is not stable.
    final Map<String, int> lastOpened = {
      for (final MediaItem item
          in appModel.getMediaTypeHistory(mediaType: mediaType))
        item.uniqueKey: item.id ?? 0,
    };

    final List<MapEntry<int, MediaItem>> indexed =
        grouped.asMap().entries.toList()
          ..sort((a, b) {
            final int recencyA = lastOpened[a.value.uniqueKey] ?? 0;
            final int recencyB = lastOpened[b.value.uniqueKey] ?? 0;
            if (recencyA != recencyB) {
              return recencyB.compareTo(recencyA);
            }
            return a.key.compareTo(b.key);
          });

    return indexed.map((entry) => entry.value).toList();
  }

  /// This is shown as the body when the shelf is empty.
  @override
  Widget buildPlaceholder() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: mediaSource.icon,
        message: t.info_empty_home_tab,
      ),
    );
  }
}
