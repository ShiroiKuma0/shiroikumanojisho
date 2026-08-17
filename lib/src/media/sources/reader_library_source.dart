import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';

/// A browse-only source that merges every book source into a single
/// shelf: EPUBs held by the ッツ reader, OCR'd scanned PDFs, and
/// mokuro manga volumes, each tile badged with the source it came
/// from. It imports nothing of its own — importing stays with the
/// individual sources, which own the file formats and their pickers —
/// and it launches nothing of its own either: every tile opens with
/// the source that owns it, via [MediaItem.getMediaSource].
///
/// Registered first for its media type, so it is both the top entry
/// of the source picker and the fallback source for a fresh install.
class ReaderLibrarySource extends ReaderMediaSource {
  /// Define this media source.
  ReaderLibrarySource._privateConstructor()
      : super(
          uniqueKey: 'reader_library',
          sourceName: 'All books',
          description: 'Every book already imported — EPUBs, scanned PDFs '
              'and manga volumes — on one shelf. Import from the individual '
              'sources; this one only reads.',
          icon: Icons.auto_stories,
          implementsSearch: false,
          implementsHistory: true,
        );

  /// Get the singleton instance of this media source.
  static ReaderLibrarySource get instance => _instance;

  static final ReaderLibrarySource _instance =
      ReaderLibrarySource._privateConstructor();

  /// The sources merged into this shelf, in the order their items are
  /// grouped before the last-opened sort is applied. Sources that
  /// hold no imported books — browser, clipboard, ChatGPT, WebSocket,
  /// lyrics — are deliberately absent: they have nothing to shelve.
  static List<ReaderMediaSource> get mergedSources => [
        ReaderTtuSource.instance,
        ReaderScannedPdfSource.instance,
        ReaderMokuroSource.instance,
      ];

  @override
  bool get isBrowseOnly => true;

  @override
  BaseSourcePage buildLaunchPage({MediaItem? item}) {
    return const PlaceholderSourcePage();
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const ReaderLibraryHistoryPage();
  }

  /// Browse-only: there is nothing to open or import at the shelf
  /// level, so the bar's open action does nothing rather than
  /// launching an empty placeholder page.
  @override
  Future<void> onSearchBarTap({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) async {}
}
