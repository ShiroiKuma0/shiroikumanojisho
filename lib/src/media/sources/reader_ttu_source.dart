import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:material_floating_search_bar_2/material_floating_search_bar_2.dart';
import 'package:shiroikumanojisho/language.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/utils.dart';

/// A global [Provider] for serving a local ッツ Ebook Reader.
final ttuServerProvider =
    FutureProvider.family<LocalAssetsServer, Language>((ref, language) {
  return ReaderTtuSource.instance.serveLocalAssets(language);
});

/// A global [Provider] for getting ッツ Ebook Reader books from IndexedDB.
final ttuBooksProvider =
    FutureProvider.family<List<MediaItem>, Language>((ref, language) {
  return ReaderTtuSource.instance.getBooksHistory(
    appModel: ref.watch(appProvider),
    language: language,
  );
});

/// A media source that allows the user to read from ッツ Ebook Reader.
class ReaderTtuSource extends ReaderMediaSource {
  /// Define this media source.
  ReaderTtuSource._privateConstructor()
      : super(
          uniqueKey: 'reader_ttu',
          sourceName: 'EPUB reader (ッツ)',
          description: 'Read EPUBs and mine sentences via an embedded web'
              ' reader.',
          icon: Icons.chrome_reader_mode_outlined,
          implementsSearch: false,
          implementsHistory: false,
        );

  /// Get the singleton instance of this media type.
  static ReaderTtuSource get instance => _instance;

  static final ReaderTtuSource _instance =
      ReaderTtuSource._privateConstructor();

  /// Default scrolling speed when in continuous page turning mode.
  static int get defaultScrollingSpeed => 100;

  @override
  Future<void> onSourceExit({
    required AppModel appModel,
    required WidgetRef ref,
  }) async {
    ref.invalidate(ttuBooksProvider(appModel.targetLanguage));
    // await exportBackup(appModel: appModel);
  }

  /// Import persisted backup data back to IndexedDB if it exists.
  Future<void> importBackup({
    required InAppWebViewController controller,
    required Language language,
    required String data,
  }) async {
    FlutterLogs.logInfo(
      mediaType.uniqueKey,
      uniqueKey,
      'Restored IndexedDB.',
    );
  }

  /// Get the IndexedDB backup key for a language
  String getIndexedDBKey(Language language) {
    return 'idb_${getPortForLanguage(language)}';
  }

  /// Get the port for the current language. This port should ideally not conflict but should remain the same for
  /// caching purposes.
  int getPortForLanguage(Language language) {
    /// Language Customizable
    if (language is JapaneseLanguage) {
      return 52059;
    } else if (language is EnglishLanguage) {
      return 52060;
    }

    // Generate a stable port from the language code to avoid conflicts
    return 52060 + language.languageCode.hashCode.abs() % 1000;
  }

  /// Used to delay the serve if the server failed to launch last time. Makes
  /// retry look better for port conflicts.
  bool _lastServeFailed = false;

  /// Cache of running [LocalAssetsServer]s, keyed by their port.
  /// `serveLocalAssets` is called from multiple places: every time
  /// the user opens a TTU book in their target language, and from
  /// [AppExportImport] which iterates every language during export
  /// or import. Without this cache, the second call for the same
  /// language hits a `SocketException("The shared flag to bind()
  /// needs to be true ...")` because Dart refuses to double-bind
  /// the same address+port within one isolate without `shared:
  /// true`. Returning the existing server when present avoids that
  /// and is also a small efficiency win on repeat opens.
  static final Map<int, LocalAssetsServer> _serversByPort = {};

  /// For serving the reader assets locally. Idempotent per port:
  /// the first call binds and caches, subsequent calls return the
  /// cached server.
  Future<LocalAssetsServer> serveLocalAssets(Language language) async {
    final port = getPortForLanguage(language);

    final existing = _serversByPort[port];
    if (existing != null) {
      return existing;
    }

    if (_lastServeFailed) {
      await Future.delayed(const Duration(seconds: 1));
    }

    try {
      _lastServeFailed = false;
      final server = LocalAssetsServer(
        address: InternetAddress.loopbackIPv4,
        port: port,
        assetsBasePath: 'assets/ttu-ebook-reader',
        logger: const DebugLogger(),
      );

      // `shared: true` sets SO_REUSEPORT, so this bind succeeds even
      // when a previous app run's isolate still holds the port — on
      // Android the process (audio service, dictionary indexing) can
      // outlive the UI, and the old server is never stopped. Without
      // it, relaunching the app loops forever on "Local server port
      // already in use". The stale server serves the same assets, so
      // sharing the port with it is harmless.
      await server.serve(shared: true);
      _serversByPort[port] = server;

      return server;
    } catch (e) {
      _lastServeFailed = true;
      rethrow;
    }
  }

  @override
  BaseSourcePage buildLaunchPage({
    MediaItem? item,
  }) {
    return ReaderTtuSourcePage(item: item);
  }

  @override
  bool get canDeleteMedia => true;

  /// Delete a book from the ッツ library for good: its record in
  /// TTU's IndexedDB, this app's history row for it, and every
  /// per-book Hive entry (attached audio, translation-book
  /// association, split ratio, per-book TTU settings).
  ///
  /// The Hive purge is what makes delete-then-reimport come back
  /// clean. Per-book keys are derived from the book's title, so a
  /// re-import of the same file resolves to the same keys and would
  /// otherwise inherit the deleted book's state.
  @override
  Future<bool> deleteMedia({
    required AppModel appModel,
    required WidgetRef ref,
    required MediaItem item,
  }) async {
    final String? bookId =
        Uri.tryParse(item.mediaIdentifier)?.queryParameters['id'];
    if (bookId == null || bookId.isEmpty) {
      return false;
    }

    final Language language = appModel.targetLanguage;
    if (!await _deleteBookFromLibrary(language: language, bookId: bookId)) {
      return false;
    }

    await _purgeBookState(appModel: appModel, item: item, bookId: bookId);
    await forgetCachedBook(
      appModel: appModel,
      language: language,
      bookId: bookId,
    );

    // Drop this app's own history rows for the book, if it was ever
    // opened. Matched on the book id rather than the whole
    // identifier: rows written from inside the reader carry TTU's
    // SPA URL shape, which differs from the library listing's.
    for (final MediaItem stored
        in appModel.getMediaSourceHistory(mediaSource: this)) {
      final String? storedId =
          Uri.tryParse(stored.mediaIdentifier)?.queryParameters['id'];
      if (storedId == bookId && stored.id != null) {
        await appModel.deleteMediaItem(stored);
      }
    }

    ref.invalidate(ttuBooksProvider(language));
    return true;
  }

  /// Run the IndexedDB delete on the shared scanner webview — the
  /// same loaded ッツ origin [getBooksHistory] talks to, and the only
  /// way to reach the IndexedDB that holds the library.
  Future<bool> _deleteBookFromLibrary({
    required Language language,
    required String bookId,
  }) async {
    final int port = getPortForLanguage(language);
    try {
      final InAppWebViewController controller =
          await _scannerController(language).timeout(_scanTimeout);
      final result = await controller
          .callAsyncJavaScript(
            functionBody: deleteBookJsBody,
            arguments: {'id': bookId},
          )
          .timeout(_scanTimeout);
      return result?.error == null;
    } catch (error) {
      FlutterLogs.logError(
        mediaType.uniqueKey,
        uniqueKey,
        'Could not delete book $bookId: $error',
      );
      await _disposeScanner(port);
      return false;
    } finally {
      _scheduleScannerDisposal(port);
    }
  }

  /// Delete every per-book entry in the reader's Hive box for this
  /// book. Keys are `<prefix>_<bookKey>`, and the book key comes in
  /// two shapes — title-derived (current) and id-derived (legacy,
  /// still live until the book's first post-1.1.x open) — so both
  /// are matched.
  Future<void> _purgeBookState({
    required AppModel appModel,
    required MediaItem item,
    required String bookId,
  }) async {
    try {
      final Box box = await Hive.openBox('readerAudio');
      final String languageCode = appModel.targetLanguage.languageCode;
      final String idKey = 'book_${languageCode}_$bookId'
          .replaceAll(RegExp('[^a-zA-Z0-9]'), '_');
      final String titleKey =
          'book_${languageCode}_t_${stableHashHex(item.title)}';

      final List<dynamic> stale = box.keys.where((key) {
        final String name = key.toString();
        return name.endsWith(idKey) || name.endsWith(titleKey);
      }).toList();
      await box.deleteAll(stale);
    } catch (_) {
      // Box unopenable — the reader opens it lazily, so there is
      // nothing persisted for this book to purge.
    }
  }

  /// FNV-1a over UTF-16 code units, as hex. The content-derived
  /// component of the reader's per-book Hive keys — shared with
  /// [ReaderTtuSourcePage] so a delete purges exactly the keys a
  /// later open would read.
  static String stableHashHex(String value) {
    var h = 0x811c9dc5;
    for (final code in value.codeUnits) {
      h ^= code & 0xff;
      h = (h * 0x01000193) & 0xffffffff;
      h ^= (code >> 8) & 0xff;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  @override
  List<Widget> getActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return [
      buildTweaksButton(
        context: context,
        ref: ref,
        appModel: appModel,
      ),
      buildSettingsButton(
        context: context,
        ref: ref,
        appModel: appModel,
      ),
      buildLaunchButton(
        context: context,
        ref: ref,
        appModel: appModel,
      ),
    ];
  }

  /// App bar action for importing an EPUB straight from the Reader
  /// tab without first having to launch the TTU library manager.
  /// Sets a one-shot flag on AppModel and opens the manager — the
  /// reader page's onLoadStop consumes the flag and auto-triggers
  /// its file-picker flow once the manager DOM is available.
  ///
  /// This bypasses the in-webview `<input type="file">` chooser,
  /// which on Boox firmware crashes the device's IntentResolver
  /// system app. See _importEpubViaFilePicker on the reader page
  /// for full background.
  @override
  Widget? buildAddButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return JidoujishoIconButton(
      tooltip: 'Import EPUB',
      icon: Icons.note_add,
      onTap: () {
        appModel.ttuImportPending = true;
        appModel.openMedia(
          ref: ref,
          mediaSource: this,
        );
      },
    );
  }

  /// Allows user to close the floating search bar of a media type tab page
  /// when open.
  Widget buildLaunchButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return FloatingSearchBarAction(
      showIfOpened: true,
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.manager,
        icon: Icons.local_library_outlined,
        onTap: () {
          appModel.openMedia(
            ref: ref,
            mediaSource: this,
          );
        },
      ),
    );
  }

  /// Allows user to close the floating search bar of a media type tab page
  /// when open.
  Widget buildSettingsButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    int port = getPortForLanguage(appModel.targetLanguage);

    return FloatingSearchBarAction(
      showIfOpened: true,
      // Deliberately not a JidoujishoIconButton: that wraps itself in
      // a Tooltip, whose long-press recognizer wins the gesture arena
      // and would swallow the long-press below. Same reason the home
      // page's overflow icon is a bare InkWell.
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          appModel.openMedia(
            ref: ref,
            mediaSource: this,
            item: MediaItem(
              mediaIdentifier: 'http://localhost:$port/settings.html',
              title: '',
              mediaTypeIdentifier: ReaderTtuSource.instance.mediaType.uniqueKey,
              mediaSourceIdentifier: ReaderTtuSource.instance.uniqueKey,
              position: 0,
              duration: 1,
              canDelete: false,
              canEdit: true,
            ),
          );
        },
        // Long-press goes to the app's own appearance settings — the
        // same gesture the home page's ⋮ carries, so the UI page is
        // reachable from the Reader without leaving the tab.
        onLongPress: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (context) => const JishoUiSettingsPage(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.settings,
            color: Theme.of(context).iconTheme.color,
            size: Theme.of(context).textTheme.titleLarge?.fontSize,
          ),
        ),
      ),
    );
  }

  /// Tweaks bar action.
  Widget buildTweaksButton(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.tweaks,
        icon: Icons.tune,
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => const TtuSettingsDialogPage(),
          );
        },
      ),
    );
  }

  /// Shows when the clear button is pressed.
  void showClearPrompt(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) async {}

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const ReaderTtuSourceHistoryPage();
  }

  /// How long any one step of a library scan may take before we give
  /// up and fall back to the cache. A scan drives a webview that
  /// loads the whole ッツ app (57 MB of assets) from a Dart HTTP
  /// server running on this very isolate, so it is slow by nature
  /// and occasionally stalls outright — the old implementation had
  /// no timeout at all and spun `while (items == null)` forever when
  /// it did, which is what a permanently spinning Reader tab was.
  static const Duration _scanTimeout = Duration(seconds: 25);

  /// How long a scanner webview is kept alive after a scan. Keeping
  /// it means the next refresh skips the ッツ cold load entirely;
  /// keeping it forever means carrying a hidden Chromium page for
  /// the life of the app, so it is dropped once idle.
  static const Duration _scannerIdleTimeout = Duration(minutes: 2);

  /// Hive box holding the last known library listing per language.
  /// The Reader tab paints from this before any webview exists.
  static const String libraryBoxName = 'ttuLibrary';

  static final Map<int, HeadlessInAppWebView> _scannersByPort = {};
  static final Map<int, Completer<InAppWebViewController>>
      _scannerReadyByPort = {};
  static final Map<int, Timer> _scannerIdleTimers = {};

  @override
  Future<void> prepareResources() async {
    // Opened at startup so [cachedBooks] can stay synchronous — the
    // whole point of the cache is painting the shelf in the first
    // frame, which an async read cannot do.
    await Hive.openBox(libraryBoxName);
  }

  /// The library as of the last successful scan.
  ///
  /// Synchronous by design: the Reader tab and the All books shelf
  /// paint from this immediately and swap in the live scan when it
  /// lands, so opening the tab no longer waits on a webview. Empty
  /// before the first successful scan of a language.
  List<MediaItem> cachedBooks({required Language language}) {
    if (!Hive.isBoxOpen(libraryBoxName)) {
      return const [];
    }
    final String? raw = Hive.box(libraryBoxName).get(_libraryKey(language));
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      final List<dynamic> entries = jsonDecode(raw) as List<dynamic>;
      return entries
          .map((entry) =>
              _itemFromCache(Map<String, dynamic>.from(entry as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _libraryKey(Language language) => 'books_${language.languageCode}';

  MediaItem _itemFromCache(Map<String, dynamic> entry) {
    final String? cover = entry['cover'] as String?;
    return MediaItem(
      mediaIdentifier: entry['identifier'] as String,
      title: entry['title'] as String? ?? ' ',
      imageUrl: cover == null ? null : 'file://$cover',
      mediaTypeIdentifier: mediaType.uniqueKey,
      mediaSourceIdentifier: uniqueKey,
      position: entry['position'] as int? ?? 0,
      duration: entry['duration'] as int? ?? 1,
      canDelete: false,
      canEdit: true,
    );
  }

  /// Scan the ッツ library for [language] and return its books,
  /// newest-read first, refreshing the cache on the way.
  ///
  /// Falls back to the cached listing on any failure or timeout, so
  /// a stalled webview costs a stale list rather than a dead tab.
  Future<List<MediaItem>> getBooksHistory({
    required AppModel appModel,
    required Language language,
    bool recursive = false,
  }) async {
    final int port = getPortForLanguage(language);
    final Directory coverDirectory = _coverDirectory(appModel);

    try {
      final InAppWebViewController controller =
          await _scannerController(language).timeout(_scanTimeout);

      // Covers already on disk are not re-encoded: the base64 blob
      // conversion of every cover was the bulk of the scan payload,
      // and a cover never changes once a book is imported.
      final CallAsyncJavaScriptResult? result = await controller
          .callAsyncJavaScript(
            functionBody: scanLibraryJsBody,
            arguments: {
              'knownIds': _cachedCoverIds(language, coverDirectory),
            },
          )
          .timeout(_scanTimeout);

      if (result == null || result.error != null) {
        throw StateError(result?.error ?? 'no result from library scan');
      }

      final Map<String, dynamic> payload =
          jsonDecode(result.value as String) as Map<String, dynamic>;
      if (payload['ok'] != true) {
        throw StateError('${payload['err']}');
      }

      final List<Map<String, dynamic>> entries = await _entriesFromScan(
        payload: payload,
        port: port,
        language: language,
        coverDirectory: coverDirectory,
      );

      if (entries.isEmpty) {
        await _seedFreshLibraryDefaults(controller, appModel);
      }

      if (Hive.isBoxOpen(libraryBoxName)) {
        await Hive.box(libraryBoxName)
            .put(_libraryKey(language), jsonEncode(entries));
      }

      return entries.map(_itemFromCache).toList();
    } catch (error) {
      FlutterLogs.logWarn(
        mediaType.uniqueKey,
        uniqueKey,
        'Library scan failed, serving cache: $error',
      );
      // A scanner that timed out is assumed wedged; dropping it means
      // the next attempt starts from a fresh page instead of
      // inheriting the stall.
      await _disposeScanner(port);
      return cachedBooks(language: language);
    } finally {
      _scheduleScannerDisposal(port);
    }
  }

  /// Turn one scan payload into cache entries, writing any newly
  /// seen cover to disk. Entries are ordered by TTU's own
  /// `lastBookOpen` stamp, newest first.
  Future<List<Map<String, dynamic>>> _entriesFromScan({
    required Map<String, dynamic> payload,
    required int port,
    required Language language,
    required Directory coverDirectory,
  }) async {
    final Map<String, dynamic> bookmarksById = {
      for (final dynamic bookmark
          in (payload['bookmarks'] as List<dynamic>? ?? const []))
        '${(bookmark as Map)['dataId']}': bookmark,
    };

    final List<Map<String, dynamic>> entries = [];
    for (final dynamic raw in (payload['books'] as List<dynamic>? ?? const [])) {
      final Map<String, dynamic> book = Map<String, dynamic>.from(raw as Map);
      final String id = '${book['id']}';
      final String title = (book['title'] as String?) ?? ' ';

      int position = 0;
      int duration = 1;
      final dynamic bookmark = bookmarksById[id];
      if (bookmark != null) {
        position = (bookmark['exploredCharCount'] as num?)?.toInt() ?? 0;
        final double progress =
            double.tryParse('${bookmark['progress']}') ?? 0;
        duration = progress == 0 ? 1 : (position / progress).floor();
      }

      String? coverPath;
      final String? encoded = book['cover'] as String?;
      if (encoded != null && encoded.startsWith('data:')) {
        coverPath = await _writeCover(coverDirectory, language, id, encoded);
      } else {
        final File existing = _coverFile(coverDirectory, language, id);
        coverPath = existing.existsSync() ? existing.path : null;
      }

      entries.add({
        'id': id,
        'identifier': 'http://localhost:$port/b.html?id=$id&?title=$title',
        'title': title,
        'position': position,
        'duration': duration,
        'cover': coverPath,
        'lastOpen': (book['lastBookOpen'] as num?)?.toInt() ?? 0,
      });
    }

    entries.sort((a, b) =>
        (b['lastOpen'] as int).compareTo(a['lastOpen'] as int));
    return entries;
  }

  /// Where cover images are kept, one file per book per language.
  Directory _coverDirectory(AppModel appModel) {
    final Directory directory =
        Directory('${appModel.appDirectory.path}/ttuCovers');
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    return directory;
  }

  File _coverFile(Directory directory, Language language, String id) {
    return File('${directory.path}/${language.languageCode}_$id.img');
  }

  /// The book ids whose covers are already on disk for [language].
  List<String> _cachedCoverIds(Language language, Directory directory) {
    if (!directory.existsSync()) {
      return const [];
    }
    final String prefix = '${language.languageCode}_';
    return directory
        .listSync()
        .whereType<File>()
        .map((file) => file.path.split('/').last)
        .where((name) => name.startsWith(prefix) && name.endsWith('.img'))
        .map((name) => name.substring(prefix.length, name.length - 4))
        .toList();
  }

  Future<String?> _writeCover(
    Directory directory,
    Language language,
    String id,
    String dataUrl,
  ) async {
    try {
      final int comma = dataUrl.indexOf(',');
      if (comma == -1) {
        return null;
      }
      final File file = _coverFile(directory, language, id);
      await file.writeAsBytes(
        base64Decode(dataUrl.substring(comma + 1)),
        flush: true,
      );
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Drop one book from the cache and delete its cover, so a delete
  /// takes effect on the shelf immediately instead of lingering
  /// until the next scan lands.
  Future<void> forgetCachedBook({
    required AppModel appModel,
    required Language language,
    required String bookId,
  }) async {
    try {
      _coverFile(_coverDirectory(appModel), language, bookId).deleteSync();
    } catch (_) {}

    if (!Hive.isBoxOpen(libraryBoxName)) {
      return;
    }
    final Box box = Hive.box(libraryBoxName);
    final String? raw = box.get(_libraryKey(language));
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final List<dynamic> entries = jsonDecode(raw) as List<dynamic>;
      entries.removeWhere((entry) => '${(entry as Map)['id']}' == bookId);
      await box.put(_libraryKey(language), jsonEncode(entries));
    } catch (_) {}
  }

  /// On a library with no books, seed the writing mode and font size
  /// a fresh ッツ install should start at. Carried over from the
  /// previous scan implementation, which did this from its "empty"
  /// console message.
  Future<void> _seedFreshLibraryDefaults(
    InAppWebViewController controller,
    AppModel appModel,
  ) async {
    if (!appModel.targetLanguage.preferVerticalReading) {
      await controller.evaluateJavascript(
          source: 'window.localStorage.setItem("writingMode", '
              '"horizontal-tb")');
      await controller.evaluateJavascript(
          source: 'window.localStorage.setItem("fontSize", 16)');
    } else {
      await controller.evaluateJavascript(
          source: 'window.localStorage.setItem("fontSize", 24)');
    }
  }

  /// A loaded webview on this language's ッツ origin, shared by every
  /// caller that needs to talk to its IndexedDB (library scans, book
  /// deletes). One per port, created on demand and disposed once
  /// idle — the alternative, one webview per operation, paid the
  /// full cold load every time.
  Future<InAppWebViewController> _scannerController(Language language) async {
    final int port = getPortForLanguage(language);
    _scannerIdleTimers.remove(port)?.cancel();

    final Completer<InAppWebViewController>? existing =
        _scannerReadyByPort[port];
    if (existing != null) {
      return existing.future;
    }

    // The scan can be requested before anything has started the
    // server for this language (the books provider does not depend
    // on the server provider), and a webview pointed at a dead port
    // would simply never load.
    await serveLocalAssets(language);

    final Completer<InAppWebViewController> ready =
        Completer<InAppWebViewController>();
    _scannerReadyByPort[port] = ready;

    final HeadlessInAppWebView webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri('http://localhost:$port/')),
      onLoadStop: (controller, url) {
        if (!ready.isCompleted) {
          ready.complete(controller);
        }
      },
    );
    _scannersByPort[port] = webView;
    await webView.run();
    return ready.future;
  }

  Future<void> _disposeScanner(int port) async {
    _scannerIdleTimers.remove(port)?.cancel();
    _scannerReadyByPort.remove(port);
    final HeadlessInAppWebView? webView = _scannersByPort.remove(port);
    if (webView == null) {
      return;
    }
    try {
      await webView.dispose();
    } catch (_) {}
  }

  void _scheduleScannerDisposal(int port) {
    _scannerIdleTimers.remove(port)?.cancel();
    _scannerIdleTimers[port] = Timer(
      _scannerIdleTimeout,
      () => _disposeScanner(port),
    );
  }

  /// Whether or not using the volume buttons in the Reader should turn the
  /// page.
  bool get volumePageTurningEnabled {
    return getPreference<bool>(
        key: 'volume_page_turning_enabled', defaultValue: true);
  }

  /// Toggles the volume page turning option.
  void toggleVolumePageTurningEnabled() async {
    await setPreference<bool>(
      key: 'volume_page_turning_enabled',
      value: !volumePageTurningEnabled,
    );
  }

  /// Controls which direction is up or down for volume button page turning.
  bool get volumePageTurningInverted {
    return getPreference<bool>(
        key: 'volume_page_turning_inverted', defaultValue: false);
  }

  /// Inverts the current volume button page turning direction preference.
  void toggleVolumePageTurningInverted() async {
    await setPreference<bool>(
      key: 'volume_page_turning_inverted',
      value: !volumePageTurningInverted,
    );
  }

  /// Whether or not to add to extend the webpage beyond the navigation bar.
  /// This may be helpful for devices that don't have difficulty accessing the
  /// top bar (i.e. don't have a teardrop notch).
  bool get extendPageBeyondNavigationBar {
    return getPreference<bool>(
        key: 'extend_page_beyond_navbar', defaultValue: false);
  }

  /// Toggles the extend navbar option.
  void toggleExtendPageBeyondNavigationBar() async {
    await setPreference<bool>(
      key: 'extend_page_beyond_navbar',
      value: !extendPageBeyondNavigationBar,
    );
  }

  /// Whether or not the dictionary popup should adapt to the reader's theme.
  bool get adaptTtuTheme {
    return getPreference<bool>(key: 'adapt_ttu_theme', defaultValue: true);
  }

  /// Toggles whether dictionary popup should adapt to the reader's theme.
  void toggleAdaptTtuTheme() async {
    await setPreference<bool>(
      key: 'adapt_ttu_theme',
      value: !adaptTtuTheme,
    );
  }

  /// Controls the speed for volume button page turning.
  int get volumePageTurningSpeed {
    return getPreference<int>(
        key: 'volume_page_turning_speed', defaultValue: defaultScrollingSpeed);
  }

  /// Sets the speed for volume button page turning.
  void setVolumePageTurningSpeed(int speed) async {
    await setPreference<int>(
      key: 'volume_page_turning_speed',
      value: speed,
    );
  }

  /// Whether the reader will highlight words on tap.
  bool get highlightOnTap {
    return getPreference<bool>(
      key: 'highlight_on_tap',
      defaultValue: true,
    );
  }

  /// Toggles whether the reader will highlight words on tap.
  void toggleHighlightOnTap() async {
    await setPreference<bool>(
      key: 'highlight_on_tap',
      value: !highlightOnTap,
    );
  }

  /// Whether to show the exit-confirmation dialog when the user backs
  /// out of a book. Applies universally to all books in the reader —
  /// this preference is stored at the source level, not per-book. On
  /// by default.
  bool get confirmExit {
    return getPreference<bool>(
      key: 'reader_confirm_exit',
      defaultValue: true,
    );
  }

  /// Toggles whether the reader asks for confirmation on book exit.
  void toggleConfirmExit() async {
    await setPreference<bool>(
      key: 'reader_confirm_exit',
      value: !confirmExit,
    );
  }

  /// Used to fetch JSON for all books in IndexedDB.
  static const String getHistoryJs = '''
indexedDB.databases().then((databases) => {
  if (databases.length > 0) {
    var bookmarkJson = JSON.stringify([]);
    var dataJson = JSON.stringify([]);
    var lastItemJson = JSON.stringify([]);

    var blobToBase64 = function(blob) {
      return new Promise(resolve => {
        let reader = new FileReader();
        reader.onload = function() {
          let dataUrl = reader.result;
          resolve(dataUrl);
        };
        reader.readAsDataURL(blob);
      });
    }

    function getAllFromIDBStore(storeName) {
      return new Promise(
        function(resolve, reject) {
          var dbRequest = indexedDB.open("books");

          dbRequest.onerror = function(event) {
            reject(Error("Error opening DB"));
          };

          dbRequest.onupgradeneeded = function(event) {
            reject(Error('Not found'));
          };

          dbRequest.onsuccess = function(event) {
            var database = event.target.result;

            try {
              var transaction = database.transaction([storeName], 'readwrite');
              var objectStore;
              try {
                objectStore = transaction.objectStore(storeName);
              } catch (e) {
                reject(Error('Error getting objects'));
              }

              var objectRequest = objectStore.getAll();

              objectRequest.onerror = function(event) {
                reject(Error('Error getting objects'));
              };

              objectRequest.onsuccess = function(event) {
                if (objectRequest.result) resolve(objectRequest.result);
                else reject(Error('Objects not found'));
              }; 
            } catch (e) {
              console.log(JSON.stringify({messageType: "error", error: e.name}));
              reject(Error('Error getting objects'));
            }
          };
        }
      );
    }

    async function getTtuData() {
      try {
        items = await getAllFromIDBStore("data");
        await Promise.all(items.map(async (item) => {
          try {
            item["coverImage"] = await blobToBase64(item["coverImage"]);
          } catch (e) {}
        }));
        
        dataJson = JSON.stringify(items);
      } catch (e) {
        dataJson = JSON.stringify([]);
      }

      try {
        bookmarkJson = JSON.stringify(await getAllFromIDBStore("bookmark"));
      } catch (e) {
        bookmarkJson = JSON.stringify([]);
      }
      
      try {
        lastItemJson = JSON.stringify(await getAllFromIDBStore("lastItem"));
      } catch (e) {
        lastItemJson = JSON.stringify([]);
      }

      console.log(JSON.stringify({messageType: "history", lastItem: lastItemJson, bookmark: bookmarkJson, data: dataJson}));
    }

    try {
      getTtuData();
    } catch (e) {
      console.log(JSON.stringify({messageType: "history", lastItem: lastItemJson, bookmark: bookmarkJson, data: dataJson}));
    }
  } else {
  
    console.log(JSON.stringify({messageType: "empty"}));
    
  }
});
''';

  /// Body for `controller.callAsyncJavaScript` — wipe all three TTU
  /// IndexedDB stores (`data`, `lastItem`, `bookmark`). Used by the
  /// import path before re-populating from the bundle. Stores that
  /// do not exist yet (TTU has not finished bootstrap, schema not
  /// yet created) are ignored — the import's `putBookJsBody` etc.
  /// will fail loudly when they cannot find their target store, so
  /// we do not need to fail twice for the same condition here.
  static const String clearStoresJsBody = '''
return await new Promise((resolve, reject) => {
  const req = indexedDB.open("books");
  req.onsuccess = () => {
    try {
      const db = req.result;
      const stores = ["data", "lastItem", "bookmark"]
          .filter(n => db.objectStoreNames.contains(n));
      if (stores.length === 0) { resolve(true); return; }
      const tx = db.transaction(stores, "readwrite");
      for (const n of stores) tx.objectStore(n).clear();
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    } catch (e) { reject(e); }
  };
  req.onerror = () => reject(req.error);
});
''';

  /// Body for `controller.callAsyncJavaScript` — insert one book
  /// record into the `data` store. Pass `book` as a Map. The
  /// `coverImage` field, if present as a base64 data URL, is
  /// converted back to a Blob in-place so TTU's later renderers
  /// see the same shape they would after a normal upload.
  static const String putBookJsBody = '''
if (book && book.coverImage && typeof book.coverImage === "string"
    && book.coverImage.indexOf("data:") === 0) {
  try {
    const r = await fetch(book.coverImage);
    book.coverImage = await r.blob();
  } catch (e) { delete book.coverImage; }
}
return await new Promise((resolve, reject) => {
  const req = indexedDB.open("books");
  req.onsuccess = () => {
    try {
      const db = req.result;
      if (!db.objectStoreNames.contains("data")) {
        reject(new Error("data store missing — open TTU once first"));
        return;
      }
      const tx = db.transaction(["data"], "readwrite");
      tx.objectStore("data").put(book);
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    } catch (e) { reject(e); }
  };
  req.onerror = () => reject(req.error);
});
''';

  /// Body for `controller.callAsyncJavaScript` — read the library.
  /// Pass `knownIds`, the book ids whose covers this app already has
  /// on disk; their `coverImage` blob is skipped, which is what
  /// keeps a refresh cheap once the covers have been seen. Returns a
  /// JSON string: `{ok, books: [{id, title, lastBookOpen, cover}],
  /// bookmarks: [...]}`.
  ///
  /// Replaces the console.log-based `getHistoryJs` for the in-app
  /// listing: a returned value can be awaited with a timeout, a
  /// console message cannot. `getHistoryJs` stays for the export
  /// path, which wants every cover regardless.
  static const String scanLibraryJsBody = '''
return await new Promise((resolve) => {
  const known = new Set((knownIds || []).map(String));
  const fail = (err) => resolve(JSON.stringify({ok: false, err: String(err)}));

  const blobToBase64 = (blob) => new Promise((res) => {
    try {
      const reader = new FileReader();
      reader.onload = () => res(reader.result);
      reader.onerror = () => res(null);
      reader.readAsDataURL(blob);
    } catch (e) { res(null); }
  });

  const getAll = (db, name) => new Promise((res) => {
    if (!db.objectStoreNames.contains(name)) { res([]); return; }
    try {
      const req = db.transaction([name], "readonly").objectStore(name).getAll();
      req.onsuccess = () => res(req.result || []);
      req.onerror = () => res([]);
    } catch (e) { res([]); }
  });

  let req;
  try { req = indexedDB.open("books"); } catch (e) { fail(e); return; }
  req.onerror = () => fail("could not open the books database");
  req.onsuccess = async () => {
    try {
      const db = req.result;
      const data = await getAll(db, "data");
      const bookmarks = await getAll(db, "bookmark");
      const books = [];
      for (const item of data) {
        let cover = null;
        if (!known.has(String(item.id)) && item.coverImage) {
          cover = (typeof item.coverImage === "string")
              ? item.coverImage
              : await blobToBase64(item.coverImage);
        }
        books.push({
          id: item.id,
          title: item.title,
          lastBookOpen: item.lastBookOpen || 0,
          cover: cover,
        });
      }
      resolve(JSON.stringify({ok: true, books: books, bookmarks: bookmarks}));
    } catch (e) { fail(e && e.message || e); }
  };
});
''';

  /// Body for `controller.callAsyncJavaScript` — delete one book and
  /// everything TTU keeps about it. Pass `id` as the book id (the
  /// `?id=` of a book URL).
  ///
  /// `data` is keyed by that id directly. `bookmark` and `lastItem`
  /// rows reference it as `dataId` and have keys of their own, so
  /// they are walked with a cursor. Leaving the `lastItem` pointer
  /// behind would have TTU try to reopen a book that no longer
  /// exists on next launch.
  static const String deleteBookJsBody = '''
return await new Promise((resolve, reject) => {
  const req = indexedDB.open("books");
  req.onsuccess = () => {
    try {
      const db = req.result;
      const stores = ["data", "lastItem", "bookmark"]
          .filter(n => db.objectStoreNames.contains(n));
      if (stores.length === 0) { resolve(true); return; }
      const target = Number(id);
      const tx = db.transaction(stores, "readwrite");
      if (db.objectStoreNames.contains("data")) {
        tx.objectStore("data").delete(target);
      }
      for (const name of ["bookmark", "lastItem"]) {
        if (!db.objectStoreNames.contains(name)) continue;
        const cursorReq = tx.objectStore(name).openCursor();
        cursorReq.onsuccess = (event) => {
          const cursor = event.target.result;
          if (!cursor) return;
          const value = cursor.value || {};
          if (Number(value.dataId) === target) cursor.delete();
          cursor.continue();
        };
      }
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    } catch (e) { reject(e); }
  };
  req.onerror = () => reject(req.error);
});
''';

  /// Body for `controller.callAsyncJavaScript` — insert all
  /// entries into the `lastItem` store. Pass `items` as a List.
  static const String putLastItemsJsBody = '''
if (!items || items.length === 0) return true;
return await new Promise((resolve, reject) => {
  const req = indexedDB.open("books");
  req.onsuccess = () => {
    try {
      const db = req.result;
      if (!db.objectStoreNames.contains("lastItem")) {
        resolve(true); return;
      }
      const tx = db.transaction(["lastItem"], "readwrite");
      const store = tx.objectStore("lastItem");
      for (const item of items) store.put(item);
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    } catch (e) { reject(e); }
  };
  req.onerror = () => reject(req.error);
});
''';

  /// Body for `controller.callAsyncJavaScript` — insert all
  /// entries into the `bookmark` store. Pass `items` as a List.
  static const String putBookmarksJsBody = '''
if (!items || items.length === 0) return true;
return await new Promise((resolve, reject) => {
  const req = indexedDB.open("books");
  req.onsuccess = () => {
    try {
      const db = req.result;
      if (!db.objectStoreNames.contains("bookmark")) {
        resolve(true); return;
      }
      const tx = db.transaction(["bookmark"], "readwrite");
      const store = tx.objectStore("bookmark");
      for (const item of items) store.put(item);
      tx.oncomplete = () => resolve(true);
      tx.onerror = () => reject(tx.error);
    } catch (e) { reject(e); }
  };
  req.onerror = () => reject(req.error);
});
''';

  /// Used to fetch JSON for all books in IndexedDB.
  static const String get = '''
indexedDB.databases().then((databases) => {
  if (databases.length > 0) {
    var bookmarkJson = JSON.stringify([]);
    var dataJson = JSON.stringify([]);
    var lastItemJson = JSON.stringify([]);

    var blobToBase64 = function(blob) {
      return new Promise(resolve => {
        let reader = new FileReader();
        reader.onload = function() {
          let dataUrl = reader.result;
          resolve(dataUrl);
        };
        reader.readAsDataURL(blob);
      });
    }

    function getAllFromIDBStore(storeName) {
      return new Promise(
        function(resolve, reject) {
          var dbRequest = indexedDB.open("books");

          dbRequest.onerror = function(event) {
            reject(Error("Error opening DB"));
          };

          dbRequest.onupgradeneeded = function(event) {
            reject(Error('Not found'));
          };

          dbRequest.onsuccess = function(event) {
            var database = event.target.result;

            try {
              var transaction = database.transaction([storeName], 'readwrite');
              var objectStore;
              try {
                objectStore = transaction.objectStore(storeName);
              } catch (e) {
                reject(Error('Error getting objects'));
              }

              var objectRequest = objectStore.getAll();

              objectRequest.onerror = function(event) {
                reject(Error('Error getting objects'));
              };

              objectRequest.onsuccess = function(event) {
                if (objectRequest.result) resolve(objectRequest.result);
                else reject(Error('Objects not found'));
              }; 
            } catch (e) {
              console.log(JSON.stringify({messageType: "error", error: e.name}));
              reject(Error('Error getting objects'));
            }
          };
        }
      );
    }

    async function getTtuData() {
      try {
        items = await getAllFromIDBStore("data");
        await Promise.all(items.map(async (item) => {
          try {
            item["coverImage"] = await blobToBase64(item["coverImage"]);
          } catch (e) {}
        }));
        
        dataJson = JSON.stringify(items);
      } catch (e) {
        dataJson = JSON.stringify([]);
      }

      try {
        bookmarkJson = JSON.stringify(await getAllFromIDBStore("bookmark"));
      } catch (e) {
        bookmarkJson = JSON.stringify([]);
      }
      
      try {
        lastItemJson = JSON.stringify(await getAllFromIDBStore("lastItem"));
      } catch (e) {
        lastItemJson = JSON.stringify([]);
      }

      console.log(JSON.stringify({messageType: "history", lastItem: lastItemJson, bookmark: bookmarkJson, data: dataJson}));
    }

    try {
      getTtuData();
    } catch (e) {
      console.log(JSON.stringify({messageType: "history", lastItem: lastItemJson, bookmark: bookmarkJson, data: dataJson}));
    }
  } else {
  
    console.log(JSON.stringify({messageType: "empty"}));
    
  }
});
''';

  /// This ensures that the internal version included with the app always uses
  /// the cache and is consistent. If this version changes and the current stored
  /// last version mismatches, a load from network is forced. The app will then
  /// update its new last version, and all new loads will be from the cache
  /// unless there is a new app version loaded with a different internal version.
  static const ttuInternalVersion = 2;

  /// Used to check for the current version.
  int? get currentTtuInternalVersion {
    return getPreference<int?>(key: 'ttu_internal_version', defaultValue: null);
  }

  /// Sets the new version.
  void setTtuInternalVersion() async {
    await setPreference<int?>(
      key: 'ttu_internal_version',
      value: ttuInternalVersion,
    );
  }
}
