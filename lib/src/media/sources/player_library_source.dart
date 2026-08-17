import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';

/// The video counterpart of [ReaderLibrarySource]: a browse-only
/// source merging every video that actually lives on the device —
/// local video files and videos downloaded from YouTube — into one
/// list, each row already naming its source in the metadata column.
///
/// Streamed sources are deliberately absent. YouTube search results
/// and network streams are not on the device, so they stay in their
/// own tabs; this list is "what I can watch offline".
///
/// Imports nothing and launches nothing of its own: every row opens
/// with the source that owns it, via [MediaItem.getMediaSource].
class PlayerLibrarySource extends PlayerMediaSource {
  /// Define this media source.
  PlayerLibrarySource._privateConstructor()
      : super(
          uniqueKey: 'player_library',
          sourceName: 'All videos',
          description: 'Every video on the device — local files and '
              'downloaded YouTube — in one list. Streams stay in their own '
              'sources.',
          icon: Icons.video_library,
          implementsSearch: false,
          implementsHistory: true,
        );

  /// Get the singleton instance of this media source.
  static PlayerLibrarySource get instance => _instance;

  static final PlayerLibrarySource _instance =
      PlayerLibrarySource._privateConstructor();

  /// The sources merged into this list, in the order their items are
  /// grouped before the last-played sort is applied.
  static List<PlayerMediaSource> get mergedSources => [
        PlayerLocalMediaSource.instance,
        PlayerYoutubeOfflineSource.instance,
      ];

  @override
  bool get isBrowseOnly => true;

  @override
  BaseSourcePage buildLaunchPage({MediaItem? item}) {
    return const PlaceholderSourcePage();
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const PlayerLibraryHistoryPage();
  }

  /// Browse-only: nothing to open or import at the list level.
  @override
  Future<void> onSearchBarTap({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) async {}
}
