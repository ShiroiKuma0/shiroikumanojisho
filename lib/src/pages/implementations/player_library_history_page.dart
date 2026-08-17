import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The tab body for [PlayerLibrarySource] — one list holding every
/// video that lives on the device, whether it was picked from local
/// storage or downloaded from YouTube. Each row already names its
/// source in the metadata column ([HistoryPlayerPageState.
/// buildMetadata]), and opens with that source when tapped.
class PlayerLibraryHistoryPage extends HistoryPlayerPage {
  /// Create an instance of this tab page.
  const PlayerLibraryHistoryPage({
    super.key,
  });

  @override
  HistoryPlayerPageState<HistoryPlayerPage> createState() =>
      _PlayerLibraryHistoryPageState();
}

class _PlayerLibraryHistoryPageState
    extends HistoryPlayerPageState<PlayerLibraryHistoryPage> {
  @override
  MediaSource get mediaSource => PlayerLibrarySource.instance;

  /// Local videos come from the history database; downloaded videos
  /// come from a scan of the study folder, which is the complete list
  /// for that source (it includes downloads never played here) and is
  /// already newest-first.
  ///
  /// Ordering mirrors the book shelf: last-played first, using the
  /// Isar row id as the stamp, with anything never played settling
  /// after in group order. Dart's sort is not stable, hence the index
  /// tiebreak.
  @override
  List<MediaItem> get historyItems {
    final List<MediaItem> grouped = [
      ...appModel
          .getMediaSourceHistory(mediaSource: PlayerLocalMediaSource.instance)
          .reversed,
      ...PlayerYoutubeOfflineSource.instance
          .getStudyFolderItems(appModel: appModel),
    ];

    final Map<String, int> lastPlayed = {
      for (final MediaItem item
          in appModel.getMediaTypeHistory(mediaType: mediaType))
        item.uniqueKey: item.id ?? 0,
    };

    final List<MapEntry<int, MediaItem>> indexed =
        grouped.asMap().entries.toList()
          ..sort((a, b) {
            final int recencyA = lastPlayed[a.value.uniqueKey] ?? 0;
            final int recencyB = lastPlayed[b.value.uniqueKey] ?? 0;
            if (recencyA != recencyB) {
              return recencyB.compareTo(recencyA);
            }
            return a.key.compareTo(b.key);
          });

    return indexed.map((entry) => entry.value).toList();
  }

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
