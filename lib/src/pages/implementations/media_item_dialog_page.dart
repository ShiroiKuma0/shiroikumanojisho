import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:spaces/spaces.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/src/pages/implementations/media_item_edit_dialog_page.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The content of the dialog used upon long-pressing a [MediaItem].
class MediaItemDialogPage extends BasePage {
  /// Create an instance of this page.
  const MediaItemDialogPage({
    required this.item,
    required this.isHistory,
    this.extraActions,
    super.key,
  });

  /// The [MediaItem] pertaining to the page.
  final MediaItem item;

  /// Whether or not the media items are in history.
  final bool isHistory;

  /// Extra actions to include in the dialog page if supplied by a
  /// media source.
  final List<Widget>? Function(MediaItem)? extraActions;

  @override
  BasePageState createState() => _MediaItemDialogPageState();
}

class _MediaItemDialogPageState extends BasePageState<MediaItemDialogPage> {
  MediaSource get mediaSource => widget.item.getMediaSource(appModel: appModel);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: buildTitle(),
      content: buildContent(),
      actions: actions,
    );
  }

  Widget buildTitle() {
    return SelectableText(
      mediaSource.getDisplayTitleFromMediaItem(widget.item),
      selectionControls: selectionControls,
    );
  }

  Widget buildContent() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                mediaSource.icon,
                color: Theme.of(context).unselectedWidgetColor,
              ),
              const Space.small(),
              Text(
                mediaSource.getLocalisedSourceName(appModel),
                style: TextStyle(
                  color: Theme.of(context).unselectedWidgetColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ],
          ),
          const Space.normal(),
          AspectRatio(
            aspectRatio: mediaSource.aspectRatio,
            child: FadeInImage(
              placeholder: MemoryImage(kTransparentImage),
              imageErrorBuilder: (_, _, _) {
                if (widget.item.extraUrl != null) {
                  return FadeInImage(
                    placeholder: MemoryImage(kTransparentImage),
                    imageErrorBuilder: (_, _, _) => const SizedBox.expand(),
                    image: mediaSource.getDisplayThumbnailFromMediaItem(
                      appModel: appModel,
                      item: widget.item,
                      fallbackUrl: widget.item.extraUrl,
                    ),
                    fit: BoxFit.fitWidth,
                  );
                } else {
                  return const SizedBox.expand();
                }
              },
              image: mediaSource.getDisplayThumbnailFromMediaItem(
                appModel: appModel,
                item: widget.item,
              ),
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> get actions => [
        // Delete removes the media itself, for sources that own one
        // (a book in the ッツ library). Clear only forgets the
        // history row — meaningless for those, since the book would
        // still be in the library and back on the shelf next
        // refresh. No source offers both.
        if (mediaSource.canDeleteMedia && widget.isHistory)
          buildDeleteButton(),
        if (widget.item.canDelete && widget.isHistory) buildClearButton(),
        if (widget.extraActions != null) ...?widget.extraActions!(widget.item),
        if (widget.item.canEdit && widget.isHistory) buildEditButton(),
        buildLaunchButton(),
      ];

  String get launchLabel {
    MediaType mediaType = widget.item.getMediaType(appModel: appModel);
    if (mediaType == PlayerMediaType.instance) {
      return t.dialog_play;
    } else if (mediaType == ReaderMediaType.instance) {
      return t.dialog_read;
    } else if (mediaType == ViewerMediaType.instance) {
      return t.dialog_view;
    } else {
      throw UnimplementedError('Media type launch label unimplemented');
    }
  }

  Widget buildClearButton() {
    return TextButton(
      onPressed: executeClear,
      child: Text(
        t.dialog_clear,
        style: TextStyle(color: theme.colorScheme.primary),
      ),
    );
  }

  Widget buildDeleteButton() {
    return TextButton(
      onPressed: executeDelete,
      child: Text(
        t.dialog_delete,
        style: const TextStyle(color: Color(0xFFFF5252)),
      ),
    );
  }

  Widget buildLaunchButton() {
    return TextButton(
      onPressed: executeLaunch,
      child: Text(
        launchLabel,
      ),
    );
  }

  Widget buildEditButton() {
    return TextButton(
      onPressed: executeEdit,
      child: Text(t.dialog_edit),
    );
  }

  void executeEdit() async {
    await showDialog(
      context: context,
      builder: (context) => MediaItemEditDialogPage(item: widget.item),
    );
  }

  void executeLaunch() async {
    Navigator.pop(context);
    await appModel.openMedia(
      mediaSource: mediaSource,
      ref: ref,
      item: widget.item,
    );
  }

  void executeClear() async {
    final navigator = Navigator.of(context);
    await appModel.deleteMediaItem(widget.item);
    navigator.pop();
  }

  /// Delete the media itself, after confirming. Destructive and not
  /// undoable — the book leaves the ッツ library, taking its
  /// bookmarks and every per-book setting with it — so it asks
  /// first, and reports rather than silently no-ops if the delete
  /// could not be carried out.
  void executeDelete() async {
    final navigator = Navigator.of(context);
    final String title =
        mediaSource.getDisplayTitleFromMediaItem(widget.item);

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          'Delete this from ${mediaSource.getLocalisedSourceName(appModel)}? '
          'Its reading position and per-book settings go with it. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.dialog_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              t.dialog_delete,
              style: const TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    final bool deleted = await mediaSource.deleteMedia(
      appModel: appModel,
      ref: ref,
      item: widget.item,
    );

    if (!deleted) {
      Fluttertoast.showToast(msg: 'Could not delete $title.');
      return;
    }

    widget.item.getMediaType(appModel: appModel).refreshTab();
    navigator.pop();
  }
}
