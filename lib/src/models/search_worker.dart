import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/models.dart';

import 'package:shiroikumanojisho/src/models/in_memory_term_index.dart';

/// Zone key under which the worker stashes the current language's
/// [InMemoryTermIndex] (if one is built) for the duration of a
/// single search call. `runStandardLatinSearch` reads it via
/// `Zone.current[inMemoryTermIndexZoneKey]`; null means fall through
/// to the Isar-query slow path.
///
/// Zones carry values across async gaps within one logical flow but
/// are independent between concurrent flows, so two interleaved
/// requests for different languages don't step on each other the way
/// a module-level variable would.
const Object inMemoryTermIndexZoneKey = #shiroikumanojisho_in_memory_term_index;

/// Persistent search-worker isolate.
///
/// Historically every dictionary search spawned a fresh isolate via
/// `compute()`. That path paid two fixed costs on every tap: ~50-150
/// ms of isolate spawn + ~100-300 ms of `Isar.open` on the cold
/// isolate (Isar caches the opened instance per-isolate). With ten-
/// ish taps per reading paragraph that adds up quickly.
///
/// This module owns a long-lived isolate that stays open for the
/// session. Isar is effectively opened once (the second call to
/// [Isar.open] within the same isolate returns the cached instance);
/// the worker receives search requests via a [ReceivePort] and
/// dispatches to the per-language `prepareSearchResults` functions
/// exactly the way `compute()` did. Results and `[WORKER-PERF]`
/// instrumentation lines travel back to the main isolate via the
/// captured [SendPort].
///
/// Phase 2 (in-memory term index) layers on top of this module by
/// caching per-language term lookups in the worker isolate's heap.
/// This file stays search-function-agnostic in Phase 1 — it's pure
/// plumbing.

/// Initial message sent from the main isolate when spawning the
/// worker. Carries the reply port the worker will use for all future
/// outbound messages (responses, perf lines, etc), plus the
/// [RootIsolateToken] that's needed to wire up platform plugins in
/// the spawned isolate.
class SearchWorkerInit {
  SearchWorkerInit({
    required this.replyPort,
    required this.rootIsolateToken,
  });

  /// The main isolate's aggregate [SendPort]. All outbound messages
  /// from the worker — search responses AND `[WORKER-PERF]` strings —
  /// go through this single port.
  final SendPort replyPort;

  /// Required to call [BackgroundIsolateBinaryMessenger.ensureInitialized]
  /// inside the spawned isolate. Without this setup, any Flutter
  /// plugin-channel call from the worker silently fails — Flutter's
  /// own `compute()` does this for you but `Isolate.spawn()` does
  /// not.
  final RootIsolateToken rootIsolateToken;
}

/// A search request sent from main to worker. The [id] is a
/// correlation number: main picks it, worker echoes it in the
/// matching [SearchWorkerResponse] so multiple in-flight requests
/// can be distinguished.
///
/// [prepareFn] is the per-language `prepareSearchResults*` function
/// reference. These are all top-level functions so Dart's isolate
/// message layer accepts them as message payload.
///
/// [languageCode] identifies the language this search is for; it's
/// used as the cache key for the per-language in-memory term index
/// (Phase 2) so separate languages don't share a (wrong) index.
///
/// [buildInMemoryIndex] is true when the worker should maintain an
/// in-memory term index for this language (kick off a build if one
/// isn't ready, and expose a ready index to `runStandardLatinSearch`
/// via the zone value [inMemoryTermIndexZoneKey]). Set to false for
/// search paths that don't use the standard Latin code path —
/// Japanese, for example.
class SearchWorkerRequest {
  SearchWorkerRequest({
    required this.id,
    required this.languageCode,
    required this.buildInMemoryIndex,
    required this.prepareFn,
    required this.params,
  });

  final int id;
  final String languageCode;
  final bool buildInMemoryIndex;
  final Future<SearchResultData?> Function(DictionarySearchParams) prepareFn;
  final DictionarySearchParams params;
}

/// Response from worker to main. Exactly one is sent per
/// [SearchWorkerRequest], identified by the matching [id].
///
/// [result] is null if the search returned no data (terminal empty
/// queries, etc). If the search threw, [error] carries the
/// stringified exception and [result] is null.
class SearchWorkerResponse {
  SearchWorkerResponse({
    required this.id,
    this.result,
    this.error,
  });

  final int id;
  final SearchResultData? result;
  final String? error;
}

/// Top-level worker entry point. Opens a [ReceivePort], sends its
/// [SendPort] back to main through the init reply port, then loops
/// on incoming messages until the isolate is killed.
///
/// The main isolate should:
///   1. Spawn this function via `Isolate.spawn<SearchWorkerInit>(
///      searchWorkerEntry, SearchWorkerInit(replyPort: myPort))`.
///   2. Wait on its own [ReceivePort] for the first message, which
///      will be the worker's [SendPort]. That's the handle for
///      submitting requests.
///   3. Send [SearchWorkerRequest]s. Await corresponding
///      [SearchWorkerResponse]s by id.
void searchWorkerEntry(SearchWorkerInit init) {
  // Bring the spawned isolate up to the same level of Flutter-
  // awareness as an isolate launched via `compute()`:
  //
  //   1. DartPluginRegistrant.ensureInitialized() registers the
  //      Dart-side of any plugins that rely on it (some plugins use
  //      annotations processed by the plugin registrar to inject
  //      setup code into spawned isolates).
  //   2. BackgroundIsolateBinaryMessenger.ensureInitialized(token)
  //      installs a platform-channel messenger so MethodChannel-
  //      based plugin calls from this isolate go to the host.
  //
  // Without these, any plugin-mediated call from the worker — or
  // anything transitively triggered by loading libraries that touch
  // plugins at init — silently throws. Isar itself is FFI-only and
  // doesn't need either, but imports that reach into the
  // shiroikumanojisho codebase may pull in code that does, and
  // matching compute()'s setup exactly removes a whole class of
  // "why is this broken" failure modes.
  DartPluginRegistrant.ensureInitialized();
  BackgroundIsolateBinaryMessenger.ensureInitialized(
      init.rootIsolateToken);

  final receivePort = ReceivePort();
  init.replyPort.send(receivePort.sendPort);

  // Per-language in-memory term indexes. Populated lazily on the
  // first search in a language; subsequent searches read from the
  // map and skip the Isar-query stage-1. Memory is roughly 13 MB per
  // ~500k-term language; see InMemoryTermIndex for the breakdown.
  final Map<String, InMemoryTermIndex> indexes = {};

  // In-progress index builds, keyed by language code. A build Future
  // lives here until it settles, at which point it moves to
  // `indexes` (success) or is removed (error).
  final Map<String, Future<void>> indexBuilds = {};

  receivePort.listen((dynamic message) async {
    if (message is SearchWorkerRequest) {
      // Rewire the params' sendPort to the persistent reply port
      // before invoking the search function. The search functions
      // use `params.send(...)` for `[WORKER-PERF]` lines, and those
      // need to go to the main isolate's aggregate receivePort —
      // not to the per-request port that the old compute() model
      // created and tore down around every search.
      //
      // DictionarySearchParams fields are final, so we build a
      // fresh instance here. Cheap — handful of primitives plus a
      // small List<int> reference (not copied, shared).
      final params = DictionarySearchParams(
        searchTerm: message.params.searchTerm,
        maximumDictionarySearchResults:
            message.params.maximumDictionarySearchResults,
        maximumDictionaryTermsInResult:
            message.params.maximumDictionaryTermsInResult,
        enabledDictionaryIds: message.params.enabledDictionaryIds,
        searchWithWildcards: message.params.searchWithWildcards,
        sendPort: init.replyPort,
        directoryPath: message.params.directoryPath,
      );

      // Index lifecycle (Phase 2).
      //
      // If this language should have an index and one isn't built or
      // building, kick off a background build now. We don't await it
      // — the current search falls through to the slow r3 path via a
      // null zone value, and subsequent searches will pick up the
      // index when it's ready. Future completion writes to
      // `indexes[langCode]` in the same isolate so no locking is
      // needed.
      final String langCode = message.languageCode;
      if (message.buildInMemoryIndex &&
          !indexes.containsKey(langCode) &&
          !indexBuilds.containsKey(langCode)) {
        indexBuilds[langCode] = _buildIndexInBackground(
          langCode: langCode,
          directoryPath: message.params.directoryPath,
          scopedDictIds: message.params.enabledDictionaryIds,
          replyPort: init.replyPort,
        ).then((built) {
          if (built != null) {
            indexes[langCode] = built;
          }
          indexBuilds.remove(langCode);
        });
      }

      final InMemoryTermIndex? activeIndex = indexes[langCode];

      try {
        // Zone wrapper exposes the index (or null) to the search
        // function for the duration of this call. Using Zone rather
        // than a module-level variable keeps concurrent searches for
        // different languages from seeing the wrong value.
        final SearchResultData? result = await runZoned(
          () => message.prepareFn(params),
          zoneValues: <Object?, Object?>{
            inMemoryTermIndexZoneKey: activeIndex,
          },
        );
        init.replyPort.send(SearchWorkerResponse(
          id: message.id,
          result: result,
        ));
      } catch (e, st) {
        // Diagnostic [WORKER-ERROR] emit disabled for release — the
        // actual error still propagates to the caller via the
        // SearchWorkerResponse.error field below, so search failures
        // surface at the call site either way. Re-enable this block
        // together with the perf logging in AppModel to get errors
        // interleaved with the `[SEARCH-PERF]` timeline.
        /*
        try {
          init.replyPort.send(
              '[WORKER-ERROR] id=${message.id} error=$e\n$st');
        } catch (_) {}
        */
        init.replyPort.send(SearchWorkerResponse(
          id: message.id,
          error: '$e\n$st',
        ));
      }
    } else if (message == 'shutdown') {
      receivePort.close();
      Isolate.current.kill();
    }
  });
}

/// Build the in-memory term index for one language. Runs in the
/// worker isolate. Returns null on failure (error is logged through
/// [replyPort] as a `[WORKER-INDEX-ERROR]` line).
///
/// Yields to the event loop between per-dict queries so incoming
/// search messages aren't starved for the full duration of the
/// build (2-5 seconds typically).
Future<InMemoryTermIndex?> _buildIndexInBackground({
  required String langCode,
  required String directoryPath,
  required List<int> scopedDictIds,
  required SendPort replyPort,
}) async {
  if (scopedDictIds.isEmpty) {
    return null;
  }
  final sw = Stopwatch()..start();

  try {
    final isar = Isar.getInstance() ??
        await Isar.open(
          globalSchemas,
          directory: directoryPath,
          maxSizeMiB: 8192,
        );

    // Total row count up front — used by the UI overlay as the
    // denominator of the "N / M" progress readout. Each per-dict
    // countSync is essentially free (reads the index length, doesn't
    // walk rows) so the one-time pre-pass is fine even for large
    // corpora.
    int totalEntries = 0;
    for (final dictId in scopedDictIds) {
      totalEntries += isar.dictionaryEntrys
          .where()
          .dictionaryIdEqualTo(dictId)
          .countSync();
    }
    try {
      replyPort.send('[WORKER-INDEX-PROGRESS] '
          'lang=$langCode processed=0 total=$totalEntries');
    } catch (_) {}

    // Collect (term, entryId, dictId) across all scoped dicts. Two
    // property queries per dict — one for terms, one for ids — so we
    // don't pay to hydrate full rows (the `compressedDefinitions`
    // blob alone would explode memory at this scale). Isar returns
    // both queries in index order for the same where clause, so the
    // parallel lists line up by index.
    final allTerms = <String>[];
    final allEntryIds = <int>[];
    final allDictIds = <int>[];

    // Progress reporting — emit at the end of every chunk. A stride
    // gate (e.g. every 50k rows) would mean fewer messages but in
    // testing it produced a stuttery overlay that occasionally read
    // as "stuck" on very large languages; emitting per chunk adds
    // negligible cost (~150 messages across a 70s German build,
    // one every ~400 ms) and keeps the counter visibly alive.
    int lastReportedAt = 0;

    // Chunk size for paginated property queries. At 20k terms per
    // chunk, each chunk's `findAllSync` takes roughly 200-400 ms on
    // large dicts — small enough that a search message tapped during
    // the build waits at most a few hundred ms for the next yield
    // point, large enough that the total number of queries stays
    // manageable (a 3M-term language needs ~150 chunks per property
    // × 10 dicts).
    const int kBuildChunkSize = 20000;

    for (final dictId in scopedDictIds) {
      int offset = 0;
      while (true) {
        // Yield before each chunk so an in-flight search request can
        // grab the isolate between blocking Isar calls. Otherwise a
        // single findAllSync on a huge dict stalls the worker for
        // multiple seconds.
        await Future<void>.delayed(Duration.zero);

        final List<String?> terms = isar.dictionaryEntrys
            .where()
            .dictionaryIdEqualTo(dictId)
            .offset(offset)
            .limit(kBuildChunkSize)
            .termProperty()
            .findAllSync();
        if (terms.isEmpty) break;

        await Future<void>.delayed(Duration.zero);

        final List<int?> ids = isar.dictionaryEntrys
            .where()
            .dictionaryIdEqualTo(dictId)
            .offset(offset)
            .limit(kBuildChunkSize)
            .idProperty()
            .findAllSync();

        // Same where + same offset + same limit → Isar walks the
        // index the same way, so the chunks line up by position. Any
        // mismatch would be a bug in our assumptions; surface it.
        if (terms.length != ids.length) {
          throw StateError(
              'term/id parallel-query length mismatch in dict $dictId '
              'at offset $offset: terms=${terms.length} ids=${ids.length}');
        }

        for (int i = 0; i < terms.length; i++) {
          final t = terms[i];
          final id = ids[i];
          if (t == null || id == null) continue;
          allTerms.add(t.toLowerCase());
          allEntryIds.add(id);
          allDictIds.add(dictId);
        }

        offset += terms.length;

        // Emit progress at the end of every chunk. Stride-gated
        // emits were tried but made the overlay feel frozen on very
        // large languages; emitting per chunk is cheap and keeps
        // the UI moving visibly.
        try {
          replyPort.send('[WORKER-INDEX-PROGRESS] '
              'lang=$langCode processed=${allTerms.length} '
              'total=$totalEntries');
        } catch (_) {}
        lastReportedAt = allTerms.length;

        // Short chunk → no more rows.
        if (terms.length < kBuildChunkSize) break;
      }
    }

    final int n = allTerms.length;

    // Sort by term using indirect indices so we don't shuffle three
    // parallel lists in place. One allocation of an Int32List for
    // the permutation, then a single pass to pack the packed arrays.
    // The sort itself is unavoidably a synchronous stall — Dart's
    // List.sort has no yield hook. For a 3M-entry language (German)
    // that's in the 3-10 s range on mid-range Android; for ~500k
    // (Polish, Russian) it's well under a second.
    await Future<void>.delayed(Duration.zero);
    final permutation = List<int>.generate(n, (i) => i, growable: false);
    permutation.sort((a, b) => allTerms[a].compareTo(allTerms[b]));

    // Pack. Two O(n) loops below; yield every kYieldStride iterations
    // so a search request tapped during build isn't blocked for the
    // entire pack phase on a very-large-n language. 50k iterations
    // takes a couple of tens of ms, a tolerable slice.
    const int kYieldStride = 50000;

    await Future<void>.delayed(Duration.zero);
    int totalBytes = 0;
    final encodedTerms = List<Uint8List>.filled(
      n,
      Uint8List(0),
    );
    for (int i = 0; i < n; i++) {
      if (i > 0 && i % kYieldStride == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final bytes =
          Uint8List.fromList(utf8.encode(allTerms[permutation[i]]));
      encodedTerms[i] = bytes;
      totalBytes += bytes.length;
    }

    final termBytes = Uint8List(totalBytes);
    final termOffsets = Uint32List(n + 1);
    final entryIds = Int64List(n);
    final dictIds = Int32List(n);

    await Future<void>.delayed(Duration.zero);
    int cursor = 0;
    for (int i = 0; i < n; i++) {
      if (i > 0 && i % kYieldStride == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      final origIdx = permutation[i];
      entryIds[i] = allEntryIds[origIdx];
      dictIds[i] = allDictIds[origIdx];
      termOffsets[i] = cursor;
      final bytes = encodedTerms[i];
      termBytes.setRange(cursor, cursor + bytes.length, bytes);
      cursor += bytes.length;
    }
    termOffsets[n] = totalBytes;

    final index = InMemoryTermIndex(
      termBytes: termBytes,
      termOffsets: termOffsets,
      entryIds: entryIds,
      dictIds: dictIds,
    );

    try {
      replyPort.send('[WORKER-INDEX-BUILD] '
          'lang=$langCode dicts=${scopedDictIds.length} '
          'terms=$n buildMs=${sw.elapsedMilliseconds} '
          'termBytes=$totalBytes');
    } catch (_) {}

    return index;
  } catch (e, st) {
    try {
      replyPort.send('[WORKER-INDEX-ERROR] '
          'lang=$langCode error=$e\n$st');
    } catch (_) {}
    return null;
  }
}
