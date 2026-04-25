import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:spaces/spaces.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';

/// A default page for a [ReaderMediaSource]'s tab body content when selected
/// as a source in the main menu.
class HistoryReaderPage extends BaseHistoryPage {
  /// Create an instance of this tab page.
  const HistoryReaderPage({
    super.key,
  });

  @override
  BaseHistoryPageState<BaseHistoryPage> createState() =>
      HistoryReaderPageState();
}

/// A base class for providing all tabs in the main menu. In large part, this
/// was implemented to define shortcuts for common lengthy methods across UI
/// code.
class HistoryReaderPageState<T extends BaseHistoryPage>
    extends BaseHistoryPageState {
  /// This variable is true when the [buildPlaceholder] should be shown.
  /// For example, if a certain media type does not have any media items to
  /// show in its history.

  /// Hive box used by the TTU reader to persist per-book audio
  /// (`mp3_<key>`) and translation-book (`secondary_url_<key>`)
  /// associations. Opened at page level so each tile's icon
  /// lookup is a synchronous Hive read rather than an async
  /// future-per-tile that would flicker on first render.
  ///
  /// `Hive.openBox` is idempotent for the same box name — if
  /// the user has the reader open in another tab and we both
  /// call openBox, Hive returns the same instance to both
  /// callers. So this is safe to open here regardless of
  /// reader-page state.
  Box? _readerAudioBox;

  @override
  void initState() {
    super.initState();
    _openReaderAudioBox();
  }

  Future<void> _openReaderAudioBox() async {
    try {
      final Box box = await Hive.openBox('readerAudio');
      if (!mounted) return;
      setState(() {
        _readerAudioBox = box;
      });
    } catch (_) {
      // If the box fails to open we just don't show the icons.
      // Reader still works because it opens the box itself.
    }
  }

  /// Compute the Hive lookup key for a TTU MediaItem so we can
  /// check whether the user has attached audio or a translation
  /// book to it. Mirrors the TTU reader page's `_safeBookKey`
  /// path 1 (URL-derived id) since that's the path used for any
  /// book opened through the TTU library manager — the only path
  /// that can produce a usable storage entry, because path 2's
  /// fallback only fires for non-library launches like settings.
  ///
  /// Returns null if the item isn't a TTU book (no `?id=` in
  /// its mediaIdentifier) — non-TTU reader sources don't use
  /// the readerAudio box at all, so their tiles never get icons.
  String? _ttuStorageKey(MediaItem item) {
    final Uri? uri = Uri.tryParse(item.mediaIdentifier);
    if (uri == null) return null;
    final String? id = uri.queryParameters['id'];
    if (id == null || id.isEmpty) return null;
    final String languageCode = appModel.targetLanguage.languageCode;
    final String raw = 'book_${languageCode}_$id';
    return raw.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  }

  bool _hasTranslationBook(MediaItem item) {
    final Box? box = _readerAudioBox;
    if (box == null) return false;
    final String? key = _ttuStorageKey(item);
    if (key == null) return false;
    return box.get('secondary_url_$key') != null;
  }

  bool _hasAudio(MediaItem item) {
    final Box? box = _readerAudioBox;
    if (box == null) return false;
    final String? key = _ttuStorageKey(item);
    if (key == null) return false;
    return box.get('mp3_$key') != null;
  }

  /// Each tab in the home page represents a media type.
  @override
  MediaType get mediaType => ReaderMediaType.instance;

  /// Get the active media source for the current media type.
  @override
  MediaSource get mediaSource =>
      appModel.getCurrentSourceForMediaType(mediaType: mediaType);

  @override
  bool get shouldPlaceholderBeShown => true;

  @override
  Widget build(BuildContext context) {
    List<MediaItem> items = appModel.getMediaTypeHistory(mediaType: mediaType);

    if (shouldPlaceholderBeShown) {
      return buildPlaceholder();
    } else {
      return buildHistory(items);
    }
  }

  /// This is shown as the body when [shouldPlaceholderBeShown] is false.
  @override
  Widget buildHistory(List<MediaItem> items) {
    return RawScrollbar(
      thumbVisibility: true,
      thickness: 3,
      controller: mediaType.scrollController,
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 48),
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 150,
          childAspectRatio: mediaSource.aspectRatio,
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        controller: mediaType.scrollController,
        itemCount: items.length,
        itemBuilder: (context, index) => buildMediaItem(items[index]),
      ),
    );
  }

  /// Build the widget visually representing the [MediaItem]'s history tile.
  @override
  Widget buildMediaItemContent(MediaItem item) {
    final bool showAudio = _hasAudio(item);
    final bool showTranslation = _hasTranslationBook(item);

    return Container(
      padding: Spacing.of(context).insets.all.normal,
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          ColoredBox(
            color: Colors.grey.shade800.withOpacity(0.3),
            child: AspectRatio(
              aspectRatio: mediaSource.aspectRatio,
              child: FadeInImage(
                key: UniqueKey(),
                imageErrorBuilder: (_, __, ___) => const SizedBox.shrink(),
                placeholder: MemoryImage(kTransparentImage),
                image: mediaSource.getDisplayThumbnailFromMediaItem(
                  appModel: appModel,
                  item: item,
                ),
                alignment: Alignment.topCenter,
                fit: BoxFit.fitHeight,
              ),
            ),
          ),
          // Top-row attachment badges. Translation icon at top-left,
          // audio icon at top-right. Each badge is rendered only
          // when the user has attached the corresponding asset to
          // this book in the reader. No padding wrapper at the row
          // level so the icons sit flush in the corners; the icon
          // backgrounds carry their own internal padding to keep
          // touch targets visually consistent with the title bar.
          if (showAudio || showTranslation)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (showTranslation)
                    _buildAttachmentBadge(Icons.translate)
                  else
                    const SizedBox.shrink(),
                  if (showAudio)
                    _buildAttachmentBadge(Icons.headphones)
                  else
                    const SizedBox.shrink(),
                ],
              ),
            ),
          LayoutBuilder(builder: (context, constraints) {
            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
              height: constraints.maxHeight * 0.25,
              width: double.maxFinite,
              color: Colors.black.withOpacity(0.6),
              child: Text(
                mediaSource.getDisplayTitleFromMediaItem(item),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
                softWrap: true,
                style: textTheme.bodySmall!.copyWith(
                    color: const Color(0xFFFFFF00),
                    fontSize: textTheme.bodySmall!.fontSize! * 0.9),
              ),
            );
          }),
          LinearProgressIndicator(
            value: (item.position / item.duration).isNaN ||
                    (item.position / item.duration) == double.infinity ||
                    (item.position == 0 && item.duration == 0)
                ? 0
                : ((item.position / item.duration) > 0.97)
                    ? 1
                    : (item.position / item.duration),
            backgroundColor: Colors.white.withOpacity(0.6),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
            minHeight: 2,
          ),
        ],
      ),
    );
  }

  /// Single attachment-badge pill drawn on a book tile's top row.
  /// Matches the title bar's styling (semi-transparent black
  /// background, white icon) so the two overlay strips read as
  /// part of the same visual treatment.
  Widget _buildAttachmentBadge(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFFFF00),
        size: 14,
      ),
    );
  }
}
