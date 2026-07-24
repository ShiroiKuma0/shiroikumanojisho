import 'dart:async';

import 'package:collection/collection.dart';
import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/src/language/language_utils.dart';

import '../models/in_memory_term_index.dart';
import '../models/search_worker.dart';

/// Shared search helpers used by multiple language implementations to
/// avoid duplicating the same query orchestration. Each helper opens
/// Isar, runs queries, populates a [SearchResultBuilder], and returns
/// the assembled [SearchResultData].
///
/// Languages that need extra preprocessing (Russian's ё/е normalisation,
/// English's contraction expansion + lemmatisation, Japanese's elaborate
/// deinflection chain) implement their own search functions but reuse
/// the same [SearchResultBuilder] pattern so the post-processing stays
/// uniform.

/// Minimum prefix length at which we issue a `startsWith` query.
///
/// Shorter prefixes produce huge, low-relevance result sets that flood
/// the builder before the actual long-prefix matches get a chance. 5
/// is a reasonable midpoint for Latin-script European languages:
/// shorter than the average lemma length (~6-8) but long enough to
/// meaningfully narrow the index walk.
const int _kStartsWithMinPrefixLen = 5;

/// Standard Latin-script language search.
///
/// Algorithm (v3 schema, language-scoped via filter + bloom skip-gate):
///   1. Normalise to lower-case.
///   2. Split on `[ -]`, then for the first word split character-by-
///      character to produce progressively-shorter prefixes.
///   3. Language scoping: `params.enabledDictionaryIds` carries the
///      set of dict ids whose `primaryLanguage` matches the session's
///      current language. This set is applied as a filter on every
///      index query so results never include other languages'
///      entries.
///   4. For each prefix, longest-first:
///      a. Exact-match phase: bloom skip-gate first — if no dict in
///         the language set could contain this term, skip the Isar
///         call entirely. Otherwise issue a single flat-index query
///         `where().termEqualTo(variant).filter().anyOf(ids, ...)`.
///      b. Starts-with phase: only for prefixes of length ≥
///         [_kStartsWithMinPrefixLen]. Same flat-index + filter
///         pattern. Bloom filters don't help here (exact-membership).
///   5. Short-circuit the whole thing whenever the builder reports
///      `remainingGroups() <= 0`.
///
/// [extraTermVariants], if provided, is called for each candidate
/// prefix and may return additional spellings to query (e.g. Russian's
/// ё→е folding). Each returned variant is queried independently and
/// all matching entries are added to the builder.
///
/// At the end we send one `[WORKER-PERF]` summary line via
/// [params.sendPort]. The caller listens for these and routes them
/// through the main-isolate perf log sink for correlation with
/// `[SEARCH-PERF]` lines.
Future<SearchResultData?> runStandardLatinSearch(
  DictionarySearchParams params, {
  List<String> Function(String prefix)? extraTermVariants,
}) async {
  final perfSw = Stopwatch()..start();

  // Reuse the isolate's existing Isar handle if one is already
  // cached (persistent-worker isolate, second and subsequent calls).
  // Fall through to Isar.open the first time only. Calling
  // Isar.open a second time in the same isolate throws
  // "Instance has already been opened" — the fresh-compute() world
  // masked this because each compute() was a brand-new isolate with
  // an empty Isar cache.
  final database = Isar.getInstance() ??
      await Isar.open(
        globalSchemas,
        directory: params.directoryPath,
        maxSizeMiB: 8192,
      );

  String searchTerm = params.searchTerm.toLowerCase().trim();
  if (searchTerm.isEmpty) return null;

  final maxGroups = params.maximumDictionaryTermsInResult;
  final builder =
      SearchResultBuilder(searchTerm: searchTerm, maxGroups: maxGroups);

  // Each group can have multiple entries (from multiple dicts); over-
  // fetch entries so we have enough material to fill every group slot
  // even when many entries share a (term, reading).
  int entryFetchLimit() {
    final remaining = builder.remainingGroups();
    if (remaining <= 0) return 0;
    return remaining * 8;
  }

  final shouldSearchWildcards = params.searchWithWildcards &&
      (searchTerm.contains('*') || searchTerm.contains('?'));

  // Perf counters, reported at end.
  int perfIsarCalls = 0;
  int perfBloomSkips = 0;
  int perfPrefixCount = 0;
  int perfScopedDictCount = 0;
  int perfStage2LoadCount = 0;
  bool perfFastPath = false;

  if (shouldSearchWildcards) {
    // Wildcard path: global (un-scoped) query against the standalone
    // term index. Unchanged by A2 because `termMatches` is a filter,
    // not an index walk, and is uncommon in practice.
    final noExactMatches = database.dictionaryEntrys
        .where()
        .termEqualTo(searchTerm)
        .isEmptySync();

    if (noExactMatches) {
      final matchesTerm = searchTerm;
      final questionMarkOnly = !matchesTerm.contains('*');
      final noAsterisks = searchTerm.replaceAll('*', '').replaceAll('?', '');

      final lim = entryFetchLimit();
      if (lim > 0) {
        List<DictionaryEntry> entries;
        if (questionMarkOnly) {
          entries = database.dictionaryEntrys
              .where()
              .termLengthEqualTo(searchTerm.length)
              .filter()
              .termMatches(matchesTerm, caseSensitive: false)
              .limit(lim)
              .findAllSync();
        } else {
          entries = database.dictionaryEntrys
              .where()
              .termLengthGreaterThan(noAsterisks.length, include: true)
              .filter()
              .termMatches(matchesTerm, caseSensitive: false)
              .limit(lim)
              .findAllSync();
        }
        builder.addEntries(entries);
        if (entries.isNotEmpty) builder.recordMatchLength(searchTerm.length);
      }
    }
  } else {
    // === Language-scoped per-dict search ===

    // 1. Determine the set of dicts to query.
    //
    // The caller (AppModel) populates `enabledDictionaryIds` with the
    // language-scoped id list. If empty, the user has no dictionaries
    // for the current language — return nothing rather than falling
    // back to an all-dicts query (that would reintroduce the exact
    // cross-language contamination this scoping was meant to fix,
    // because Isar's `anyOf([], ...)` accepts every row).
    final List<int> scopedDictIds = params.enabledDictionaryIds;
    if (scopedDictIds.isEmpty) {
      // Perf emit disabled for release. Re-enable (and the matching
      // [WORKER-PERF] branch in AppModel._onSearchWorkerMessage) to
      // collect timing data. Preserved as dormant source so we don't
      // have to re-derive the shape of the perf line next time.
      /*
      final workerMs = perfSw.elapsedMilliseconds;
      try {
        params.send('[WORKER-PERF] term="${params.searchTerm}" '
            'worker=${workerMs}ms scopedDicts=0 prefixes=0 '
            'isarCalls=0 bloomSkips=0 skipped=empty-scope');
      } catch (_) {}
      */
      return null;
    }
    perfScopedDictCount = scopedDictIds.length;

    // 2. Load the scoped dicts in one Isar call and eagerly build
    // bloom filters where available. Filter construction is cheap
    // (~1μs per dict — the bytes are already in memory after the
    // dictionary row loaded). Dicts imported under schema v2 or
    // earlier have empty `bloomBits` and get a `null` bloom, which
    // the lookup below treats as "no filter; always query".
    final List<Dictionary> scopedDicts = database.dictionarys
        .getAllSync(scopedDictIds)
        .whereType<Dictionary>()
        .toList();
    final Map<int, TermBloom?> blooms = <int, TermBloom?>{};
    for (final d in scopedDicts) {
      if (d.bloomBits.isNotEmpty) {
        blooms[d.id] = TermBloom.fromBytes(d.bloomBits);
      } else {
        blooms[d.id] = null;
      }
    }

    // 3. Build the candidate prefix list, longest-first by construction.
    List<String> segments = searchTerm.splitWithDelim(RegExp('[ -]'));
    if (segments.length > 20) segments = segments.sublist(0, 10);

    final firstWord = segments.removeAt(0);
    segments = [
      if (firstWord.length >= 3) ...firstWord.split('') else firstWord,
    ];

    final prefixes = <String>[];
    for (int i = 0; i < segments.length; i++) {
      final partialTerm = segments.sublist(0, segments.length - i).join();
      if (partialTerm.isEmpty) continue;
      if (partialTerm.endsWith(' ')) continue;
      prefixes.add(partialTerm);
    }
    perfPrefixCount = prefixes.length;

    // === FAST PATH (Phase 2) ===
    //
    // If the worker has finished building the in-memory term index
    // for this language, the search-worker module stashes it in the
    // current Zone under [inMemoryTermIndexZoneKey]. A non-null
    // reading means we can skip every Isar `termEqualTo` /
    // `termStartsWith` call in stage 1 and do the same lookups over a
    // sorted byte-packed array — binary search vs B-tree walk, plus
    // zero per-call Isar fixed overhead.
    //
    // Stage 2 (bulk hydrate via `getAllSync`) and stage 3 (builder
    // feed) are exactly the same as the slow path — only the id-
    // discovery changes.
    //
    // The zone value is null whenever:
    //   - Phase 2 is disabled for this language (worker request had
    //     buildInMemoryIndex: false, e.g. Japanese).
    //   - The index build is still in progress for this language
    //     (first search or two in a new language).
    //   - The build failed (an `[WORKER-INDEX-ERROR]` line will have
    //     been emitted).
    // In any of those cases we fall through to the r3 slow path
    // below and the user still gets a result.
    final InMemoryTermIndex? memIndex =
        Zone.current[inMemoryTermIndexZoneKey] as InMemoryTermIndex?;

    if (memIndex != null) {
      const int kFastPathPerCallIdLimit = 32;
      final int kFastPathMaxCollectedIds = maxGroups * 16;

      final Map<int, List<int>> exactIdsByLength = <int, List<int>>{};
      final Map<int, List<int>> startsWithIdsByLength =
          <int, List<int>>{};
      int collectedIdCount = 0;

      // Stage 1a — exact id discovery.
      exactPhase:
      for (final prefix in prefixes) {
        if (collectedIdCount >= kFastPathMaxCollectedIds) break exactPhase;
        final variants = extraTermVariants != null
            ? extraTermVariants(prefix)
            : <String>[prefix];
        for (final variant in variants) {
          if (collectedIdCount >= kFastPathMaxCollectedIds) {
            break exactPhase;
          }
          final ids = memIndex.findExact(variant);
          if (ids.isNotEmpty) {
            final bucket = exactIdsByLength[prefix.length] ??= <int>[];
            bucket.addAll(ids);
            collectedIdCount += ids.length;
          }
        }
      }

      // Stage 1b — starts-with id discovery (prefixes above the
      // threshold only).
      startsWithPhase:
      for (final prefix in prefixes) {
        if (collectedIdCount >= kFastPathMaxCollectedIds) {
          break startsWithPhase;
        }
        if (prefix.length < _kStartsWithMinPrefixLen) continue;
        final variants = extraTermVariants != null
            ? extraTermVariants(prefix)
            : <String>[prefix];
        for (final variant in variants) {
          if (collectedIdCount >= kFastPathMaxCollectedIds) {
            break startsWithPhase;
          }
          final ids = memIndex.findStartsWith(
            variant,
            limit: kFastPathPerCallIdLimit,
          );
          if (ids.isNotEmpty) {
            final bucket = startsWithIdsByLength[prefix.length] ??= <int>[];
            bucket.addAll(ids);
            collectedIdCount += ids.length;
          }
        }
      }

      // Stage 2 — bulk hydrate unique ids via Isar.
      final Set<int> uniqueIds = <int>{};
      for (final ids in exactIdsByLength.values) {
        uniqueIds.addAll(ids);
      }
      for (final ids in startsWithIdsByLength.values) {
        uniqueIds.addAll(ids);
      }
      perfStage2LoadCount = uniqueIds.length;

      final Map<int, DictionaryEntry> entriesById =
          <int, DictionaryEntry>{};
      if (uniqueIds.isNotEmpty) {
        final loaded =
            database.dictionaryEntrys.getAllSync(uniqueIds.toList());
        for (final e in loaded) {
          if (e != null && e.id != null) {
            entriesById[e.id!] = e;
          }
        }
      }

      // Stage 3 — feed builder in priority order.
      for (int length = searchTerm.length; length > 0; length--) {
        if (builder.remainingGroups() <= 0) break;
        final ids = exactIdsByLength[length];
        if (ids == null) continue;
        final bucket = <DictionaryEntry>[];
        for (final id in ids) {
          final e = entriesById[id];
          if (e != null) bucket.add(e);
        }
        if (bucket.isNotEmpty) {
          builder.addEntries(bucket);
          builder.recordMatchLength(length);
        }
      }
      for (int length = searchTerm.length; length > 0; length--) {
        if (builder.remainingGroups() <= 0) break;
        final ids = startsWithIdsByLength[length];
        if (ids == null) continue;
        final bucket = <DictionaryEntry>[];
        for (final id in ids) {
          final e = entriesById[id];
          if (e != null) bucket.add(e);
        }
        if (bucket.isNotEmpty) {
          builder.addEntries(bucket);
          builder.recordMatchLength(length);
        }
      }

      perfFastPath = true;
      // Skip the slow-path block below entirely.
    } else {

    // 4. Exact-match phase — longest prefix first. One Isar call per
    // prefix variant against the flat `term` index, with a post-index
    // filter that restricts results to the language's dict id set.
    // Earlier revisions of this code iterated per-dict using the
    // composite `(dictionaryId, term)` index; that approach multiplied
    // the call count (one per dict per prefix) while giving no per-
    // call speedup — composite and flat seeks are both O(log N) on
    // Isar's B-tree, and the flat index's disk pages are hotter after
    // repeated use. A single flat-index query with dict filter is
    // strictly cheaper for our workload.
    //
    // Bloom filters are used as a *skip-gate*: if NO language-scoped
    // dict can possibly contain the term, the Isar call is elided. For
    // rare terms across a large dict set this saves real time; for
    // common terms it costs one bitmap check per dict and we proceed
    // with the query.
    exactPhase:
    for (final prefix in prefixes) {
      if (entryFetchLimit() <= 0) break exactPhase;

      final variants = extraTermVariants != null
          ? extraTermVariants(prefix)
          : <String>[prefix];

      final prefixExact = <DictionaryEntry>[];
      for (final variant in variants) {
        if (entryFetchLimit() <= 0) break exactPhase;

        // Bloom skip-gate. If every dict's bloom says "definitely
        // not present", skip the Isar call entirely.
        bool anyBloomHit = false;
        for (final dictId in scopedDictIds) {
          final bloom = blooms[dictId];
          // null bloom = pre-A1 dict, no filter available, assume hit.
          if (bloom == null || bloom.mayContain(variant)) {
            anyBloomHit = true;
            break;
          }
        }
        if (!anyBloomHit) {
          perfBloomSkips++;
          continue;
        }

        perfIsarCalls++;
        final hits = database.dictionaryEntrys
            .where()
            .termEqualTo(variant)
            .filter()
            .anyOf(scopedDictIds, (q, id) => q.dictionaryIdEqualTo(id))
            .limit(entryFetchLimit())
            .findAllSync();
        prefixExact.addAll(hits);
      }

      if (prefixExact.isNotEmpty) {
        builder.addEntries(prefixExact);
        builder.recordMatchLength(prefix.length);
      }
    }

    // 5. Starts-with phase — longest prefix first, skipping prefixes
    // below [_kStartsWithMinPrefixLen]. One flat-index call per prefix
    // variant, filtered to the language's dict set. Bloom filters are
    // *not* useful here — they answer exact-membership questions, not
    // prefix-existence.
    startsWithPhase:
    for (final prefix in prefixes) {
      if (entryFetchLimit() <= 0) break startsWithPhase;
      if (prefix.length < _kStartsWithMinPrefixLen) continue;

      final variants = extraTermVariants != null
          ? extraTermVariants(prefix)
          : <String>[prefix];

      final prefixStarts = <DictionaryEntry>[];
      for (final variant in variants) {
        if (entryFetchLimit() <= 0) break startsWithPhase;

        perfIsarCalls++;
        final hits = database.dictionaryEntrys
            .where()
            .termStartsWith(variant)
            .filter()
            .anyOf(scopedDictIds, (q, id) => q.dictionaryIdEqualTo(id))
            .sortByTermLength()
            .limit(entryFetchLimit())
            .findAllSync();
        prefixStarts.addAll(hits);
      }

      if (prefixStarts.isNotEmpty) {
        builder.addEntries(prefixStarts);
        builder.recordMatchLength(prefix.length);
      }
    }
    } // end else (slow path)
  }

  // 6. Worker-side instrumentation summary. Disabled for release —
  // re-enable (and the matching [WORKER-PERF] branch in
  // AppModel._onSearchWorkerMessage) to collect timing data.
  // Preserved as dormant source so the line shape + counter set
  // don't have to be re-derived when we need them next.
  /*
  final workerMs = perfSw.elapsedMilliseconds;
  try {
    params.send('[WORKER-PERF] term="${params.searchTerm}" '
        'worker=${workerMs}ms '
        'scopedDicts=$perfScopedDictCount '
        'prefixes=$perfPrefixCount '
        'isarCalls=$perfIsarCalls '
        'bloomSkips=$perfBloomSkips '
        'stage2Load=$perfStage2LoadCount '
        'fastPath=$perfFastPath');
  } catch (_) {
    // sendPort closed or otherwise unavailable — nothing to do.
  }
  */

  return builder.build(database);
}
