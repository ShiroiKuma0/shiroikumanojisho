import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';
import 'package:path/path.dart' as path;

/// A media source for videos exported by shiroikuma-jiyudoga's "Study in
/// jisho" button. The final contract (jiyudoga ≥ 0.25.1+22): exactly one
/// MKV per video — h264 + aac remuxed with the study subtitles embedded as
/// Matroska S_TEXT/UTF8 (SubRip) tracks, mkvmerge-clean structure. Track
/// `aligned` carries the default-track flag (named `asr` instead when it
/// is the only track); `asr` (raw auto captions) rides alongside when both
/// exist. (Interim 0.25.1+19–21 flavours — WEBVTT codec IDs, stray
/// CodecPrivate — rendered no text anywhere and are simply re-exported,
/// not special-cased.) jiyudoga writes it into a study folder and fires a
/// `shiroikuma.jisho.intent.action.STUDY_VIDEO` intent at this app (handled
/// in `main.dart`); this source lists that folder as an offline YouTube
/// library. Playback and thumbnails delegate to [PlayerLocalMediaSource];
/// embedded tracks are picked up by the player page's ffmpeg extraction
/// path, which converts them to SRT — no handling is needed here. The
/// sidecar-SRT scan is also delegated and still applies to legacy exports
/// (pre-mkv mp4 + same-basename .srt/.asr.srt trios).
class PlayerYoutubeOfflineSource extends PlayerMediaSource {
  /// Define this media source.
  PlayerYoutubeOfflineSource._privateConstructor()
      : super(
          uniqueKey: 'player_youtube_offline',
          sourceName: 'Downloaded YouTube',
          description: 'Play study videos exported from jiyudoga, with '
              'generated subtitles.',
          icon: Icons.download_for_offline,
          implementsSearch: false,
          implementsHistory: true,
        );

  /// Get the singleton instance of this media type.
  static PlayerYoutubeOfflineSource get instance => _instance;

  static final PlayerYoutubeOfflineSource _instance =
      PlayerYoutubeOfflineSource._privateConstructor();

  /// The persisted study folder — the library root that jiyudoga exports
  /// into. Set from each received STUDY_VIDEO intent; null until the first
  /// intent ever arrives.
  Directory? get studyDirectory {
    String dirPath = getPreference<String>(key: 'study_dir', defaultValue: '');
    if (dirPath.isEmpty) {
      return null;
    }
    return Directory(dirPath);
  }

  /// Persist the study folder from a received intent.
  Future<void> setStudyDirectory(String dirPath) async {
    await setPreference<String>(key: 'study_dir', value: dirPath);
  }

  /// Video extensions jiyudoga exports: single mkv with embedded subtitles
  /// since jiyudoga 0.25.1+22; mp4 (with SRT sidecars) from older exports.
  static const List<String> _videoExtensions = ['.mp4', '.mkv'];

  /// List the study folder's videos as media items, newest first by file
  /// modification time. Items that already exist in Isar history are
  /// returned as their history entry so resume positions and thumbnail
  /// overrides carry over; files never opened yet get a fresh item.
  /// History entries whose file no longer exists are naturally hidden,
  /// because the listing is driven by the folder scan.
  List<MediaItem> getStudyFolderItems({required AppModel appModel}) {
    Directory? directory = studyDirectory;
    if (directory == null || !directory.existsSync()) {
      return [];
    }

    List<File> files = directory
        .listSync()
        .whereType<File>()
        .where((file) => _videoExtensions
            .contains(path.extension(file.path).toLowerCase()))
        .toList();

    Map<File, DateTime> modified = {
      for (File file in files) file: file.statSync().modified,
    };
    files.sort((a, b) => modified[b]!.compareTo(modified[a]!));

    Map<String, MediaItem> historyByPath = {
      for (MediaItem item
          in appModel.getMediaSourceHistory(mediaSource: this))
        item.mediaIdentifier: item,
    };

    return files.map((file) {
      return historyByPath[file.path] ?? getMediaItemFromPath(file.path);
    }).toList();
  }

  /// Build a fresh [MediaItem] for a study video path.
  MediaItem getMediaItemFromPath(String filePath, {String? title}) {
    return MediaItem(
      mediaIdentifier: filePath,
      title: title ?? path.basenameWithoutExtension(filePath),
      mediaTypeIdentifier: mediaType.uniqueKey,
      mediaSourceIdentifier: uniqueKey,
      position: 0,
      duration: 0,
      canDelete: true,
      canEdit: true,
    );
  }

  /// Generate and set the override thumbnail for a study video the same way
  /// [PlayerLocalMediaSource.pickVideoFile] does for picked files.
  Future<void> prepareThumbnail({
    required AppModel appModel,
    required MediaItem item,
  }) async {
    File thumbnailFile = appModel.getThumbnailFile();
    if (thumbnailFile.existsSync()) {
      thumbnailFile.deleteSync();
    }
    thumbnailFile.createSync(recursive: true);

    await PlayerLocalMediaSource.instance
        .generateThumbnail(item.mediaIdentifier, thumbnailFile.path);
    await setOverrideThumbnailFromMediaItem(
      appModel: appModel,
      item: item,
      file: thumbnailFile,
      clearOverrideImage: false,
    );
  }

  @override
  Future<VlcPlayerController> preparePlayerController({
    required AppModel appModel,
    required WidgetRef ref,
    required MediaItem item,
  }) {
    return PlayerLocalMediaSource.instance.preparePlayerController(
      appModel: appModel,
      ref: ref,
      item: item,
    );
  }

  @override
  Future<List<SubtitleItem>> prepareSubtitles({
    required AppModel appModel,
    required WidgetRef ref,
    required MediaItem item,
  }) {
    return PlayerLocalMediaSource.instance.prepareSubtitles(
      appModel: appModel,
      ref: ref,
      item: item,
    );
  }

  @override
  BaseSourcePage buildLaunchPage({
    MediaItem? item,
  }) {
    return PlayerSourcePage(
      item: item,
      source: this,
      useHistory: true,
    );
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const PlayerYoutubeOfflineHistoryPage();
  }

  @override
  Future<void> onSearchBarTap({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) async {
    Fluttertoast.showToast(msg: t.youtube_offline_empty);
  }

  @override
  List<Widget> getActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return [
      buildSettingsButton(
        appModel: appModel,
        context: context,
        ref: ref,
      ),
    ];
  }

  @override
  String getDisplaySubtitleFromMediaItem(MediaItem item) {
    return path.dirname(item.mediaIdentifier);
  }
}
