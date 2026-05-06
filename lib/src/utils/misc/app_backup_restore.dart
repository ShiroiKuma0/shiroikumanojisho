import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/src/utils/components/folder_file_picker.dart';
import 'package:shiroikumanojisho/src/utils/misc/app_export_import.dart'
    show LongOpProgressDialog, LongOpProgressTracker;

/// Full-fidelity, same-device backup and restore. The bundle is a
/// byte-for-byte snapshot of the app's data root (skipping caches);
/// restoring it on a different device almost certainly will NOT do
/// what the user wants because Android WebView writes its data into
/// a vendor-specific subdirectory (`app_webview/` for stock
/// Chromium, `app_hws_webview/` for Huawei HMS) and a copy from one
/// vendor to the other lands in a directory the destination's
/// WebView never reads. Use [AppExportImport] for cross-device
/// migration.
///
/// Restore design (post-1.1.0 rewrite):
///
/// 1. ZIP picking goes through [FolderFilePicker], NOT
///    `file_picker`. The latter materialises the picked file by
///    copying it into `cache/file_picker/` on Android OEM builds
///    that route external storage through SAF (confirmed Huawei
///    EMUI/HarmonyOS, suspected on Boox-style heavily-skinned
///    Android). Each restore attempt thus accumulated another full
///    copy of the backup in app cache; the symptom was "app gets
///    killed mid-restore and used storage grows by the backup size
///    each retry" until ENOSPC. With the folder picker we get a
///    real `/storage/emulated/0/...` path and never copy.
///
/// 2. Extract goes to `<dataRoot>/.restore_staging/`, NOT to
///    `cache/`. Same filesystem as the live data we are about to
///    replace, so the per-child rename in step 3 is O(1).
///
/// 3. Per-child atomic swap. For each top-level child that the
///    backup contributes (e.g. `app_flutter`, `files`,
///    `app_webview`, etc.), rename the live one to
///    `.restore_old_<name>`, then rename the staged one into place.
///    On any failure mid-swap, we reverse the renames we have
///    completed so far. On success we delete the `.restore_old_*`
///    set in a final cleanup pass.
///
///    Versus the previous "wipe live tree, then copy from cache":
///    transient peak storage during a successful restore drops from
///    ~3x backup-size (file_picker copy + extracted staging + new
///    data) to ~1x (extracted staging + brief overlap during each
///    rename pair). And a partial-failure no longer corrupts the
///    data root — rollback restores the pre-restore state.
///
/// 4. Defensive `cache/file_picker/` purge at the start, in case
///    the user previously hit the broken pre-1.1.0 path or some
///    other code in the app regresses into using `file_picker`.
///
/// 5. Diagnostic log written to
///    `/storage/emulated/0/tmp/shiroikumanojisho_restore_<ts>.log`
///    at every step. Survives the post-restore `exit(0)` and any
///    crashes; the user can read it without a debugger to see what
///    happened.
class AppBackupRestore {
  /// Top-level directories under [dataRoot] that the restore must
  /// never touch — managed by Android (`lib`, the symlink to native
  /// libraries) or transient (`cache`, `code_cache`).
  ///
  /// Note that `lib` is intentionally a directory under app data;
  /// it is created by the Android packaging layer pointing at the
  /// real native-libraries path. Removing or renaming it fails
  /// loudly and breaks the next launch's JNI lookup.
  static const Set<String> _restoreNeverTouch = {
    'lib',
    'cache',
    'code_cache',
  };

  /// Equivalent set used by backup creation — same idea but also
  /// excludes our own scratch directories so we never zip them up.
  static const Set<String> _backupTopLevelSkip = {
    'cache',
    'code_cache',
    'lib',
    'dictionaryImportWorkingDirectory',
    'backup_staging',
    'backup_restore',
    '.restore_staging',
  };

  /// Directories at any depth that should be excluded — caches that
  /// browsers and WebViews scatter throughout their data tree.
  /// Skipping these keeps the backup zip to a reasonable size.
  static const Set<String> _backupSkipNested = {
    'Cache',
    'Code Cache',
    'GPU Cache',
    'GPUCache',
    'CacheStorage',
    'Crashpad',
    'pending_crash_reports',
  };

  /// Create a backup ZIP of all app data.
  static Future<void> createBackup({
    required AppModel appModel,
    required BuildContext context,
  }) async {
    final navigator = Navigator.of(context);
    final log = _RestoreLog.create('backup');

    // Two major steps: copy data → staging, compress staging → zip.
    final tracker = LongOpProgressTracker(
      operation: 'Backing up',
      totalSteps: 2,
    );
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LongOpProgressDialog(
        titleNotifier: tracker.titleNotifier,
        bodyNotifier: tracker.bodyNotifier,
      ),
    );

    try {
      final dataRoot = appModel.appDirectory.parent;
      log.write('dataRoot: ${dataRoot.path}');

      final staging = Directory(
          path.join(appModel.temporaryDirectory.path, 'backup_staging'));
      if (staging.existsSync()) staging.deleteSync(recursive: true);
      staging.createSync(recursive: true);
      log.write('staging: ${staging.path}');

      // Copy entire data root, skipping cache and temp directories.
      // `app_hws_webview` (Huawei) and `app_webview` (standard
      // Chromium) are intentionally NOT top-level excluded: their
      // `IndexedDB/` and `Local Storage/` subdirectories hold TTU's
      // books and reader settings respectively. The `_backupSkipNested`
      // set keeps cache subdirectories out of the backup at any depth,
      // which is enough to keep the zip to a reasonable size without
      // throwing away the user's library.
      tracker.step('Copying app data...');
      await _copyDirectoryWithProgress(
        dataRoot,
        staging,
        skip: _backupTopLevelSkip,
        skipNested: _backupSkipNested,
        onProgress: (copied, total) {
          final fmt = NumberFormat.decimalPattern();
          tracker.detail(
              'Copying app data... '
              '(${fmt.format(copied)}/${fmt.format(total)})');
        },
      );

      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final filename = 'shiroikumanojisho_backup_$timestamp.zip';

      final tmpDir = Directory('/storage/emulated/0/tmp');
      if (!tmpDir.existsSync()) tmpDir.createSync(recursive: true);
      final zipFile = File(path.join(tmpDir.path, filename));
      if (zipFile.existsSync()) zipFile.deleteSync();

      tracker.step('Compressing...');
      log.write('zipping to ${zipFile.path}');
      await ZipFile.createFromDirectory(
        sourceDir: staging,
        zipFile: zipFile,
        onZipping: (fileName, isDirectory, progressPercent) {
          tracker.detail(
              'Compressing... (${progressPercent.toStringAsFixed(0)}%)');
          return ZipFileOperation.includeItem;
        },
      );
      log.write('zip done, size=${zipFile.statSync().size}');

      staging.deleteSync(recursive: true);
      log.close();

      if (navigator.canPop()) navigator.pop();

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup complete'),
            content: Text('Saved to:\n${zipFile.path}'),
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
      log.error('Backup failed: $e\n$st');
      log.close();
      if (navigator.canPop()) navigator.pop();
      debugPrint('Backup error: $e');
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup failed'),
            content: Text('$e\n\nLog: ${log.path}'),
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

  /// Restore app data from a backup ZIP.
  static Future<void> restoreBackup({
    required AppModel appModel,
    required BuildContext context,
  }) async {
    final log = _RestoreLog.create('restore');
    try {
      // 1. Pick the ZIP via the folder picker (real path, no
      // file_picker materialisation).
      final zipPath = await Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => FolderFilePicker(
            appModel: appModel,
            allowedExtensions: const ['.zip'],
            fileIcon: Icons.archive,
            title: 'Pick backup ZIP',
            initialDir: '/storage/emulated/0/tmp',
          ),
        ),
      );
      if (zipPath == null) {
        log.write('user cancelled at picker');
        log.close();
        return;
      }
      log.write('picked: $zipPath');

      final zipFile = File(zipPath);
      if (!zipFile.existsSync()) {
        log.error('zip does not exist: $zipPath');
        log.close();
        if (context.mounted) {
          Fluttertoast.showToast(msg: 'Selected ZIP not found');
        }
        return;
      }
      final zipSize = zipFile.statSync().size;
      log.write('zip size: $zipSize bytes');

      // 2. Confirm
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore backup'),
          content: Text(
              'Restore from:\n${path.basename(zipPath)}\n\n'
              'This will replace all current app data. '
              'The app will close after restore.\n\nContinue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Restore',
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

      // 3. Show progress dialog (non-dismissible). Three major
      // steps: extract zip, swap data, finalize. Swap is the bulk
      // of the time on a large library and the steps within it
      // (rename live→.restore_old, rename staging→live, delete
      // .restore_old) are atomic per-child so we can show
      // (copied/total) progress against the child count.
      final tracker = LongOpProgressTracker(
        operation: 'Restoring',
        totalSteps: 3,
      );
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LongOpProgressDialog(
          titleNotifier: tracker.titleNotifier,
          bodyNotifier: tracker.bodyNotifier,
        ),
      );

      // 4. Defensive: clean any prior file_picker materialisations
      // out of cache. We never want them and they accumulate per
      // failed restore attempt under the pre-1.1.0 path.
      _cleanFilePickerCache(appModel, log.write);

      // 5. Extract to a sibling of the live children inside dataRoot,
      // so the per-child rename in step 6 is a same-filesystem
      // operation (O(1) metadata change).
      tracker.step('Extracting backup...');
      final dataRoot = appModel.appDirectory.parent;
      log.write('dataRoot: ${dataRoot.path}');
      final staging =
          Directory(path.join(dataRoot.path, '.restore_staging'));
      if (staging.existsSync()) {
        log.write('clearing existing staging: ${staging.path}');
        staging.deleteSync(recursive: true);
      }
      staging.createSync(recursive: true);

      log.write('extracting to ${staging.path}');
      await ZipFile.extractToDirectory(
        zipFile: zipFile,
        destinationDir: staging,
        onExtracting: (zipEntry, progressPercent) {
          tracker.detail(
              'Extracting backup... (${progressPercent.toStringAsFixed(0)}%)');
          return ZipFileOperation.includeItem;
        },
      );
      log.write('extract complete');

      // 6. Decide format: post-rename backups have data-root layout
      // (children like app_flutter/, files/, app_webview/ at the
      // top level); pre-rename backups have legacy app/ + db/ +
      // webview/ layout.
      final isLegacyBackup =
          Directory(path.join(staging.path, 'app')).existsSync();
      log.write('format: ${isLegacyBackup ? "legacy" : "root"}');

      tracker.step('Applying restore...');
      if (isLegacyBackup) {
        await _restoreLegacy(appModel, staging, log.write);
      } else {
        await _restoreRoot(appModel, staging, log.write);
      }

      // 7. Cleanup staging — by this point either swap succeeded
      // (staging is empty of useful content, just leftover dir
      // markers) or _restoreRoot threw and we have rolled back.
      tracker.step('Finalizing...');
      if (staging.existsSync()) {
        try {
          staging.deleteSync(recursive: true);
          log.write('removed staging');
        } catch (e) {
          log.error('failed to remove staging: $e');
        }
      }

      log.write('restore complete, exiting');
      log.close();

      if (navigator.canPop()) navigator.pop();
      Fluttertoast.showToast(msg: 'Restore complete. Closing app...');

      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    } catch (e, st) {
      log.error('restore failed: $e\n$st');
      log.close();
      debugPrint('Restore error: $e');
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
            title: const Text('Restore failed'),
            content: Text('$e\n\nLog: ${log.path}'),
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

  /// Per-child atomic swap from staging to live data root. See class
  /// docstring section "3. Per-child atomic swap" for the strategy.
  static Future<void> _restoreRoot(
    AppModel appModel,
    Directory staging,
    void Function(String) log,
  ) async {
    final dataRoot = appModel.appDirectory.parent;
    // Ordered list of (livePath, oldRenamedPath) for every successful
    // live→old rename, so that on failure mid-swap we can reverse them
    // in reverse order.
    final List<MapEntry<String, String>> renamedOld = [];
    // Children that got their staged version moved into place — so on
    // rollback we know to remove them before restoring the old.
    final List<String> movedIntoLive = [];
    final tsSuffix = DateTime.now().microsecondsSinceEpoch;

    try {
      final stagedChildren = staging.listSync(followLinks: false);
      log('staged children: '
          '${stagedChildren.map((e) => path.basename(e.path)).join(", ")}');

      for (final entity in stagedChildren) {
        final name = path.basename(entity.path);
        if (_restoreNeverTouch.contains(name)) {
          log('skipping never-touch child: $name');
          continue;
        }
        final livePath = path.join(dataRoot.path, name);
        final oldPath = path.join(
            dataRoot.path, '.restore_old_${name}_$tsSuffix');

        final liveType = FileSystemEntity.typeSync(livePath);
        if (liveType != FileSystemEntityType.notFound) {
          log('rename live→old: $livePath → $oldPath');
          if (liveType == FileSystemEntityType.directory) {
            Directory(livePath).renameSync(oldPath);
          } else {
            File(livePath).renameSync(oldPath);
          }
          renamedOld.add(MapEntry(livePath, oldPath));
        }

        log('rename staged→live: ${entity.path} → $livePath');
        if (entity is Directory) {
          entity.renameSync(livePath);
        } else if (entity is File) {
          entity.renameSync(livePath);
        } else {
          log('  (skipping non-file/dir entity)');
          continue;
        }
        movedIntoLive.add(livePath);
      }

      // Success — delete the displaced old children. Last so that any
      // failure above leaves the originals reachable for rollback.
      for (final entry in renamedOld) {
        final oldPath = entry.value;
        log('cleanup old: $oldPath');
        try {
          final t = FileSystemEntity.typeSync(oldPath);
          if (t == FileSystemEntityType.directory) {
            Directory(oldPath).deleteSync(recursive: true);
          } else if (t == FileSystemEntityType.file) {
            File(oldPath).deleteSync();
          }
        } catch (e) {
          // Non-fatal — the swap already succeeded; this is just
          // disk-space cleanup.
          log('  cleanup failed (non-fatal): $e');
        }
      }
    } catch (e) {
      log('swap aborted at: $e — rolling back');

      for (final livePath in movedIntoLive.reversed) {
        try {
          final t = FileSystemEntity.typeSync(livePath);
          if (t == FileSystemEntityType.directory) {
            Directory(livePath).deleteSync(recursive: true);
          } else if (t == FileSystemEntityType.file) {
            File(livePath).deleteSync();
          }
          log('rollback: removed $livePath');
        } catch (e2) {
          log('rollback: failed to remove $livePath: $e2');
        }
      }
      for (final entry in renamedOld.reversed) {
        final livePath = entry.key;
        final oldPath = entry.value;
        try {
          final t = FileSystemEntity.typeSync(oldPath);
          if (t == FileSystemEntityType.directory) {
            Directory(oldPath).renameSync(livePath);
          } else if (t == FileSystemEntityType.file) {
            File(oldPath).renameSync(livePath);
          }
          log('rollback: restored $livePath from $oldPath');
        } catch (e2) {
          log('rollback: failed to restore $livePath from $oldPath: $e2');
        }
      }

      rethrow;
    }
  }

  /// Legacy backup format (`app/` + `db/` + optional `webview/`).
  /// Kept for users who still have ancient bundles; the rename-swap
  /// strategy is overkill here because each of the three paths maps
  /// to a known fixed destination, and the legacy layout itself is
  /// frozen.
  static Future<void> _restoreLegacy(
    AppModel appModel,
    Directory extractDir,
    void Function(String) log,
  ) async {
    final appBackup = Directory(path.join(extractDir.path, 'app'));
    final dbBackup = Directory(path.join(extractDir.path, 'db'));

    if (!appBackup.existsSync() || !dbBackup.existsSync()) {
      throw 'Invalid legacy backup (missing app/ or db/)';
    }

    log('  legacy: clearing appDirectory');
    await _clearDirectory(appModel.appDirectory,
        skip: {'dictionaryImportWorkingDirectory'});
    log('  legacy: copying app/ -> appDirectory');
    await _copyDirectory(appBackup, appModel.appDirectory);

    log('  legacy: clearing databaseDirectory');
    await _clearDirectory(appModel.databaseDirectory);
    log('  legacy: copying db/ -> databaseDirectory');
    await _copyDirectory(dbBackup, appModel.databaseDirectory);

    final wvBackup = Directory(path.join(extractDir.path, 'webview'));
    if (wvBackup.existsSync()) {
      final webviewDir = Directory(
          path.join(appModel.appDirectory.parent.path, 'app_webview'));
      if (webviewDir.existsSync()) {
        log('  legacy: clearing app_webview');
        await _clearDirectory(webviewDir);
      }
      log('  legacy: copying webview/ -> app_webview');
      await _copyDirectory(wvBackup, webviewDir);
    }
  }

  /// Wipe `cache/file_picker/` and any sibling `cache/file_picker_*`
  /// directories. These accumulate in the broken pre-1.1.0 path
  /// because `file_picker` materialises picked external-storage
  /// files into them and never cleans up. Best-effort — failures
  /// are logged but not fatal.
  static void _cleanFilePickerCache(
      AppModel appModel, void Function(String) log) {
    try {
      final cacheRoot = appModel.temporaryDirectory;
      if (!cacheRoot.existsSync()) return;
      for (final entity in cacheRoot.listSync(followLinks: false)) {
        if (entity is! Directory) continue;
        final name = path.basename(entity.path);
        if (name == 'file_picker' || name.startsWith('file_picker')) {
          try {
            entity.deleteSync(recursive: true);
            log('cleaned ${entity.path}');
          } catch (e) {
            log('failed to clean ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      log('file_picker cache walk failed: $e');
    }
  }

  /// Recursively copy a directory.
  ///
  /// [skip] applies only at the top level — names matching are skipped.
  /// [skipNested] applies at any depth — directories matching are skipped
  /// regardless of where they appear in the tree (used for cache dirs that
  /// browsers/WebViews scatter through their data directory).
  static Future<void> _copyDirectory(
    Directory source,
    Directory destination, {
    Set<String> skip = const {},
    Set<String> skipNested = const {},
  }) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    await for (var entity in source.list()) {
      final name = path.basename(entity.path);
      if (skip.contains(name)) continue;
      if (skipNested.contains(name)) continue;

      final destPath = path.join(destination.path, name);
      if (entity is File) {
        await entity.copy(destPath);
      } else if (entity is Directory) {
        // Pass an empty `skip` to nested calls (top-level-only filter), but
        // continue propagating `skipNested` all the way down.
        await _copyDirectory(
          entity,
          Directory(destPath),
          skipNested: skipNested,
        );
      }
    }
  }

  /// Same as [_copyDirectory] but pre-walks the source tree to count
  /// files first, then reports `(copied/total)` via [onProgress] as
  /// it copies. Used by `createBackup` so the dialog shows real
  /// progress instead of a static "Creating backup..." message.
  /// Reports every 50 files, plus on the final file.
  ///
  /// We mirror the skip semantics of [_copyDirectory] exactly:
  /// `skip` filters at the top level only, `skipNested` filters at
  /// every level. This is important because backup needs to skip
  /// `app_hws_webview/Cache/` etc. inside an otherwise-included
  /// directory.
  static Future<void> _copyDirectoryWithProgress(
    Directory source,
    Directory destination, {
    Set<String> skip = const {},
    Set<String> skipNested = const {},
    void Function(int copied, int total)? onProgress,
  }) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    final allFiles = <_FileToCopy>[];
    void walk(Directory dir, String relPrefix, {required bool isRoot}) {
      for (final entity in dir.listSync(followLinks: false)) {
        final name = path.basename(entity.path);
        if (isRoot && skip.contains(name)) continue;
        if (skipNested.contains(name)) continue;
        final childRel = relPrefix.isEmpty ? name : '$relPrefix/$name';
        if (entity is File) {
          allFiles.add(_FileToCopy(entity, childRel));
        } else if (entity is Directory) {
          walk(entity, childRel, isRoot: false);
        }
      }
    }
    walk(source, '', isRoot: true);

    final total = allFiles.length;
    int processed = 0;
    int skipped = 0;
    for (final f in allFiles) {
      final destPath = path.join(destination.path, f.relPath);
      final destDir = Directory(path.dirname(destPath));
      if (!destDir.existsSync()) {
        destDir.createSync(recursive: true);
      }
      try {
        await f.file.copy(destPath);
      } on FileSystemException catch (e) {
        // Source vanished between walk and copy. Common when
        // backing up a *live* data directory: Chromium WebView
        // garbage-collects IndexedDB blobs on the fly, browsers
        // sweep their caches, etc. The pre-walk window may be
        // seconds wide (tens of thousands of files) which is
        // plenty of time for a transient blob to disappear.
        // Skip the file and keep going — the bundle just lacks
        // a transient cache entry, which is semantically the
        // same as having taken the snapshot a moment later.
        skipped++;
        debugPrint('backup copy skip (vanished): ${f.relPath} ($e)');
      }
      processed++;
      if (onProgress != null &&
          (processed % 50 == 0 || processed == total)) {
        onProgress(processed, total);
      }
    }
    if (onProgress != null && total == 0) {
      onProgress(0, 0);
    }
    if (skipped > 0) {
      debugPrint('backup _copyDirectoryWithProgress: '
          '$skipped/$total files vanished mid-copy');
    }
  }

  /// Clear contents of a directory without deleting the directory itself.
  static Future<void> _clearDirectory(
    Directory directory, {
    Set<String> skip = const {},
  }) async {
    if (!directory.existsSync()) return;

    await for (var entity in directory.list()) {
      final name = path.basename(entity.path);
      if (skip.contains(name)) continue;

      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
    }
  }
}

/// Internal wrapper used by [_copyDirectoryWithProgress] to keep
/// each file's source File and its destination-relative path
/// together as we walk the source tree.
class _FileToCopy {
  _FileToCopy(this.file, this.relPath);
  final File file;
  final String relPath;
}

/// Append-only diagnostic log written to shared external storage so
/// it survives any post-restore `exit(0)` and is reachable from any
/// file manager. The user can paste contents back into a bug report
/// without ADB.
///
/// Best-effort — if writing fails (no permission, no space) the log
/// degrades to a no-op rather than taking down the operation it was
/// supposed to be diagnosing.
class _RestoreLog {
  _RestoreLog._(this.path, this._sink);

  /// Open a fresh log at
  /// `/storage/emulated/0/tmp/shiroikumanojisho_<kind>_<ts>.log`.
  /// Kind is something like `restore` or `backup`.
  factory _RestoreLog.create(String kind) {
    // File logging on disk at /storage/emulated/0/tmp/. See
    // equivalent note in `_ExLog.create` — kept on so we can
    // diagnose backup/restore issues from the same shared-storage
    // location as export/import.
    try {
      final dir = Directory('/storage/emulated/0/tmp');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final ts = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      final p = '${dir.path}/shiroikumanojisho_${kind}_$ts.log';
      final f = File(p);
      final sink = f.openWrite(mode: FileMode.write);
      sink.writeln('=== shiroikumanojisho $kind log ===');
      sink.writeln('opened: ${DateTime.now().toIso8601String()}');
      return _RestoreLog._(p, sink);
    } catch (e) {
      debugPrint('log open failed: $e');
      return _RestoreLog._('(log unavailable)', null);
    }
  }

  final String path;
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
