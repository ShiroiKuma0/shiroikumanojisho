import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:isar/isar.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:shiroikumanojisho/creator.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/language.dart';
import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/src/media/sources/reader_ttu_source.dart';
import 'package:shiroikumanojisho/src/utils/components/folder_file_picker.dart';
import 'package:shiroikumanojisho/src/utils/misc/browser_bookmark.dart';
import 'package:shiroikumanojisho/src/utils/misc/mokuro_catalog.dart';

/// Cross-device data migration via semantic export/import.
///
/// Where [AppBackupRestore] takes a binary snapshot of the app data
/// directory (correct for same-device snapshots, broken for
/// cross-device because the WebView IDB lives in a vendor-specific
/// subdirectory), this class exports the user's data as structured
/// records and reconstructs them on the destination by replaying the
/// app's own write paths.
///
/// What goes in the bundle:
///
/// - **manifest.json**: bundle schema version, source device info,
///   languages with TTU data.
/// - **isar/**: per-collection JSONL dumps. One row per line, with
///   bytes (e.g. `DictionaryEntry.compressedDefinitions`) base64-
///   encoded inline. Streaming-friendly on both write and read so
///   memory does not balloon for libraries with hundreds of
///   thousands of dictionary entries.
/// - **hive/**: flat JSON dump of `readerAudio` (per-book reader
///   settings, secondary book associations, font sizes) and
///   `appModel` (target language, theme, custom storage path,
///   miscellaneous preferences).
/// - **ttu/<language>/**: per-language TTU IndexedDB dump produced
///   by running `ReaderTtuSource.getHistoryJs` in a headless
///   WebView. Contains the parsed `data` store (books, `coverImage`
///   as base64 data URLs), `lastItem` store, and `bookmark` store
///   (per-book reading position and progress).
/// - **dictionaryResources/**: passthrough copy of the
///   per-dictionary asset directory (font binaries, structured-
///   content images).
///
/// What does NOT go in:
///
/// - WebView caches — recreated on first use.
/// - Audio file binaries — they live on shared storage outside the
///   app sandbox, and a typical library is tens to hundreds of GB.
///   We export the path REFERENCES inside MediaItem rows; if those
///   paths do not resolve on the destination, the import wraps up
///   with an interactive base-directory remap pass.
///
/// Schema versioning: the manifest's `bundle_schema` integer must
/// match `_bundleSchemaVersion` on import. The import refuses any
/// other version outright; that keeps "I imported a thing and it
/// half-worked" out of the failure modes.
class AppExportImport {
  /// Bundle format version. Bump when adding new top-level files
  /// or changing the JSON shape of any existing file.
  static const int _bundleSchemaVersion = 1;

  // -------------------------------------------------------------
  // EXPORT
  // -------------------------------------------------------------

  /// Build a portable export bundle. Saves a ZIP under
  /// `/storage/emulated/0/tmp/` and offers a share dialog.
  static Future<void> exportData({
    required AppModel appModel,
    required BuildContext context,
  }) async {
    final navigator = Navigator.of(context);
    final log = _ExLog.create('export');

    // Six major steps: stage, isar, hive, ttu, dictResources, zip.
    // Manifest is folded into the staging step (cheap).
    final tracker = LongOpProgressTracker(
      operation: 'Exporting',
      totalSteps: 6,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LongOpProgressDialog(
        titleNotifier: tracker.titleNotifier,
        bodyNotifier: tracker.bodyNotifier,
      ),
    );

    // Tracked separately so the failure path can clean it up too —
    // null until staging has been created.
    String? stagingPathForCleanup;

    try {
      log.write('=== export start ===');
      tracker.step('Setting up staging...');

      // External storage so we are not fighting the app data
      // partition during a possibly-large export.
      final tmpRoot = Directory('/storage/emulated/0/tmp');
      if (!tmpRoot.existsSync()) tmpRoot.createSync(recursive: true);
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final stagingName = 'shiroikumanojisho_export_staging_$timestamp';
      final staging = Directory(path.join(tmpRoot.path, stagingName));
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      staging.createSync(recursive: true);
      stagingPathForCleanup = staging.path;
      log.write('staging: ${staging.path}');

      // ---- manifest skeleton ----
      // Writing manifest is folded into the staging step — it is
      // a single small file and not worth its own user-visible
      // step counter slot.
      tracker.detail('Writing manifest...');
      final manifest = <String, dynamic>{
        'bundle_schema': _bundleSchemaVersion,
        'created_at': DateTime.now().toIso8601String(),
        'app_languages': appModel.languages.values
            .map((l) => {
                  'code': l.languageCode,
                  'country': l.languageCountryCode,
                })
            .toList(),
      };
      // Populated as we walk languages below.
      final ttuLanguages = <String>[];
      manifest['ttu_languages'] = ttuLanguages;

      // ---- isar dumps ----
      tracker.step('Exporting database...');
      final isarDir = Directory(path.join(staging.path, 'isar'));
      isarDir.createSync(recursive: true);
      final isarRowCounts = await _exportIsar(appModel, isarDir, log, tracker);
      manifest['isar_row_counts'] = isarRowCounts;

      // ---- hive dumps ----
      tracker.step('Exporting preferences...');
      final hiveDir = Directory(path.join(staging.path, 'hive'));
      hiveDir.createSync(recursive: true);
      await _exportHive(appModel, hiveDir, log);

      // ---- per-language TTU IndexedDB ----
      tracker.step('Exporting books...');
      final ttuRoot = Directory(path.join(staging.path, 'ttu'));
      ttuRoot.createSync(recursive: true);
      final langs = appModel.languages.values.toList();
      for (var i = 0; i < langs.length; i++) {
        final lang = langs[i];
        tracker.detail(
            'Exporting books: ${lang.languageCode} (${i + 1}/${langs.length})...');
        try {
          final out = Directory(path.join(ttuRoot.path, lang.languageCode));
          out.createSync(recursive: true);
          final hadAny = await _exportTtuForLanguage(lang, out, log);
          if (hadAny) ttuLanguages.add(lang.languageCode);
        } catch (e, st) {
          log.error('ttu export failed for ${lang.languageCode}: $e\n$st');
        }
      }

      // ---- dictionaryResources passthrough ----
      tracker.step('Copying dictionary resources...');
      final dictResSrc = Directory(
          path.join(appModel.appDirectory.path, 'dictionaryResources'));
      if (dictResSrc.existsSync()) {
        final dictResDst =
            Directory(path.join(staging.path, 'dictionaryResources'));
        dictResDst.createSync(recursive: true);
        await _copyDirectoryWithProgress(
          dictResSrc,
          dictResDst,
          onProgress: (copied, total) {
            final fmt = NumberFormat.decimalPattern();
            tracker.detail(
                'Copying dictionary resources... '
                '(${fmt.format(copied)}/${fmt.format(total)})');
          },
        );
        manifest['has_dictionary_resources'] = true;
      } else {
        manifest['has_dictionary_resources'] = false;
      }

      // Write manifest last so it reflects what we actually produced.
      await File(path.join(staging.path, 'manifest.json'))
          .writeAsString(jsonEncode(manifest));

      // ---- zip up ----
      // ZIP via flutter_archive's native ZipFile. We tried tar
      // (uncompressed) for a couple of revisions to skip
      // compression overhead, but on Boox flash the import-side
      // extract was still very slow because per-file syscall and
      // journal-write overhead dominates regardless of archive
      // format, AND the resulting ~3.7 GB bundle was awkward to
      // move between devices. ZIP gets us back to ~1.3 GB with
      // gzip-equivalent (DEFLATE) compression. Decompression
      // overhead on ARM is fast enough that the smaller-file
      // win on flash read more than compensates.
      tracker.step('Compressing...');
      final zipName = 'shiroikumanojisho_export_$timestamp.zip';
      final zipFile = File(path.join(tmpRoot.path, zipName));
      if (zipFile.existsSync()) zipFile.deleteSync();
      log.write('zipping to ${zipFile.path}');
      await ZipFile.createFromDirectory(
        sourceDir: staging,
        zipFile: zipFile,
        onZipping: (fileName, isDirectory, progressPercent) {
          // `progressPercent` is 0–100 (a double). The
          // flutter_archive plugin invokes this on the platform's
          // worker thread per file; the Dart-side dialog updates
          // trigger a setState and keep the spinner animation
          // lively even on slow Android flash where compression
          // of a multi-GB staging dir can take several minutes.
          tracker.detail(
              'Compressing... (${progressPercent.toStringAsFixed(0)}%)');
          return ZipFileOperation.includeItem;
        },
      );
      log.write('zip done, size=${zipFile.statSync().size}');

      // Async-delete the staging dir with per-file progress.
      // On Boox flash a 3+ GB staging dir takes 30+ seconds to
      // recursively delete; without per-file progress the dialog
      // looks frozen at "Cleaning up..." for the whole duration.
      tracker.detail('Cleaning up...');
      try {
        await _deleteDirectoryWithProgress(
          staging,
          onPhase: (phase) => tracker.detail('Cleaning up: $phase'),
          onProgress: (deleted, total) {
            final fmt = NumberFormat.decimalPattern();
            tracker.detail(
                'Cleaning up: '
                '(${fmt.format(deleted)}/${fmt.format(total)})');
          },
        );
        log.write('removed staging: ${staging.path}');
      } catch (e) {
        log.error('failed to remove staging: $e');
      }
      log.close();

      if (navigator.canPop()) navigator.pop();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export complete'),
            content: Text(
                'Saved to:\n${zipFile.path}\n\n'
                'Move this file to the destination device and use '
                '"Import data" to restore it there.'),
            actions: [
              TextButton(
                onPressed: () {
                  Share.shareFiles([zipFile.path],
                      mimeTypes: ['application/zip']);
                },
                child: const Text('Share'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e, st) {
      log.error('export failed: $e\n$st');
      log.close();
      // Clean up staging on failure too. Without this, a partial
      // export leaks gigabytes of JSONL into shared storage and
      // each retry stacks another copy on top. Async to avoid the
      // multi-GB sync-delete UI freeze.
      if (stagingPathForCleanup != null) {
        try {
          final s = Directory(stagingPathForCleanup);
          if (s.existsSync()) await s.delete(recursive: true);
        } catch (_) {}
      }
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export failed'),
            content: Text('$e\n\nLog: ${log.logPath}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // IMPORT
  // -------------------------------------------------------------

  /// Restore an app state from an export bundle, replacing all
  /// current Isar/Hive/TTU data. Triggers an `exit(0)` on success
  /// so that the next launch initialises against fresh state.
  static Future<void> importData({
    required AppModel appModel,
    required BuildContext context,
  }) async {
    final log = _ExLog.create('import');
    Directory? extractDir;
    try {
      log.write('=== import start ===');

      final bundlePath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => FolderFilePicker(
            appModel: appModel,
            allowedExtensions: const ['.zip'],
            fileIcon: Icons.unarchive,
            title: 'Pick export bundle',
            initialDir: '/storage/emulated/0/tmp',
          ),
        ),
      );
      if (bundlePath == null) {
        log.write('user cancelled at picker');
        log.close();
        return;
      }
      log.write('picked: $bundlePath');

      final bundleFile = File(bundlePath);
      if (!bundleFile.existsSync()) {
        log.error('bundle does not exist: $bundlePath');
        log.close();
        return;
      }

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Import bundle'),
          content: Text(
              'Import from:\n${path.basename(bundlePath)}\n\n'
              'This will REPLACE all current dictionaries, books, '
              'reading progress, AnkiMappings, audio history, and '
              'preferences. The app will close after import.\n\n'
              'Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        log.write('user cancelled at confirm');
        log.close();
        return;
      }

      if (!context.mounted) return;
      final navigator = Navigator.of(context);
      // Seven major steps: extract, manifest, isar, hive,
      // dictResources, ttu, audio remap. The audio step usually
      // finishes instantly (path heuristic only — real remap, when
      // needed, is interactive and runs after the dialog closes).
      final tracker = LongOpProgressTracker(
        operation: 'Importing',
        totalSteps: 7,
      );
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LongOpProgressDialog(
          titleNotifier: tracker.titleNotifier,
          bodyNotifier: tracker.bodyNotifier,
        ),
      );

      // Extract on shared storage so we do not contend with the app
      // data partition during the actual restore phase.
      tracker.step('Extracting bundle...');
      final ts = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      extractDir = Directory(
          '/storage/emulated/0/tmp/shiroikumanojisho_import_staging_$ts');
      if (extractDir.existsSync()) extractDir.deleteSync(recursive: true);
      extractDir.createSync(recursive: true);
      log.write('extracting to ${extractDir.path}');

      log.write('extracting ${bundleFile.path}');
      await ZipFile.extractToDirectory(
        zipFile: bundleFile,
        destinationDir: extractDir,
        onExtracting: (zipEntry, progressPercent) {
          tracker.detail(
              'Extracting bundle... (${progressPercent.toStringAsFixed(0)}%)');
          return ZipFileOperation.includeItem;
        },
      );
      log.write('extract complete');

      // ---- manifest sanity check ----
      tracker.step('Reading manifest...');
      final manifestFile = File(path.join(extractDir.path, 'manifest.json'));
      if (!manifestFile.existsSync()) {
        throw 'Bundle is missing manifest.json — not a valid export';
      }
      final manifest = jsonDecode(await manifestFile.readAsString())
          as Map<String, dynamic>;
      final bundleSchema = manifest['bundle_schema'] as int? ?? 0;
      if (bundleSchema != _bundleSchemaVersion) {
        throw 'Bundle schema version $bundleSchema is not supported '
            '(expected $_bundleSchemaVersion). Export from a matching '
            'app version.';
      }
      log.write('manifest ok, ts=${manifest["created_at"]}');

      // ---- isar restore ----
      tracker.step('Restoring database...');
      final isarDir = Directory(path.join(extractDir.path, 'isar'));
      if (isarDir.existsSync()) {
        final rowCounts =
            (manifest['isar_row_counts'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as int));
        await _importIsar(appModel, isarDir, log, tracker,
            rowCounts: rowCounts);
      } else {
        log.write('no isar/ in bundle, skipping');
      }

      // ---- hive restore ----
      tracker.step('Restoring preferences...');
      final hiveDir = Directory(path.join(extractDir.path, 'hive'));
      if (hiveDir.existsSync()) {
        await _importHive(appModel, hiveDir, log);
      } else {
        log.write('no hive/ in bundle, skipping');
      }

      // ---- dictionaryResources passthrough ----
      tracker.step('Restoring dictionary resources...');
      final dictResSrc =
          Directory(path.join(extractDir.path, 'dictionaryResources'));
      if (dictResSrc.existsSync()) {
        final dictResDst = Directory(
            path.join(appModel.appDirectory.path, 'dictionaryResources'));
        if (dictResDst.existsSync()) {
          // Async — `dictionaryResources/` can hold tens of
          // thousands of files (per-dictionary audio, images, etc.)
          // and the sync delete blocks the UI thread for tens of
          // seconds.
          tracker.detail('Clearing existing dictionary resources...');
          await _deleteDirectoryWithProgress(
            dictResDst,
            onPhase: (phase) => tracker.detail(
                'Clearing existing dictionary resources: $phase'),
            onProgress: (deleted, total) {
              final fmt = NumberFormat.decimalPattern();
              tracker.detail(
                  'Clearing existing dictionary resources: '
                  '(${fmt.format(deleted)}/${fmt.format(total)})');
            },
          );
        }
        dictResDst.createSync(recursive: true);
        await _copyDirectoryWithProgress(
          dictResSrc,
          dictResDst,
          onProgress: (copied, total) {
            final fmt = NumberFormat.decimalPattern();
            tracker.detail(
                'Restoring dictionary resources... '
                '(${fmt.format(copied)}/${fmt.format(total)})');
          },
        );
        log.write('dictionaryResources copied');
      }

      // ---- per-language TTU IndexedDB ----
      tracker.step('Restoring books...');
      final ttuLanguages = (manifest['ttu_languages'] as List?)
              ?.cast<String>() ??
          const <String>[];
      for (var i = 0; i < ttuLanguages.length; i++) {
        final code = ttuLanguages[i];
        tracker.detail(
            'Restoring books: $code (${i + 1}/${ttuLanguages.length})...');
        try {
          // Look up by languageCode, NOT by map key. The map is
          // keyed by locale.toLanguageTag() (e.g. "ja-JP") but
          // ttu_languages stores just the language code ("ja").
          // The previous version did `appModel.languages[code]`,
          // which silently returned null for every language and
          // skipped the entire TTU import — visible in the log
          // as "ttu: skipping language X (not registered locally)"
          // for every language.
          Language? lang;
          for (final l in appModel.languages.values) {
            if (l.languageCode == code) {
              lang = l;
              break;
            }
          }
          if (lang == null) {
            log.write(
                'ttu: skipping language $code (not in app supported list)');
            continue;
          }
          final ttuDir =
              Directory(path.join(extractDir.path, 'ttu', code));
          if (!ttuDir.existsSync()) {
            log.write('ttu: no dir for $code, skipping');
            continue;
          }
          await _importTtuForLanguage(lang, ttuDir, log, tracker);
        } catch (e, st) {
          log.error('ttu import failed for $code: $e\n$st');
        }
      }

      // ---- audio path remap ----
      tracker.step('Checking audio paths...');
      final unresolved = await _collectUnresolvedAudio(appModel, log);
      if (unresolved.isNotEmpty) {
        if (navigator.canPop()) navigator.pop();
        if (context.mounted) {
          await _runAudioRemapFlow(
            appModel: appModel,
            context: context,
            unresolved: unresolved,
            log: log,
          );
        }
      } else {
        if (navigator.canPop()) navigator.pop();
      }

      // ---- cleanup + exit ----
      // Pop whatever dialog is on top of the navigator (the audio
      // remap flow may have left one open after Skip), then show a
      // dedicated cleanup dialog so the user gets feedback during
      // the multi-GB extract dir removal. On Boox flash a 3 GB
      // recursive delete can take 30+ seconds, and doing it
      // synchronously on the UI thread is what produced the
      // "Skip freezes the device" symptom in `+11`.
      // Pop whatever dialog is on top of the navigator (the audio
      // remap flow may have left one open after Skip), then show
      // the tracker dialog again with a fresh "Cleaning up" step.
      // The tracker has been re-used through this whole import
      // and supports adding ad-hoc detail strings, so we can show
      // per-file delete progress without standing up a new
      // dialog scaffold here.
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => LongOpProgressDialog(
            titleNotifier: tracker.titleNotifier,
            bodyNotifier: tracker.bodyNotifier,
          ),
        );
      }
      tracker.detail('Cleaning up...');

      try {
        await _deleteDirectoryWithProgress(
          extractDir,
          onPhase: (phase) => tracker.detail('Cleaning up: $phase'),
          onProgress: (deleted, total) {
            final fmt = NumberFormat.decimalPattern();
            tracker.detail(
                'Cleaning up: '
                '(${fmt.format(deleted)}/${fmt.format(total)})');
          },
        );
      } catch (e) {
        log.error('failed to remove extract dir: $e');
      }

      // Force Hive's pending writes to disk before we exit. Each
      // box was already flushed in `_importHive` after its writes,
      // but `Hive.close()` is the belt-and-suspenders move and
      // also closes any boxes that the live `AppModel` may have
      // touched separately during the session.
      try {
        await Hive.close();
        log.write('hive closed');
      } catch (e) {
        log.error('hive close failed: $e');
      }

      // Force Isar to flush. Closing the instance commits any
      // outstanding write transactions and fsyncs the data file.
      // Without this the dictionary-entries import we just did
      // could be partially in the WAL when `exit(0)` fires, and
      // on next launch Isar would replay the WAL — but on Boox
      // flash the WAL replay can be slow enough that the user
      // sees a long blank-screen start.
      try {
        await appModel.database.close();
        log.write('isar closed');
      } catch (e) {
        log.error('isar close failed: $e');
      }

      log.write('=== import complete, exiting ===');
      log.close();

      Fluttertoast.showToast(msg: 'Import complete. Closing app...');
      // Bumped from 2s to 4s — gives the OS extra time to drain
      // its dirty page cache before we kill the process. The
      // WebView IDB writes done during the TTU import phase are
      // particularly sensitive: there is no Dart-side flush API
      // for them, so we rely on the WebView dispose having
      // committed the IDB transactions and the OS having time
      // to fsync the WebView's storage files.
      await Future.delayed(const Duration(seconds: 4));
      exit(0);
    } catch (e, st) {
      log.error('import failed: $e\n$st');
      log.close();
      // Best-effort async cleanup on failure too, but do not show
      // a dialog here — the failure dialog below is what the user
      // needs to see.
      try {
        await extractDir?.delete(recursive: true);
      } catch (_) {}
      if (context.mounted) {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          try {
            nav.pop();
          } catch (_) {}
        }
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Import failed'),
            content: Text('$e\n\nLog: ${log.logPath}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // ISAR EXPORT/IMPORT
  // -------------------------------------------------------------
  //
  // Per-collection JSONL — each line is a complete JSON object so
  // both writer and reader can stream without buffering the whole
  // collection in memory. DictionaryEntry has a `compressedDefinitions`
  // byte array; we base64-encode it inline rather than dumping it
  // as a JSON int array (which would balloon to ~3-4x the size).
  //
  // The `id` field is preserved across export/import. For most
  // collections the id is auto-incremented and can be retained
  // verbatim because we wipe-and-replace; for DictionaryTag the id
  // is a stable hash of (dictionaryId, name) so retaining works
  // there too.

  // Batch size for both Isar reads (export) and writes (import).
  // Bumped from 500 → 5000 after observing ~2k rows/sec import
  // throughput on Boox flash, dominated by per-`writeTxn` fsync
  // overhead (~50–200 ms regardless of batch size). Larger batches
  // amortise the fsync over more rows; pairing this with the
  // decode/write pipeline in `_loadJsonl` gives a combined ~4–6×
  // speedup. Memory cost is bounded — even with two batches in
  // flight the working set is ~10 MB worth of DictionaryEntry
  // objects, fine on any device that can run the app at all.
  static const int _isarBatchSize = 5000;

  static Future<Map<String, int>> _exportIsar(
    AppModel appModel,
    Directory outDir,
    _ExLog log,
    LongOpProgressTracker tracker,
  ) async {
    final db = appModel.database;
    // We pre-count every collection up front so we can stash the
    // numbers into manifest.json for the importer to use as a
    // denominator. `Isar.count()` uses the primary index so even
    // for the 9.7M-row entries collection it returns in a few ms.
    final counts = <String, int>{
      'dictionaries': await db.dictionarys.count(),
      'dictionary_entries': await db.dictionaryEntrys.count(),
      'dictionary_tags': await db.dictionaryTags.count(),
      'dictionary_frequencies': await db.dictionaryFrequencys.count(),
      'dictionary_pitches': await db.dictionaryPitchs.count(),
      'anki_mappings': await db.ankiMappings.count(),
      'media_items': await db.mediaItems.count(),
      'search_history_items': await db.searchHistoryItems.count(),
      'browser_bookmarks': await db.browserBookmarks.count(),
      'mokuro_catalogs': await db.mokuroCatalogs.count(),
    };

    tracker.detail('Exporting dictionaries...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'dictionaries.jsonl')),
      db.dictionarys,
      _dictionaryToJson,
      log,
    );

    tracker.detail('Exporting dictionary entries...');
    await _dumpJsonlPaged<DictionaryEntry>(
      File(path.join(outDir.path, 'dictionary_entries.jsonl')),
      (afterId, lim) => db.dictionaryEntrys
          .where()
          .idGreaterThan(afterId)
          .limit(lim)
          .findAll(),
      (e) => e.id!,
      _entryToJson,
      log,
      tracker: tracker,
      progressLabel: 'Exporting dictionary entries...',
      progressTotal: counts['dictionary_entries'],
    );

    tracker.detail('Exporting dictionary tags...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'dictionary_tags.jsonl')),
      db.dictionaryTags,
      _tagToJson,
      log,
    );

    tracker.detail('Exporting frequencies...');
    await _dumpJsonlPaged<DictionaryFrequency>(
      File(path.join(outDir.path, 'dictionary_frequencies.jsonl')),
      (afterId, lim) => db.dictionaryFrequencys
          .where()
          .idGreaterThan(afterId)
          .limit(lim)
          .findAll(),
      (f) => f.id!,
      _frequencyToJson,
      log,
      tracker: tracker,
      progressLabel: 'Exporting frequencies...',
      progressTotal: counts['dictionary_frequencies'],
    );

    tracker.detail('Exporting pitches...');
    await _dumpJsonlPaged<DictionaryPitch>(
      File(path.join(outDir.path, 'dictionary_pitches.jsonl')),
      (afterId, lim) => db.dictionaryPitchs
          .where()
          .idGreaterThan(afterId)
          .limit(lim)
          .findAll(),
      (p) => p.id!,
      _pitchToJson,
      log,
      tracker: tracker,
      progressLabel: 'Exporting pitches...',
      progressTotal: counts['dictionary_pitches'],
    );

    tracker.detail('Exporting AnkiMappings...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'anki_mappings.jsonl')),
      db.ankiMappings,
      (m) => m.toJson()..['_id'] = m.id,
      log,
    );

    tracker.detail('Exporting media items...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'media_items.jsonl')),
      db.mediaItems,
      (i) => i.toJson()..['_id'] = i.id,
      log,
    );

    tracker.detail('Exporting search history...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'search_history_items.jsonl')),
      db.searchHistoryItems,
      (s) => {
        '_id': s.id,
        'historyKey': s.historyKey,
        'searchTerm': s.searchTerm,
      },
      log,
    );

    tracker.detail('Exporting browser bookmarks...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'browser_bookmarks.jsonl')),
      db.browserBookmarks,
      _browserBookmarkToJson,
      log,
    );

    tracker.detail('Exporting mokuro catalogs...');
    await _dumpJsonl(
      File(path.join(outDir.path, 'mokuro_catalogs.jsonl')),
      db.mokuroCatalogs,
      _mokuroCatalogToJson,
      log,
    );

    return counts;
  }

  static Future<void> _importIsar(
    AppModel appModel,
    Directory inDir,
    _ExLog log,
    LongOpProgressTracker tracker, {
    Map<String, int>? rowCounts,
  }) async {
    final db = appModel.database;

    Future<void> doOne<T>(
      String filename,
      String label,
      String countKey,
      IsarCollection<T> col,
      T Function(Map<String, dynamic>) fromJson,
    ) async {
      tracker.detail('Importing $label...');
      final f = File(path.join(inDir.path, filename));
      if (!f.existsSync()) {
        log.write('isar: skipping $filename (not present)');
        return;
      }
      // Only clear if there is something to clear. On a fresh
      // install (the common cross-device case) the collection is
      // already empty and `col.clear()` would still issue a write
      // transaction with its own fsync — wasted work. For the
      // dictionary entries collection on Boox flash this saves
      // measurable seconds, but the bigger win is on the
      // *populated* re-import path: a real `clear()` of 9.7M rows
      // is itself a major chunk of the runtime, so we keep the
      // existing semantics (wipe-and-replace) but only pay for it
      // when it is needed.
      final existing = await col.count();
      if (existing > 0) {
        log.write('isar: clearing $existing existing rows in $filename');
        await db.writeTxn(() async => col.clear());
      }
      await _loadJsonl<T>(f, col, fromJson, db, log,
          tracker: tracker,
          progressLabel: 'Importing $label...',
          progressTotal: rowCounts?[countKey]);
    }

    await doOne('dictionaries.jsonl', 'dictionaries', 'dictionaries',
        db.dictionarys, _dictionaryFromJson);
    await doOne('dictionary_entries.jsonl', 'dictionary entries',
        'dictionary_entries', db.dictionaryEntrys, _entryFromJson);
    await doOne('dictionary_tags.jsonl', 'dictionary tags', 'dictionary_tags',
        db.dictionaryTags, _tagFromJson);
    await doOne('dictionary_frequencies.jsonl', 'frequencies',
        'dictionary_frequencies', db.dictionaryFrequencys, _frequencyFromJson);
    await doOne('dictionary_pitches.jsonl', 'pitches', 'dictionary_pitches',
        db.dictionaryPitchs, _pitchFromJson);
    await doOne('anki_mappings.jsonl', 'AnkiMappings', 'anki_mappings',
        db.ankiMappings, (j) {
      final m = AnkiMapping.fromJson(j);
      m.id = j['_id'] as int?;
      return m;
    });
    await doOne('media_items.jsonl', 'media items', 'media_items',
        db.mediaItems, (j) {
      final m = MediaItem.fromJson(j);
      m.id = j['_id'] as int?;
      return m;
    });
    await doOne('search_history_items.jsonl', 'search history',
        'search_history_items', db.searchHistoryItems, (j) {
      final s = SearchHistoryItem(
        historyKey: j['historyKey'] as String,
        searchTerm: j['searchTerm'] as String,
      );
      s.id = j['_id'] as int?;
      return s;
    });
    await doOne('browser_bookmarks.jsonl', 'browser bookmarks',
        'browser_bookmarks', db.browserBookmarks, _browserBookmarkFromJson);
    await doOne('mokuro_catalogs.jsonl', 'mokuro catalogs', 'mokuro_catalogs',
        db.mokuroCatalogs, _mokuroCatalogFromJson);
  }

  /// Dump every row of [col] to [outFile] as JSONL. Loads the
  /// collection in one `findAll()` — only safe for collections we
  /// know are bounded (dictionary headers, tags, mappings, media
  /// items, search history, bookmarks, mokuro catalogs). For the
  /// large ones (entries / frequencies / pitches) use
  /// [_dumpJsonlPaged] instead.
  static Future<void> _dumpJsonl<T>(
    File outFile,
    IsarCollection<T> col,
    Map<String, dynamic> Function(T) toJson,
    _ExLog log,
  ) async {
    final sink = outFile.openWrite();
    int total = 0;
    try {
      final all = await col.where().findAll();
      for (final item in all) {
        sink.writeln(jsonEncode(toJson(item)));
        total++;
      }
      log.write('  ${path.basename(outFile.path)}: $total rows');
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// Dump every row of a large Isar collection to [outFile] as
  /// JSONL using id-cursor pagination. Designed for collections
  /// where the row count can be hundreds of thousands and a
  /// single `findAll()` would either pin too much memory or block
  /// the isolate for too long.
  ///
  /// We can not implement this with a generic `IsarCollection<T>`
  /// because the typed where-clause builders (`idGreaterThan`)
  /// are generated per collection. Instead the caller passes:
  ///
  ///   - [pageFetcher]: a closure that given `(afterId, limit)`
  ///     returns the next page of rows whose id is strictly
  ///     greater than `afterId`, ordered ascending and capped at
  ///     `limit`. Implemented at call sites as
  ///     `db.foos.where().idGreaterThan(afterId).limit(limit).findAll()`.
  ///   - [idOf]: extracts the id from a row to advance the cursor.
  ///
  /// This is O(N) total across the whole collection, vs. the
  /// O(N²/B) of the offset-based pagination we used to do —
  /// for a 300k-row dictionary that is the difference between
  /// "finishes in a couple of minutes" and "still running half
  /// an hour later".
  static Future<void> _dumpJsonlPaged<T>(
    File outFile,
    Future<List<T>> Function(int afterId, int limit) pageFetcher,
    int Function(T) idOf,
    Map<String, dynamic> Function(T) toJson,
    _ExLog log, {
    LongOpProgressTracker? tracker,
    String? progressLabel,
    int? progressTotal,
  }) async {
    final sink = outFile.openWrite();
    // We accumulate JSONL lines in an in-memory buffer and only
    // commit to the sink when the buffer reaches the threshold.
    // This keeps memory bounded (the buffer never exceeds a few
    // MB) while amortising the cost of `sink.flush()`.
    //
    // Flushing after every Isar batch (500 rows) was ~10x slower
    // on Android flash than not flushing at all — each flush has
    // tens to hundreds of ms of latency, and at 19k flushes for
    // a 9.7M-row dictionary that adds up to half an hour just
    // sitting in flush. Flushing every ~4 MB instead gives the
    // same OOM-safety (writes do not queue unbounded in the
    // sink) but cuts the flush count by ~30x.
    //
    // Threshold is in Dart string code units (UTF-16). For
    // Japanese-heavy entries the on-disk UTF-8 size is ~3x, so
    // 4 MB code units = ~12 MB bytes per flush in the worst
    // case. Both are fine on an 8 GB device.
    final buf = StringBuffer();
    int bufChars = 0;
    const flushThresholdChars = 4 * 1024 * 1024;

    Future<void> drainBuf() async {
      if (buf.isEmpty) return;
      sink.write(buf.toString());
      buf.clear();
      bufChars = 0;
      await sink.flush();
    }

    // `Isar.minId` is the smallest valid id; using `idGreaterThan`
    // with `include: false` (its default) skips that id but ids
    // are auto-assigned starting from 1 so we never have a row
    // with id == minId in practice.
    int lastId = Isar.minId;
    int written = 0;
    final fmt = NumberFormat.decimalPattern();
    try {
      while (true) {
        final chunk = await pageFetcher(lastId, _isarBatchSize);
        if (chunk.isEmpty) break;
        for (final item in chunk) {
          final line = jsonEncode(toJson(item));
          buf.writeln(line);
          // +1 accounts for the newline `writeln` appends.
          bufChars += line.length + 1;
          written++;
          if (bufChars >= flushThresholdChars) {
            await drainBuf();
          }
        }
        lastId = idOf(chunk.last);
        if (tracker != null && progressLabel != null) {
          // Format the running counter (and total, when known) with
          // locale-aware thousands separators. The pattern picks up
          // the device locale via the intl default; for users in
          // grouping locales this gives `45,000/300,000`, for users
          // whose locale uses other separators it adapts.
          final cur = fmt.format(written);
          tracker.detail(progressTotal != null
              ? '$progressLabel ($cur/${fmt.format(progressTotal)})'
              : '$progressLabel ($cur)');
        }
        if (chunk.length < _isarBatchSize) break;
      }
      await drainBuf();
      log.write('  ${path.basename(outFile.path)}: $written rows');
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  /// Stream-read a JSONL file and `putAll` rows into the given Isar
  /// collection in batches. Rows that fail to parse are logged and
  /// Stream-read a JSONL file and `putAll` rows into the given Isar
  /// collection in batches. Rows that fail to parse are logged and
  /// skipped — partial import beats no import for big bundles.
  ///
  /// Performance shape:
  ///   * Decode (CPU) and write (disk) are pipelined — while one
  ///     batch is being written via `db.writeTxn`, the next batch is
  ///     accumulated from the line stream. We hold at most one
  ///     in-flight `writeTxn` to bound memory, so the working set is
  ///     two batches: one being decoded, one being committed.
  ///   * Batch size is `_isarBatchSize` (5000). At ~50–200 ms of
  ///     fsync cost per `writeTxn`, batching 5000 rows amortises
  ///     that to 0.01–0.04 ms per row instead of 0.1–0.4 ms.
  ///
  /// If [progressTotal] is supplied (read from the manifest's
  /// `isar_row_counts`), the dialog body shows
  /// `(written/total)` with locale-aware thousands separators —
  /// the user gets a real ETA instead of just a running count.
  static Future<void> _loadJsonl<T>(
    File jsonlFile,
    IsarCollection<T> col,
    T Function(Map<String, dynamic>) fromJson,
    Isar db,
    _ExLog log, {
    LongOpProgressTracker? tracker,
    String? progressLabel,
    int? progressTotal,
  }) async {
    var batch = <T>[];
    int total = 0;
    int errors = 0;
    final fmt = NumberFormat.decimalPattern();

    void publishProgress() {
      if (tracker == null || progressLabel == null) return;
      final cur = fmt.format(total);
      tracker.detail(progressTotal != null
          ? '$progressLabel ($cur/${fmt.format(progressTotal)})'
          : '$progressLabel ($cur)');
    }

    // Show `(0/total)` immediately so the user sees the denominator
    // before the first batch lands — which can take a few seconds
    // for the dictionary entries collection while Isar warms up.
    publishProgress();

    Future<void> writeBatch(List<T> toWrite) async {
      // Use the sync API: `writeTxnSync` + `putAllSync` runs the
      // transaction on the calling isolate without marshalling each
      // call through Isar's port to the native isolate. For batched
      // writes this is typically 2–3x faster than the async pair
      // because we avoid the per-call serialisation overhead. We
      // still wrap in a `Future.microtask` so the UI thread gets a
      // chance to pump the progress notifier between batches —
      // without that, on a fast device the import could starve the
      // dialog frame loop and look frozen even though work is
      // proceeding.
      //
      // Trade-off: a `writeTxnSync` blocks the calling isolate
      // until commit, so during each ~100ms transaction the UI
      // thread cannot draw frames. With 5000-row batches that is
      // tolerable jank; if it ever becomes a problem we can
      // shrink the batch or move imports to a worker isolate.
      await Future<void>(() {
        db.writeTxnSync(() => col.putAllSync(toWrite));
      });
      total += toWrite.length;
      publishProgress();
    }

    // Pipeline: keep one writeTxn in flight at a time. While it
    // runs, the next batch is being decoded from the stream. We
    // only `await` the previous flush when we are ready to start
    // the next one, so the two phases overlap.
    Future<void> pendingWrite = Future.value();

    final stream = jsonlFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final raw in stream) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      try {
        final j = jsonDecode(line) as Map<String, dynamic>;
        batch.add(fromJson(j));
        if (batch.length >= _isarBatchSize) {
          // Wait for previous flush to finish before queueing the
          // next, so we never have more than one writeTxn pending
          // and decode memory stays bounded to one batch.
          await pendingWrite;
          final toWrite = batch;
          batch = <T>[];
          pendingWrite = writeBatch(toWrite);
        }
      } catch (e) {
        errors++;
        if (errors <= 5) log.error('  parse error: $e // line=$line');
      }
    }
    await pendingWrite;
    if (batch.isNotEmpty) {
      await writeBatch(batch);
    }
    log.write('  ${path.basename(jsonlFile.path)}: '
        '$total imported, $errors errors');
  }

  // ---- Per-collection JSON shape helpers. ----
  //
  // These mirror each Isar entity's field set verbatim. We keep
  // them hand-written rather than leaning on Isar's exportJsonRaw
  // because (a) byte fields like `compressedDefinitions` get
  // serialised as JSON int arrays by Isar — ~3-4x the size of
  // base64 inline strings — and (b) hand-written serialisers let
  // us evolve the on-disk format independently of Isar schema
  // changes.

  static Map<String, dynamic> _dictionaryToJson(Dictionary d) => {
        'id': d.id,
        'name': d.name,
        'formatKey': d.formatKey,
        'order': d.order,
        'primaryLanguage': d.primaryLanguage,
        'bloomBits': base64Encode(d.bloomBits),
        'hiddenLanguages': d.hiddenLanguages,
        'collapsedLanguages': d.collapsedLanguages,
      };

  static Dictionary _dictionaryFromJson(Map<String, dynamic> j) {
    final d = Dictionary(
      id: j['id'] as int,
      name: j['name'] as String,
      formatKey: j['formatKey'] as String,
      order: j['order'] as int,
      primaryLanguage: j['primaryLanguage'] as String? ?? '',
      hiddenLanguages:
          (j['hiddenLanguages'] as List?)?.cast<String>() ?? const [],
      collapsedLanguages:
          (j['collapsedLanguages'] as List?)?.cast<String>() ?? const [],
    );
    final bb = j['bloomBits'];
    if (bb is String && bb.isNotEmpty) {
      d.bloomBits = base64Decode(bb);
    }
    return d;
  }

  static Map<String, dynamic> _entryToJson(DictionaryEntry e) => {
        'id': e.id,
        'term': e.term,
        'reading': e.reading,
        'dictionaryId': e.dictionaryId,
        'popularity': e.popularity,
        'compressedDefinitions': base64Encode(e.compressedDefinitions),
        'entryTagsRaw': e.entryTagsRaw,
        'headingTagsRaw': e.headingTagsRaw,
        'imagePaths': e.imagePaths,
        'audioPaths': e.audioPaths,
      };

  static DictionaryEntry _entryFromJson(Map<String, dynamic> j) {
    final e = DictionaryEntry(
      term: j['term'] as String,
      reading: j['reading'] as String,
      dictionaryId: j['dictionaryId'] as int,
      popularity: (j['popularity'] as num).toDouble(),
      compressedDefinitions:
          base64Decode(j['compressedDefinitions'] as String),
      entryTagsRaw: j['entryTagsRaw'] as String? ?? '',
      headingTagsRaw: j['headingTagsRaw'] as String? ?? '',
      imagePaths: (j['imagePaths'] as List?)?.cast<String>(),
      audioPaths: (j['audioPaths'] as List?)?.cast<String>(),
    );
    final id = j['id'];
    if (id is int) e.id = id;
    return e;
  }

  static Map<String, dynamic> _tagToJson(DictionaryTag t) => {
        'dictionaryId': t.dictionaryId,
        'name': t.name,
        'category': t.category,
        'sortingOrder': t.sortingOrder,
        'notes': t.notes,
        'popularity': t.popularity,
      };

  static DictionaryTag _tagFromJson(Map<String, dynamic> j) =>
      DictionaryTag(
        dictionaryId: j['dictionaryId'] as int,
        name: j['name'] as String,
        category: j['category'] as String,
        sortingOrder: j['sortingOrder'] as int,
        notes: j['notes'] as String? ?? '',
        popularity: (j['popularity'] as num).toDouble(),
      );

  static Map<String, dynamic> _frequencyToJson(DictionaryFrequency f) => {
        'id': f.id,
        'term': f.term,
        'reading': f.reading,
        'dictionaryId': f.dictionaryId,
        'value': f.value,
        'displayValue': f.displayValue,
      };

  static DictionaryFrequency _frequencyFromJson(Map<String, dynamic> j) {
    final f = DictionaryFrequency(
      term: j['term'] as String,
      reading: j['reading'] as String,
      dictionaryId: j['dictionaryId'] as int,
      value: (j['value'] as num).toDouble(),
      displayValue: j['displayValue'] as String,
    );
    final id = j['id'];
    if (id is int) f.id = id;
    return f;
  }

  static Map<String, dynamic> _pitchToJson(DictionaryPitch p) => {
        'id': p.id,
        'term': p.term,
        'reading': p.reading,
        'dictionaryId': p.dictionaryId,
        'downstep': p.downstep,
      };

  static DictionaryPitch _pitchFromJson(Map<String, dynamic> j) {
    final p = DictionaryPitch(
      term: j['term'] as String,
      reading: j['reading'] as String,
      dictionaryId: j['dictionaryId'] as int,
      downstep: j['downstep'] as int,
    );
    final id = j['id'];
    if (id is int) p.id = id;
    return p;
  }

  static Map<String, dynamic> _browserBookmarkToJson(BrowserBookmark b) => {
        'id': b.id,
        'name': b.name,
        'url': b.url,
      };

  static BrowserBookmark _browserBookmarkFromJson(Map<String, dynamic> j) {
    final b = BrowserBookmark(
      name: j['name'] as String,
      url: j['url'] as String,
    );
    final id = j['id'];
    if (id is int) b.id = id;
    return b;
  }

  static Map<String, dynamic> _mokuroCatalogToJson(MokuroCatalog m) => {
        'id': m.id,
        'name': m.name,
        'url': m.url,
        'order': m.order,
      };

  static MokuroCatalog _mokuroCatalogFromJson(Map<String, dynamic> j) {
    final m = MokuroCatalog(
      name: j['name'] as String,
      url: j['url'] as String,
      order: j['order'] as int,
    );
    final id = j['id'];
    if (id is int) m.id = id;
    return m;
  }

  // -------------------------------------------------------------
  // HIVE EXPORT/IMPORT
  // -------------------------------------------------------------
  //
  // We dump only the named boxes the app uses for persistent
  // user-facing state. `appModel` (preferences like target
  // language, theme, custom storage path) and `readerAudio` (per-
  // book reader settings, secondary book associations, font sizes)
  // are the headline ones. Anonymous per-source preference boxes
  // (one per MediaSource via `Hive.openBox(uniqueKey)`) are also
  // included so per-source settings survive the migration.
  //
  // Values must be JSON-serialisable primitives (string / int /
  // double / bool / list / map). The boxes the app uses today
  // satisfy this — values are either primitives or already-JSON-
  // encoded strings — so we do not need a custom (de)serialiser.

  static const List<String> _builtinHiveBoxes = [
    'appModel',
    'readerAudio',
  ];

  static Future<void> _exportHive(
    AppModel appModel,
    Directory outDir,
    _ExLog log,
  ) async {
    // Built-in boxes by name.
    final boxNames = <String>{..._builtinHiveBoxes};
    // Per-MediaSource preference boxes — one per source's uniqueKey.
    for (final mediaType in appModel.mediaTypes.values) {
      final sources = appModel.mediaSources[mediaType];
      if (sources == null) continue;
      for (final source in sources.values) {
        boxNames.add(source.uniqueKey);
      }
    }

    final dump = <String, Map<String, dynamic>>{};
    for (final name in boxNames) {
      try {
        final box = await Hive.openBox(name);

        // Capture default-but-effective values that aren't yet
        // persisted. Some preference getters in `AppModel` use
        // `_preferences.get(..., defaultValue: <dynamic>)` where the
        // defaultValue depends on platform state (e.g.
        // `is_dark_mode` defaults to system brightness). If the
        // user has never explicitly toggled, the key isn't in the
        // box, the export captures nothing for it, and on the
        // import side a Flutter cold-start brightness quirk can
        // produce the wrong value — visible to the user as "the
        // theme reverted after import." Forcing the effective
        // value into the box before serialisation makes the
        // bundle self-sufficient. We do this only for keys with
        // dynamic defaults; static-default keys round-trip fine.
        if (name == 'appModel') {
          if (!box.containsKey('is_dark_mode')) {
            await box.put('is_dark_mode', appModel.isDarkMode);
            log.write(
                '  hive: appModel forced is_dark_mode=${appModel.isDarkMode}');
          }
        }

        final entries = <String, dynamic>{};
        for (final key in box.keys) {
          entries[key.toString()] = box.get(key);
        }
        dump[name] = entries;
        log.write('  hive: $name -> ${entries.length} keys');
      } catch (e) {
        log.error('  hive: $name failed: $e');
      }
    }
    await File(path.join(outDir.path, 'boxes.json'))
        .writeAsString(jsonEncode(dump));
  }

  static Future<void> _importHive(
    AppModel appModel,
    Directory inDir,
    _ExLog log,
  ) async {
    final boxesFile = File(path.join(inDir.path, 'boxes.json'));
    if (!boxesFile.existsSync()) {
      log.write('hive: boxes.json missing, skipping');
      return;
    }
    final dump = jsonDecode(await boxesFile.readAsString())
        as Map<String, dynamic>;
    for (final entry in dump.entries) {
      final name = entry.key;
      final entries = entry.value as Map<String, dynamic>;
      try {
        final box = await Hive.openBox(name);
        await box.clear();
        for (final kv in entries.entries) {
          await box.put(kv.key, kv.value);
        }
        // Force the box to flush its in-memory writes to disk.
        // Hive boxes batch writes by default; without an explicit
        // flush the values may sit in the box's pending-writes
        // buffer when `exit(0)` fires after import, and the next
        // launch reads stale on-disk data — manifesting as "the
        // theme I imported did not take effect," "preferences
        // reverted," etc.
        await box.flush();
        log.write('  hive: $name <- ${entries.length} keys (flushed)');
      } catch (e) {
        log.error('  hive: $name failed: $e');
      }
    }
  }

  // -------------------------------------------------------------
  // TTU INDEXEDDB EXPORT/IMPORT
  // -------------------------------------------------------------
  //
  // Each language has its own TTU localhost server (port set by
  // `ReaderTtuSource.getPortForLanguage`) and its own IndexedDB
  // namespace inside the WebView. We open a `HeadlessInAppWebView`
  // pointing at that server, wait for the page to load, then run
  // JS to read or write the IDB stores.
  //
  // Writing books one at a time keeps any single JS payload
  // bounded. A library of 50 books at 2-5 MB each parses to
  // hundreds of MB total; sending them all at once would either
  // crash `evaluateJavascript` outright (its argument-marshalling
  // path stages the whole string) or eat enough native memory to
  // get the process killed by Android. One-at-a-time is slow but
  // reliable.

  /// Run the export against TTU for [language]. Returns true if
  /// any books were found (and the dir was populated); false if
  /// the IDB is empty or initialisation failed in a recoverable
  /// way.
  static Future<bool> _exportTtuForLanguage(
    Language language,
    Directory outDir,
    _ExLog log,
  ) async {
    final port = ReaderTtuSource.instance.getPortForLanguage(language);
    log.write('ttu export: ${language.languageCode} on port $port');

    // Make sure the local server is running for this language.
    await ReaderTtuSource.instance.serveLocalAssets(language);

    final completer = Completer<Map<String, dynamic>?>();
    HeadlessInAppWebView? webView;
    Timer? timeout;
    timeout = Timer(const Duration(minutes: 5), () {
      if (!completer.isCompleted) {
        completer.complete(null);
        log.error('ttu export: timeout for ${language.languageCode}');
      }
    });

    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:$port/'),
      ),
      onLoadStop: (controller, url) async {
        try {
          await controller.evaluateJavascript(
              source: ReaderTtuSource.getHistoryJs);
        } catch (e) {
          if (!completer.isCompleted) completer.complete(null);
          log.error('ttu export: getHistoryJs failed: $e');
        }
      },
      onConsoleMessage: (controller, message) async {
        try {
          final m = jsonDecode(message.message) as Map<String, dynamic>;
          final t = m['messageType'];
          if (t == 'history') {
            if (!completer.isCompleted) completer.complete(m);
          } else if (t == 'empty') {
            if (!completer.isCompleted) completer.complete(null);
          }
        } catch (_) {
          // Non-JSON console messages from TTU; ignore.
        }
      },
    );

    await webView.run();
    final result = await completer.future;
    timeout.cancel();
    try {
      await webView.dispose();
    } catch (_) {}

    if (result == null) {
      log.write('ttu export: no data for ${language.languageCode}');
      return false;
    }

    // The JS encodes each store as a JSON-string field on the
    // outer map (already double-encoded). We pass the strings
    // through verbatim — the import path will jsonDecode them.
    final dataStr = result['data'] as String? ?? '[]';
    final lastItemStr = result['lastItem'] as String? ?? '[]';
    final bookmarkStr = result['bookmark'] as String? ?? '[]';

    // Re-parse `data` to count books and write JSONL (one book per
    // line) so a future stream-based import path can iterate
    // without buffering. lastItem and bookmark are small enough
    // that single-file JSON is fine.
    final dataList = (jsonDecode(dataStr) as List).cast<dynamic>();
    final dataSink =
        File(path.join(outDir.path, 'data.jsonl')).openWrite();
    try {
      for (final book in dataList) {
        dataSink.writeln(jsonEncode(book));
      }
    } finally {
      await dataSink.flush();
      await dataSink.close();
    }

    await File(path.join(outDir.path, 'lastItem.json'))
        .writeAsString(lastItemStr);
    await File(path.join(outDir.path, 'bookmark.json'))
        .writeAsString(bookmarkStr);

    log.write(
        '  ttu ${language.languageCode}: ${dataList.length} books exported');
    return dataList.isNotEmpty;
  }

  /// Run the import against TTU for [language] using files
  /// produced by [_exportTtuForLanguage].
  static Future<void> _importTtuForLanguage(
    Language language,
    Directory inDir,
    _ExLog log,
    LongOpProgressTracker tracker,
  ) async {
    final port = ReaderTtuSource.instance.getPortForLanguage(language);
    log.write('ttu import: ${language.languageCode} on port $port');

    final dataFile = File(path.join(inDir.path, 'data.jsonl'));
    final lastItemFile = File(path.join(inDir.path, 'lastItem.json'));
    final bookmarkFile = File(path.join(inDir.path, 'bookmark.json'));

    if (!dataFile.existsSync()) {
      log.write('  data.jsonl missing, skipping');
      return;
    }

    await ReaderTtuSource.instance.serveLocalAssets(language);

    // Pre-load all books into memory. Each book is JSON of the
    // parsed-content + base64 cover, typically a few MB; for
    // libraries of dozens of books this fits comfortably in RAM.
    // For libraries of hundreds we would need to stream — leave a
    // TODO for that case.
    final books = <Map<String, dynamic>>[];
    final stream = dataFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (final line in stream) {
      if (line.trim().isEmpty) continue;
      try {
        books.add(jsonDecode(line) as Map<String, dynamic>);
      } catch (e) {
        log.error('  failed to parse book line: $e');
      }
    }
    final lastItems =
        lastItemFile.existsSync() ? lastItemFile.readAsStringSync() : '[]';
    final bookmarks =
        bookmarkFile.existsSync() ? bookmarkFile.readAsStringSync() : '[]';

    log.write('  parsed: ${books.length} books');

    // Spin up the headless WebView and complete an "IDB ready"
    // signal once we have run the clear-all step.
    final readyCompleter = Completer<InAppWebViewController>();
    final doneCompleter = Completer<bool>();
    HeadlessInAppWebView? webView;
    Timer? timeout;
    timeout = Timer(const Duration(minutes: 30), () {
      if (!doneCompleter.isCompleted) {
        log.error('  ttu import: timeout');
        doneCompleter.complete(false);
      }
    });

    webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:$port/'),
      ),
      onLoadStop: (controller, url) async {
        if (!readyCompleter.isCompleted) {
          readyCompleter.complete(controller);
        }
      },
    );
    await webView.run();

    try {
      final controller = await readyCompleter.future;

      // Clear existing stores.
      await controller.callAsyncJavaScript(
          functionBody: ReaderTtuSource.clearStoresJsBody);

      // Insert each book one at a time — keeps any single JS
      // payload manageable.
      var inserted = 0;
      for (final book in books) {
        tracker.detail('Restoring books: ${language.languageCode} '
            '(${inserted + 1}/${books.length})...');
        try {
          await controller.callAsyncJavaScript(
            functionBody: ReaderTtuSource.putBookJsBody,
            arguments: {'book': book},
          );
          inserted++;
        } catch (e) {
          log.error('  failed to insert book ${book["id"]}: $e');
        }
      }

      // Insert lastItems and bookmarks in one shot — small.
      await controller.callAsyncJavaScript(
        functionBody: ReaderTtuSource.putLastItemsJsBody,
        arguments: {'items': jsonDecode(lastItems)},
      );
      await controller.callAsyncJavaScript(
        functionBody: ReaderTtuSource.putBookmarksJsBody,
        arguments: {'items': jsonDecode(bookmarks)},
      );

      log.write('  ttu ${language.languageCode}: $inserted books imported');
      if (!doneCompleter.isCompleted) doneCompleter.complete(true);
    } catch (e, st) {
      log.error('  ttu import failed: $e\n$st');
      if (!doneCompleter.isCompleted) doneCompleter.complete(false);
    } finally {
      timeout.cancel();
      try {
        await webView.dispose();
      } catch (_) {}
    }

    await doneCompleter.future;
  }

  // -------------------------------------------------------------
  // AUDIO PATH REMAP
  // -------------------------------------------------------------
  //
  // MediaItem.mediaIdentifier for audio sources is an absolute file
  // path. After importing on a different device the original paths
  // are unlikely to resolve — different external storage roots,
  // user reorganises their library, etc. We collect the unresolved
  // entries, ask the user for an old-prefix → new-prefix mapping,
  // and rewrite the rows.
  //
  // The user can repeat the remap until they are satisfied with
  // what is left unresolved.

  static Future<List<MediaItem>> _collectUnresolvedAudio(
    AppModel appModel,
    _ExLog log,
  ) async {
    final all =
        await appModel.database.mediaItems.where().findAll();
    final unresolved = <MediaItem>[];
    for (final item in all) {
      // Local file path heuristic: starts with `/` (absolute) and
      // does not look like an http(s) URL or a localhost TTU URL.
      // TTU's MediaItem.mediaIdentifier is HTTP, so it is excluded
      // by the heuristic and we do not bother trying to validate.
      final id = item.mediaIdentifier;
      if (!id.startsWith('/')) continue;
      if (!File(id).existsSync()) {
        unresolved.add(item);
      }
    }
    log.write('audio remap: ${unresolved.length} unresolved paths');
    return unresolved;
  }

  static Future<void> _runAudioRemapFlow({
    required AppModel appModel,
    required BuildContext context,
    required List<MediaItem> unresolved,
    required _ExLog log,
  }) async {
    var remaining = List<MediaItem>.from(unresolved);

    while (remaining.isNotEmpty && context.mounted) {
      // Show a summary + offer to remap.
      final action = await showDialog<_AudioRemapAction>(
        context: context,
        builder: (ctx) {
          // Show distinct directory prefixes so the user knows
          // what they are remapping FROM.
          final distinctParents = <String>{};
          for (final item in remaining) {
            distinctParents.add(File(item.mediaIdentifier).parent.path);
          }
          final preview = distinctParents.take(5).join('\n');
          return AlertDialog(
            title: const Text('Audio paths to remap'),
            content: SingleChildScrollView(
              child: Text(
                  '${remaining.length} audio item${remaining.length == 1 ? "" : "s"} '
                  'have paths that do not resolve on this device.\n\n'
                  'Original directories include:\n$preview'
                  '${distinctParents.length > 5 ? "\n…" : ""}\n\n'
                  'Pick a base directory on this device and we will '
                  'try to find the same filenames inside it.'),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, _AudioRemapAction.skip),
                child: const Text('Skip'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(ctx, _AudioRemapAction.remap),
                child: const Text('Pick base directory'),
              ),
            ],
          );
        },
      );

      if (action != _AudioRemapAction.remap || !context.mounted) {
        log.write('audio remap: user skipped, ${remaining.length} left');
        break;
      }

      // Pre-fill with the parent directory of the first unresolved
      // item so the user is editing a directory path, not a file
      // path. They typically only need to change the prefix portion
      // of the directory to point at where the audio lives on this
      // device. Falls back to the default shared-storage root if
      // for some reason `remaining` is empty by the time we reach
      // this point (defensive — the loop condition would have
      // broken us out).
      final seed = remaining.isEmpty
          ? '/storage/emulated/0/'
          : path.dirname(remaining.first.mediaIdentifier);
      final rawNewBase = await _promptForBaseDirectory(
        context,
        initialText: seed,
      );
      if (rawNewBase == null) continue;
      // The user may paste anything: a real directory, a file path
      // (because we seeded with the full unresolved file), or a
      // directory whose innermost segment does not exist yet.
      // Walk up until we hit an existing directory so the suffix
      // matcher has a real anchor; if nothing on the way up exists,
      // fall through with the raw input and let the matcher fail
      // uniformly — the user gets "nothing matched under X" and can
      // try again.
      final newBase = _normalizeNewBase(rawNewBase);
      log.write('audio remap: input=$rawNewBase normalized=$newBase');

      final db = appModel.database;
      final updates = <MediaItem>[];
      final stillUnresolved = <MediaItem>[];

      for (final item in remaining) {
        final candidate = _attemptRemap(item.mediaIdentifier, newBase);
        if (candidate != null && File(candidate).existsSync()) {
          updates.add(item.copyWith(mediaIdentifier: candidate));
        } else {
          stillUnresolved.add(item);
        }
      }

      if (updates.isNotEmpty) {
        await db.writeTxn(() async => db.mediaItems.putAll(updates));
        log.write('  remapped ${updates.length}, '
            '${stillUnresolved.length} still unresolved');
      } else {
        log.write('  nothing matched under $newBase');
      }
      remaining = stillUnresolved;

      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remap result'),
            content: Text(
                'Resolved: ${updates.length}\n'
                'Still unresolved: ${remaining.length}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Walk up from [input] until we find an existing directory. The
  /// user is allowed to paste anything into the audio-base prompt —
  /// a real directory, a file path (because we pre-fill with the
  /// full unresolved file path so they can see the originating
  /// shape), or a directory that does not exist yet. The suffix
  /// matcher in [_attemptRemap] needs a real anchor; this helper
  /// supplies one. If nothing on the way up exists we fall through
  /// with the raw input — the matcher then fails for every item
  /// and the user gets a "nothing matched" message, which is the
  /// honest failure mode.
  static String _normalizeNewBase(String input) {
    var current = input.trim();
    while (current.isNotEmpty && current != '/') {
      if (Directory(current).existsSync()) return current;
      final parent = path.dirname(current);
      if (parent == current) break;
      current = parent;
    }
    return input;
  }

  /// Suffix-replace the original path under [newBase]. We try the
  /// most-specific match first (full original parent) and walk up
  /// the tree until we find one that exists, so a moved-around
  /// library still resolves as long as the leaf folder names are
  /// preserved somewhere under the new base.
  static String? _attemptRemap(String originalPath, String newBase) {
    final originalSegments = originalPath.split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (originalSegments.isEmpty) return null;
    // Try suffixes of length 1, 2, 3, ... up to the full original.
    for (var take = 1; take <= originalSegments.length; take++) {
      final suffix = originalSegments
          .sublist(originalSegments.length - take)
          .join('/');
      final candidate = path.join(newBase, suffix);
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  static Future<String?> _promptForBaseDirectory(
    BuildContext context, {
    String initialText = '/storage/emulated/0/',
  }) async {
    final controller = TextEditingController(
      text: initialText,
    );
    return showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Audio base directory'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Type the absolute path on THIS device under which '
              'your audio files now live. Example:\n'
              '/storage/emulated/0/Audiobooks',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: '/storage/emulated/0/Audiobooks',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Use this'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // FILE-LEVEL HELPERS
  // -------------------------------------------------------------

  /// Recursively copy a directory, preserving structure. No skip
  /// filters needed here — callers are explicit about what they
  /// pass in.
  static Future<void> _copyDirectory(
      Directory source, Directory destination) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }
    await for (final entity in source.list()) {
      final name = path.basename(entity.path);
      final destPath = path.join(destination.path, name);
      if (entity is File) {
        await entity.copy(destPath);
      } else if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath));
      }
    }
  }

  /// Recursively copy a directory while reporting progress in
  /// `(copied/total)` form via [onProgress]. We pre-walk the
  /// source tree once to collect every file path (cheap — just
  /// stats), then iterate copying. Reports every 50 files copied
  /// (and on the final file) so the dialog updates often enough
  /// to look alive but not so often that we spam the framework
  /// with rebuilds during a tens-of-thousands-of-files copy.
  ///
  /// Used by export's `dictionaryResources/` passthrough and the
  /// matching import side, both of which can take minutes on a
  /// large per-language audio/image library.
  static Future<void> _copyDirectoryWithProgress(
    Directory source,
    Directory destination, {
    void Function(int copied, int total)? onProgress,
  }) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    // Pre-walk: gather every File under [source] to know the
    // denominator for progress reporting. Sync listing (cheap and
    // simpler than streaming) — for a typical dictionaryResources
    // dir of tens of thousands of files this is sub-second.
    final allFiles = <File>[];
    void walk(Directory dir) {
      for (final entity in dir.listSync(followLinks: false)) {
        if (entity is File) {
          allFiles.add(entity);
        } else if (entity is Directory) {
          walk(entity);
        }
      }
    }
    walk(source);

    final total = allFiles.length;
    int processed = 0;
    int skipped = 0;
    for (final f in allFiles) {
      final rel = path.relative(f.path, from: source.path);
      final destPath = path.join(destination.path, rel);
      final destDir = Directory(path.dirname(destPath));
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }
      try {
        await f.copy(destPath);
      } on FileSystemException catch (e) {
        // Source vanished between walk and copy. Common with live
        // data dirs — Chromium IndexedDB blob GC, browser caches,
        // etc. delete files in the background. Rather than fail
        // the whole operation we skip the file and keep going;
        // the bundle just lacks a transient cache entry, which is
        // semantically equivalent to having taken the snapshot a
        // moment later. We log so devs can see how often it fires.
        skipped++;
        debugPrint('copy skip (vanished): $rel ($e)');
      }
      processed++;
      if (onProgress != null &&
          (processed % 50 == 0 || processed == total)) {
        onProgress(processed, total);
      }
    }
    // Always emit a final 0/0 (or whatever) callback in case the
    // directory was empty, so callers see the empty state without
    // having to special-case it.
    if (onProgress != null && total == 0) {
      onProgress(0, 0);
    }
    if (skipped > 0) {
      debugPrint('_copyDirectoryWithProgress: '
          '$skipped/$total files vanished mid-copy');
    }
  }

  /// Recursively delete a directory while reporting progress in
  /// `(deleted/total)` form via [onProgress]. Like
  /// [_copyDirectoryWithProgress] this pre-walks the source tree
  /// to count files so the dialog has a real denominator. Then
  /// it deletes files individually, then walks the directory tree
  /// bottom-up to remove now-empty directories, and finally
  /// removes [target] itself.
  ///
  /// `Directory.delete(recursive: true)` does the same job in one
  /// async call but offers no per-file callback, so on slow
  /// flash a multi-GB delete looks frozen for tens of seconds —
  /// the "Cleaning up..." dialog hangs at the same string the
  /// whole time. This explicit walk is slightly slower in absolute
  /// terms but provides the visible progress the user expects.
  ///
  /// Errors on individual files are logged via debugPrint and
  /// counted, but do not abort. A leftover few files in the source
  /// tree at end of cleanup are not catastrophic; we will retry
  /// on next run.
  static Future<void> _deleteDirectoryWithProgress(
    Directory target, {
    void Function(int deleted, int total)? onProgress,
    void Function(String phase)? onPhase,
  }) async {
    if (!target.existsSync()) {
      if (onProgress != null) onProgress(0, 0);
      return;
    }

    // Pre-walk file count for the denominator. We only count
    // files; directory removals at the end are bulk and not worth
    // showing in progress.
    //
    // The walk itself can take many seconds on a large tree on
    // slow flash — every directory entry is a syscall, and
    // /sdcard's FUSE layer is not fast. Without a callback during
    // the walk, the calling dialog stays at its previous text
    // (typically "Cleaning up... (0)") until the walk finishes
    // and the first file gets deleted, looking frozen. The
    // `onPhase` callback lets the caller distinguish "I'm
    // counting" from "I'm deleting."
    if (onPhase != null) onPhase('Counting files...');
    final allFiles = <File>[];
    final allDirs = <Directory>[];

    // Async walk: `listSync` blocks the whole isolate for the
    // duration of the directory traversal — on a multi-thousand-
    // file tree on /sdcard FUSE that is many seconds during which
    // the UI cannot repaint. The async `list()` stream lets the
    // event loop drain between batches of entries, so the dialog
    // can pump frames and show the user that work is happening.
    // We also publish a running count so the user sees the walk
    // progressing rather than a static "Counting files..."
    var seenSoFar = 0;
    Future<void> walk(Directory dir) async {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) {
          allFiles.add(entity);
        } else if (entity is Directory) {
          allDirs.add(entity);
          await walk(entity);
        }
        seenSoFar++;
        if (seenSoFar % 200 == 0 && onPhase != null) {
          onPhase('Counting files... ($seenSoFar)');
        }
      }
    }
    await walk(target);

    final total = allFiles.length;
    // Publish denominator immediately so the user sees "(0/N)"
    // instead of just "(0)" while the first 50 deletions happen.
    // Useful especially on dirs with few large files where the
    // first throttled progress callback (every 50 deletions) may
    // never fire before total files are exhausted.
    if (onProgress != null) onProgress(0, total);
    if (onPhase != null) onPhase('Deleting files...');

    int deleted = 0;
    int skipped = 0;
    for (final f in allFiles) {
      try {
        await f.delete();
      } catch (e) {
        skipped++;
        debugPrint('delete skip: ${f.path} ($e)');
      }
      deleted++;
      if (onProgress != null && (deleted % 50 == 0 || deleted == total)) {
        onProgress(deleted, total);
      }
    }

    // Bottom-up directory removal: deepest paths first so a parent
    // is empty by the time we try to remove it. Sort by path
    // length descending as a cheap proxy for depth.
    allDirs.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (final d in allDirs) {
      try {
        await d.delete();
      } catch (_) {
        // Non-empty (probably an undeleted file, maybe vanished
        // and re-created mid-walk) or already gone. Ignore.
      }
    }
    try {
      await target.delete();
    } catch (e) {
      debugPrint('failed to delete root ${target.path}: $e');
    }

    if (onProgress != null && total == 0) {
      onProgress(0, 0);
    }
    if (skipped > 0) {
      debugPrint('_deleteDirectoryWithProgress: '
          '$skipped/$total files failed to delete');
    }
  }
}

enum _AudioRemapAction { skip, remap }

/// Append-only diagnostic log mirroring [AppBackupRestore]'s log,
/// distinct file naming so export/import sessions do not collide
/// with backup/restore sessions.
class _ExLog {
  _ExLog._(this.logPath, this._sink);

  factory _ExLog.create(String kind) {
    // File logging on disk at /storage/emulated/0/tmp/. We had this
    // disabled briefly but every import/export issue we have hit
    // since requires the log to diagnose, so it stays on. The log
    // path is a few hundred KB at most for a typical run.
    try {
      final dir = Directory('/storage/emulated/0/tmp');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final ts = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final p = '${dir.path}/shiroikumanojisho_${kind}_$ts.log';
      final sink = File(p).openWrite(mode: FileMode.write);
      sink.writeln('=== shiroikumanojisho $kind log ===');
      sink.writeln('opened: ${DateTime.now().toIso8601String()}');
      return _ExLog._(p, sink);
    } catch (e) {
      debugPrint('log open failed: $e');
      return _ExLog._('(log unavailable)', null);
    }
  }

  final String logPath;
  final IOSink? _sink;

  void write(String line) {
    final ts = DateTime.now().toIso8601String();
    debugPrint('[$ts] $line');
    try {
      _sink?.writeln('[$ts] $line');
    } catch (_) {}
  }

  void error(String line) => write('ERROR: $line');

  void close() {
    try {
      _sink?.writeln('closed: ${DateTime.now().toIso8601String()}');
      _sink?.close();
    } catch (_) {}
  }
}

/// Progress dialog with a live-updating status line. The string
/// updates via a `ValueNotifier` so the orchestrator can change it
/// from arbitrary depths in the call stack without rebuilding the
/// dialog scaffold.
/// Progress dialog for long multi-step operations like export,
/// import, backup, and restore. Backed by two notifiers — one for
/// the title (which carries the `(N/M)` step counter so users can
/// see where they are in the overall flow) and one for the body
/// (the current activity detail, e.g. `Exporting dictionary
/// entries... (45,000/9,739,165)`).
///
/// This is public so [AppBackupRestore] can reuse it without
/// having to duplicate the widget.
class LongOpProgressDialog extends StatelessWidget {
  const LongOpProgressDialog({
    super.key,
    required this.titleNotifier,
    required this.bodyNotifier,
  });

  final ValueNotifier<String> titleNotifier;
  final ValueNotifier<String> bodyNotifier;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: ValueListenableBuilder<String>(
        valueListenable: titleNotifier,
        builder: (_, value, __) => Text(value),
      ),
      content: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 24),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: bodyNotifier,
              builder: (_, value, __) => Text(value),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tracks "step N of M" through a long multi-step operation and
/// pushes updates into the two notifiers consumed by
/// [LongOpProgressDialog].
///
/// The driver code calls [step] when entering a new major phase
/// (e.g. "Exporting database", "Compressing"), and [detail] for
/// fine-grained updates within a phase ("(45,000/9,739,165)").
/// The dialog title shows `<operation> (current/total)` and the
/// body shows the most recent detail string.
class LongOpProgressTracker {
  LongOpProgressTracker({
    required this.operation,
    required this.totalSteps,
  })  : titleNotifier = ValueNotifier<String>('$operation (0/$totalSteps)'),
        bodyNotifier = ValueNotifier<String>('Starting...');

  final String operation;
  final int totalSteps;
  final ValueNotifier<String> titleNotifier;
  final ValueNotifier<String> bodyNotifier;
  int _currentStep = 0;

  /// Advance to the next major step. The new step name is shown
  /// in the body until [detail] is called with finer-grained
  /// progress text.
  void step(String stepName) {
    _currentStep++;
    titleNotifier.value = '$operation ($_currentStep/$totalSteps)';
    bodyNotifier.value = stepName;
  }

  /// Update the body detail without advancing the step counter.
  /// Use during long sub-operations (large file copies, ZIP
  /// progress, big collection dumps) to keep the user informed.
  void detail(String text) {
    bodyNotifier.value = text;
  }
}
