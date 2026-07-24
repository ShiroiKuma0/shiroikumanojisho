import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/models.dart';

import 'dictionary_resource_cleanup.dart';

/// Developer-facing diagnostics dialog showing on-disk storage usage and
/// search performance. Reached by long-pressing the version label on the
/// home page.
///
/// The dialog is intentionally text-heavy and unstyled. It is not localised.
class StorageBenchmarkDialog extends StatefulWidget {
  /// Initialise the dialog.
  const StorageBenchmarkDialog({required this.appModel, super.key});

  /// The app model, used to resolve directory paths and run searches.
  final AppModel appModel;

  /// Show the dialog as a modal.
  static Future<void> show(BuildContext context, AppModel appModel) {
    return showDialog(
      context: context,
      builder: (_) => StorageBenchmarkDialog(appModel: appModel),
    );
  }

  @override
  State<StorageBenchmarkDialog> createState() => _StorageBenchmarkDialogState();
}

class _StorageBenchmarkDialogState extends State<StorageBenchmarkDialog> {
  AppModel get _appModel => widget.appModel;

  bool _scanning = true;
  String _summary = '';

  bool _benchmarking = false;
  String _benchmarkResult = '';

  @override
  void initState() {
    super.initState();
    _scanStorage();
  }

  Future<void> _scanStorage() async {
    setState(() {
      _scanning = true;
      _summary = 'Scanning…';
    });
    final summary = await compute(_scanStorageInIsolate, _ScanParams(
      appDirectoryPath: _appModel.appDirectory.path,
      databaseDirectoryPath: _appModel.databaseDirectory.path,
      dataRootPath: _appModel.appDirectory.parent.path,
    ));
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _summary = summary;
    });
  }

  Future<void> _runBenchmark() async {
    setState(() {
      _benchmarking = true;
      _benchmarkResult = 'Sampling terms…';
    });

    final database = Isar.getInstance();
    if (database == null) {
      setState(() {
        _benchmarking = false;
        _benchmarkResult = 'Database not open.';
      });
      return;
    }

    // Sample random term strings from the flat-schema entries
    // collection. Entries are the v2 equivalent of what headings used
    // to key; duplicates are fine since the benchmark measures average
    // search latency over arbitrary realistic inputs.
    final totalEntries = database.dictionaryEntrys.countSync();
    if (totalEntries == 0) {
      setState(() {
        _benchmarking = false;
        _benchmarkResult = 'No dictionary data — import a dictionary first.';
      });
      return;
    }

    const sampleSize = 100;
    final rng = math.Random(0xC0FFEE);
    final sampleOffsets = List<int>.generate(
      sampleSize,
      (_) => rng.nextInt(totalEntries),
    );

    // Pull terms via `offset+limit`. `findAllSync` with limit 1 is cheap.
    final terms = <String>[];
    for (final offset in sampleOffsets) {
      final entries = database.dictionaryEntrys
          .where()
          .anyTerm()
          .offset(offset)
          .limit(1)
          .findAllSync();
      if (entries.isNotEmpty) {
        terms.add(entries.first.term);
      }
    }

    if (terms.isEmpty) {
      setState(() {
        _benchmarking = false;
        _benchmarkResult = 'Could not sample any terms.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _benchmarkResult = 'Running ${terms.length} queries…';
    });

    // Run searches and time each one. We bypass the in-memory cache so we
    // measure cold-path performance.
    final timings = <int>[];
    final stopwatch = Stopwatch();
    for (final term in terms) {
      stopwatch.reset();
      stopwatch.start();
      try {
        await _appModel.searchDictionary(
          searchTerm: term,
          searchWithWildcards: false,
          useCache: false,
        );
      } catch (e) {
        // Ignore individual search failures — we want timing data.
      }
      stopwatch.stop();
      timings.add(stopwatch.elapsedMicroseconds);
    }

    timings.sort();
    final total = timings.fold<int>(0, (a, b) => a + b);
    final avg = total / timings.length;
    final median = timings[timings.length ~/ 2];
    final p95 = timings[(timings.length * 0.95).floor()
        .clamp(0, timings.length - 1)];
    final p99 = timings[(timings.length * 0.99).floor()
        .clamp(0, timings.length - 1)];
    final min = timings.first;
    final max = timings.last;

    final result = StringBuffer()
      ..writeln('Search benchmark — ${timings.length} queries')
      ..writeln('  total:   ${_formatMicros(total)}')
      ..writeln('  avg:     ${_formatMicros(avg.round())}')
      ..writeln('  median:  ${_formatMicros(median)}')
      ..writeln('  p95:     ${_formatMicros(p95)}')
      ..writeln('  p99:     ${_formatMicros(p99)}')
      ..writeln('  min:     ${_formatMicros(min)}')
      ..writeln('  max:     ${_formatMicros(max)}');

    if (!mounted) return;
    setState(() {
      _benchmarking = false;
      _benchmarkResult = result.toString();
    });
  }

  static String _formatMicros(int micros) {
    if (micros < 1000) return '$micros µs';
    if (micros < 1000000) return '${(micros / 1000).toStringAsFixed(1)} ms';
    return '${(micros / 1000000).toStringAsFixed(2)} s';
  }

  @override
  Widget build(BuildContext context) {
    final fullText = StringBuffer()
      ..writeln(_summary)
      ..writeln()
      ..writeln(_benchmarkResult.isEmpty
          ? '(benchmark not yet run)'
          : _benchmarkResult);

    return AlertDialog(
      title: const Text('Storage & Benchmark'),
      content: SingleChildScrollView(
        child: SelectableText(
          fullText.toString(),
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _scanning ? null : _scanStorage,
          child: const Text('Rescan'),
        ),
        TextButton(
          onPressed: (_scanning || _benchmarking) ? null : _runBenchmark,
          child: Text(_benchmarking ? 'Running…' : 'Run benchmark'),
        ),
        TextButton(
          onPressed: () {
            Share.share(fullText.toString(),
                subject: 'jidoujisho2 storage report');
          },
          child: const Text('Share'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Parameters for the off-isolate storage scan.
class _ScanParams {
  _ScanParams({
    required this.appDirectoryPath,
    required this.databaseDirectoryPath,
    required this.dataRootPath,
  });

  final String appDirectoryPath;
  final String databaseDirectoryPath;
  final String dataRootPath;
}

/// Top-level for use with `compute()`. Walks the filesystem and produces a
/// formatted summary string.
String _scanStorageInIsolate(_ScanParams params) {
  final buffer = StringBuffer();

  final dataRoot = Directory(params.dataRootPath);
  final appDir = Directory(params.appDirectoryPath);
  final dbDir = Directory(params.databaseDirectoryPath);
  final dictResources =
      Directory(path.join(params.appDirectoryPath, 'dictionaryResources'));

  buffer.writeln('Data root:  ${dataRoot.path}');
  buffer.writeln('  total:    '
      '${_fmt(DictionaryResourceCleanup.directorySize(dataRoot))}');
  buffer.writeln();

  // Top-level directory breakdown.
  buffer.writeln('Top-level directories:');
  if (dataRoot.existsSync()) {
    final entries = <MapEntry<String, int>>[];
    for (final entity in dataRoot.listSync(followLinks: false)) {
      if (entity is Directory) {
        final name = path.basename(entity.path);
        final size = DictionaryResourceCleanup.directorySize(entity);
        entries.add(MapEntry(name, size));
      } else if (entity is File) {
        try {
          entries.add(MapEntry(path.basename(entity.path), entity.lengthSync()));
        } catch (_) {}
      }
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries) {
      buffer.writeln('  ${_pad(_fmt(e.value), 10)}  ${e.key}');
    }
  } else {
    buffer.writeln('  (not found)');
  }
  buffer.writeln();

  // Isar database file.
  buffer.writeln('Isar database:');
  if (dbDir.existsSync()) {
    final files = dbDir.listSync(followLinks: false).whereType<File>();
    var found = false;
    for (final f in files) {
      final name = path.basename(f.path);
      if (name.endsWith('.isar') || name.endsWith('.isar.lock')) {
        found = true;
        try {
          buffer.writeln(
              '  ${_pad(_fmt(f.lengthSync()), 10)}  $name');
        } catch (_) {}
      }
    }
    if (!found) buffer.writeln('  (no .isar files found)');
  } else {
    buffer.writeln('  (not found)');
  }
  buffer.writeln();

  // Per-dictionary resource directory breakdown.
  buffer.writeln('Dictionary resource directories:');
  if (dictResources.existsSync()) {
    final entries = <MapEntry<String, int>>[];
    int bankBytes = 0;
    int otherBytes = 0;
    for (final entity in dictResources.listSync(followLinks: false)) {
      if (entity is! Directory) continue;
      int dirBank = 0;
      int dirOther = 0;
      try {
        for (final child
            in entity.listSync(recursive: true, followLinks: false)) {
          if (child is! File) continue;
          final size = child.lengthSync();
          final name = path.basename(child.path);
          if (DictionaryResourceCleanup.isBankFile(name)) {
            dirBank += size;
          } else {
            dirOther += size;
          }
        }
      } catch (_) {}
      bankBytes += dirBank;
      otherBytes += dirOther;
      entries.add(
          MapEntry(path.basename(entity.path), dirBank + dirOther));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));
    for (final e in entries) {
      buffer.writeln('  ${_pad(_fmt(e.value), 10)}  ${e.key}');
    }
    buffer.writeln('  --------');
    buffer.writeln(
        '  ${_pad(_fmt(bankBytes), 10)}  reclaimable bank JSONs');
    buffer.writeln(
        '  ${_pad(_fmt(otherBytes), 10)}  retained assets (images, css, etc.)');
  } else {
    buffer.writeln('  (no dictionaries imported)');
  }
  buffer.writeln();

  // App documents directory total (Hive, etc.).
  buffer.writeln('App documents directory:');
  buffer.writeln('  total:    '
      '${_fmt(DictionaryResourceCleanup.directorySize(appDir))}');

  return buffer.toString();
}

String _fmt(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _pad(String s, int width) {
  if (s.length >= width) return s;
  return s + ' ' * (width - s.length);
}
