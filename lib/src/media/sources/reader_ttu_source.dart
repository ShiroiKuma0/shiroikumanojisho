import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_logs/flutter_logs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_assets_server/local_assets_server.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
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
          sourceName: 'ッツ Ebook Reader',
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

      await server.serve();
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
  List<Widget> getActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return [
      buildImportButton(
        context: context,
        ref: ref,
        appModel: appModel,
      ),
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

  /// Toolbar action for importing an EPUB straight from the Reader
  /// tab without first having to launch the TTU library manager.
  /// Sets a one-shot flag on AppModel and opens the manager — the
  /// reader page's onLoadStop consumes the flag and auto-triggers
  /// its file-picker flow once the manager DOM is available.
  ///
  /// This bypasses the in-webview `<input type="file">` chooser,
  /// which on Boox firmware crashes the device's IntentResolver
  /// system app. See _importEpubViaFilePicker on the reader page
  /// for full background.
  Widget buildImportButton({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return FloatingSearchBarAction(
      showIfOpened: true,
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: 'Import EPUB',
        icon: Icons.note_add,
        onTap: () {
          appModel.ttuImportPending = true;
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
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.settings,
        icon: Icons.settings,
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

  /// Fetch JSON for all books in IndexedDB.
  Future<List<MediaItem>> getBooksHistory({
    required AppModel appModel,
    required Language language,
    bool recursive = false,
  }) async {
    int port = getPortForLanguage(appModel.targetLanguage);

    List<MediaItem>? items;

    HeadlessInAppWebView webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:$port/'),
      ),
      onLoadStop: (controller, url) async {
        controller.evaluateJavascript(source: getHistoryJs);
      },
      onConsoleMessage: (controller, message) async {
        try {
          Map<String, dynamic> messageJson = jsonDecode(message.message);

          if (messageJson['messageType'] != null) {
            switch (messageJson['messageType']) {
              case 'history':
                try {
                  items = getItemsFromJson(messageJson, port);
                } catch (error, stack) {
                  items = [];
                  debugPrint('$error');
                  debugPrint('$stack');
                }
                break;
              case 'empty':
                if (!appModel.targetLanguage.preferVerticalReading) {
                  await controller.evaluateJavascript(
                      source:
                          'javascript:window.localStorage.setItem("writingMode", "horizontal-tb")');
                  await controller.evaluateJavascript(
                      source:
                          'javascript:window.localStorage.setItem("fontSize", 16)');
                } else {
                  await controller.evaluateJavascript(
                      source:
                          'javascript:window.localStorage.setItem("fontSize", 24)');
                }

                items = [];
                break;
              case 'error':
                items = [];
                break;
            }
          }
        } on FormatException catch (_) {}
      },
    );

    try {
      await webView.run();
      while (items == null) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      await webView.dispose();
    }

    return items!;
  }

  /// Fetch the list of history items given JSON from IndexedDB.
  List<MediaItem> getItemsFromJson(Map<String, dynamic> json, int port) {
    List<Map<String, dynamic>> bookmarks =
        List<Map<String, dynamic>>.from(jsonDecode(json['bookmark']));
    List<Map<String, dynamic>> datas =
        List<Map<String, dynamic>>.from(jsonDecode(json['data']));
    Map<int, Map<String, dynamic>> bookmarksById =
        Map<int, Map<String, dynamic>>.fromEntries(
            bookmarks.map((e) => MapEntry(e['dataId'] as int, e)));

    List<MapEntry<int, MediaItem>> itemsById = datas.mapIndexed((index, data) {
      int position = 0;
      int duration = 1;

      Map<String, dynamic>? bookmark = bookmarksById[data['id']];

      if (bookmark != null) {
        position = bookmark['exploredCharCount'] as int;
        double progress = double.parse(bookmark['progress'].toString());
        if (progress == 0) {
          duration = 1;
        } else {
          duration = position ~/ progress;
        }
      }

      String id = data['id'].toString();
      String title = data['title'] as String? ?? ' ';
      String? base64Image;
      try {
        Uri.parse(data['coverImage']);
        base64Image = data['coverImage'];
      } catch (e) {
        base64Image = null;
      }

      return MapEntry(
        index,
        MediaItem(
          mediaIdentifier: 'http://localhost:$port/b.html?id=$id&?title=$title',
          title: title,
          base64Image: base64Image,
          mediaTypeIdentifier: ReaderTtuSource.instance.mediaType.uniqueKey,
          mediaSourceIdentifier: ReaderTtuSource.instance.uniqueKey,
          position: position,
          duration: duration,
          canDelete: false,
          canEdit: true,
        ),
      );
    }).toList();

    List<int> lastOpens = datas.mapIndexed((index, data) {
      return data['lastBookOpen'] as int? ?? 0;
    }).toList();

    itemsById.sort((a, b) => lastOpens[b.key].compareTo(lastOpens[a.key]));
    List<MediaItem> itemsByLastOpened = itemsById.map((e) => e.value).toList();

    return itemsByLastOpened;
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
