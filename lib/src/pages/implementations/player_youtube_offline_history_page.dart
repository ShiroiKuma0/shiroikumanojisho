import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The tab body for [PlayerYoutubeOfflineSource]. Unlike the shared
/// [HistoryPlayerPage] — which shows the whole player history — this page
/// is driven by a scan of the persisted study folder: it lists that
/// folder's videos newest-first, merged with Isar history for resume
/// positions, and hides history entries whose file has been deleted.
class PlayerYoutubeOfflineHistoryPage extends HistoryPlayerPage {
  /// Create an instance of this tab page.
  const PlayerYoutubeOfflineHistoryPage({
    super.key,
  });

  @override
  HistoryPlayerPageState<HistoryPlayerPage> createState() =>
      _PlayerYoutubeOfflineHistoryPageState();
}

class _PlayerYoutubeOfflineHistoryPageState
    extends HistoryPlayerPageState<PlayerYoutubeOfflineHistoryPage> {
  @override
  MediaSource get mediaSource => PlayerYoutubeOfflineSource.instance;

  /// The folder scan is already newest-first, which is the order
  /// [HistoryPlayerPageState.buildHistory] renders in.
  @override
  List<MediaItem> get historyItems => PlayerYoutubeOfflineSource.instance
      .getStudyFolderItems(appModel: appModel);

  @override
  Widget buildPlaceholder() {
    return Center(
      child: JidoujishoPlaceholderMessage(
        icon: mediaSource.icon,
        message: t.youtube_offline_empty,
      ),
    );
  }
}
