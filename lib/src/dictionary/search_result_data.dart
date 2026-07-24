import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';

/// Plain-data structures returned by language-specific search workers
/// across the `compute()` isolate boundary.
///
/// In contrast to the previous design — which persisted a
/// `DictionarySearchResult` row in Isar and returned its primary key —
/// search results are now ephemeral. The worker isolate runs queries,
/// groups entries by `(term, reading)`, returns this object directly, and
/// the main isolate then loads the actual entry rows by id, decodes their
/// definitions, and hands the assembled view-model to the UI.
///
/// All fields here are types that survive the structured-clone-equivalent
/// serialisation Dart performs when crossing isolate boundaries (`int`,
/// `String`, `List`, `Map`).
class SearchResultData {
  /// Construct a result.
  SearchResultData({
    required this.searchTerm,
    required this.bestLength,
    required this.groups,
  });

  /// The original search term (post-normalisation by the language worker).
  final String searchTerm;

  /// Length of the longest prefix of [searchTerm] that produced any
  /// matches. Used by the UI to highlight the matched portion of source
  /// text.
  final int bestLength;

  /// Groups of entries with the same `(term, reading)`, sorted by
  /// descending popularity sum.
  final List<EntryGroup> groups;

  /// Convenience: total number of entries across all groups.
  int get totalEntries =>
      groups.fold<int>(0, (sum, g) => sum + g.entryIds.length);

  /// Convenience: a flat list of all entry ids in display order. Used by
  /// `AppModel.searchDictionary` to batch-load entries with a single
  /// `getAllSync` call.
  List<int> get allEntryIds {
    final out = <int>[];
    for (final g in groups) {
      out.addAll(g.entryIds);
    }
    return out;
  }
}

/// One displayed heading in a search result — entries sharing a common
/// `(term, reading)` pair, possibly across multiple dictionaries.
class EntryGroup {
  /// Construct a group.
  EntryGroup({
    required this.term,
    required this.reading,
    required this.entryIds,
    required this.pitchIds,
    required this.frequencyIds,
  });

  /// The shared headword.
  final String term;

  /// The shared reading. Empty for languages that do not use distinct
  /// readings.
  final String reading;

  /// Primary keys of `DictionaryEntry` rows in this group, in dictionary
  /// display order.
  final List<int> entryIds;

  /// Primary keys of `DictionaryPitch` rows applicable to this `(term,
  /// reading)`, across all dictionaries that ship pitch data.
  final List<int> pitchIds;

  /// Primary keys of `DictionaryFrequency` rows applicable to this
  /// `(term, reading)`, across all dictionaries that ship frequency data.
  final List<int> frequencyIds;
}

/// Mutable accumulator used by language search functions to collect
/// entries from multiple query stages, group them by `(term, reading)`,
/// rank by popularity, and emit a finalised [SearchResultData].
///
/// Insertion order matters: when two groups have equal popularity sums,
/// the group inserted first wins. This lets language code prioritise
/// e.g. exact matches over starts-with matches by inserting them first.
class SearchResultBuilder {
  /// Construct a builder that will emit at most [maxGroups] groups.
  SearchResultBuilder({
    required this.searchTerm,
    required this.maxGroups,
  });

  /// The original search term passed through to the result.
  final String searchTerm;

  /// Maximum number of groups to retain in the final output.
  final int maxGroups;

  /// Tracks the longest matched prefix length seen so far.
  int bestLength = 0;

  /// Insertion order index — used to break ties when sorting by
  /// popularity sum.
  final Map<String, _GroupBuilder> _byKey = <String, _GroupBuilder>{};

  /// True if at least [maxGroups] distinct `(term, reading)` pairs have
  /// been added. Callers may use this to short-circuit further query
  /// stages.
  bool get isFull => _byKey.length >= maxGroups;

  /// Number of distinct groups currently held.
  int get groupCount => _byKey.length;

  /// Estimated remaining slot count — used to size the `limit()` parameter
  /// of follow-up queries.
  int remainingGroups() {
    final remaining = maxGroups - _byKey.length;
    return remaining < 0 ? 0 : remaining;
  }

  /// Add a single entry. Idempotent on `entry.id`.
  void addEntry(DictionaryEntry entry) {
    final key = '${entry.term}\u0001${entry.reading}';
    final builder = _byKey.putIfAbsent(
      key,
      () => _GroupBuilder(entry.term, entry.reading, _byKey.length),
    );
    builder.add(entry);
  }

  /// Add many entries at once.
  void addEntries(Iterable<DictionaryEntry> entries) {
    for (final entry in entries) {
      addEntry(entry);
    }
  }

  /// Update the best-matched prefix length seen.
  void recordMatchLength(int length) {
    if (length > bestLength) bestLength = length;
  }

  /// Sort, trim and resolve associated pitch/frequency rows. Returns null
  /// if no groups were added.
  SearchResultData? build(Isar database) {
    if (_byKey.isEmpty) return null;

    final sorted = _byKey.values.toList()
      ..sort((a, b) {
        final cmp = b.popularitySum.compareTo(a.popularitySum);
        if (cmp != 0) return cmp;
        // Tie-break by insertion order so that earlier-discovered groups
        // (typically more relevant matches) win.
        return a.insertionOrder.compareTo(b.insertionOrder);
      });

    final kept = sorted.length > maxGroups
        ? sorted.sublist(0, maxGroups)
        : sorted;

    final groups = <EntryGroup>[];
    for (final builder in kept) {
      // Pitches: same (term, reading). The query is indexed on term,
      // reading is filtered in Dart since reading is not separately
      // indexed on the pitch collection.
      final pitchIds = database.dictionaryPitchs
          .where()
          .termEqualTo(builder.term)
          .findAllSync()
          .where((p) => p.reading == builder.reading)
          .map((p) => p.id!)
          .toList();

      // Frequencies: same term, and either same reading or no reading
      // specified by the source dict.
      final frequencyIds = database.dictionaryFrequencys
          .where()
          .termEqualTo(builder.term)
          .findAllSync()
          .where(
              (f) => f.reading == builder.reading || f.reading.isEmpty)
          .map((f) => f.id!)
          .toList();

      groups.add(EntryGroup(
        term: builder.term,
        reading: builder.reading,
        entryIds: builder.entryIds,
        pitchIds: pitchIds,
        frequencyIds: frequencyIds,
      ));
    }

    return SearchResultData(
      searchTerm: searchTerm,
      bestLength: bestLength,
      groups: groups,
    );
  }

  /// Internal-use accessor: ordered list of the raw per-group
  /// accumulators. Used by language implementations (currently
  /// Japanese) that need to perform a custom post-sort before
  /// finalisation. Callers should not mutate the returned list.
  List<BuilderGroupData> rawGroups() {
    return _byKey.values
        .map((g) => BuilderGroupData(
              term: g.term,
              reading: g.reading,
              entryIds: g.entryIds,
              popularitySum: g.popularitySum,
              insertionOrder: g.insertionOrder,
            ))
        .toList();
  }

  /// Finalise the builder from an already-ordered list of
  /// [BuilderGroupData] (produced by [rawGroups] and sorted externally).
  /// Same as [build] except the caller picks the sort. Used by
  /// `prepareSearchResultsJapaneseLanguage` for its multi-criteria sort.
  SearchResultData? buildFromOrderedGroups(
    Isar database,
    List<BuilderGroupData> orderedGroups,
  ) {
    if (orderedGroups.isEmpty) return null;

    final kept = orderedGroups.length > maxGroups
        ? orderedGroups.sublist(0, maxGroups)
        : orderedGroups;

    final groups = <EntryGroup>[];
    for (final g in kept) {
      final pitchIds = database.dictionaryPitchs
          .where()
          .termEqualTo(g.term)
          .findAllSync()
          .where((p) => p.reading == g.reading)
          .map((p) => p.id!)
          .toList();

      final frequencyIds = database.dictionaryFrequencys
          .where()
          .termEqualTo(g.term)
          .findAllSync()
          .where((f) => f.reading == g.reading || f.reading.isEmpty)
          .map((f) => f.id!)
          .toList();

      groups.add(EntryGroup(
        term: g.term,
        reading: g.reading,
        entryIds: g.entryIds,
        pitchIds: pitchIds,
        frequencyIds: frequencyIds,
      ));
    }

    return SearchResultData(
      searchTerm: searchTerm,
      bestLength: bestLength,
      groups: groups,
    );
  }
}

/// Public snapshot of one group accumulator inside
/// [SearchResultBuilder], exposed for languages with bespoke post-sort
/// requirements (see `prepareSearchResultsJapaneseLanguage`).
class BuilderGroupData {
  BuilderGroupData({
    required this.term,
    required this.reading,
    required this.entryIds,
    required this.popularitySum,
    required this.insertionOrder,
  });

  final String term;
  final String reading;
  final List<int> entryIds;
  final double popularitySum;
  final int insertionOrder;
}

/// Internal: per-group accumulator inside [SearchResultBuilder].
class _GroupBuilder {
  _GroupBuilder(this.term, this.reading, this.insertionOrder);

  final String term;
  final String reading;
  final int insertionOrder;
  final List<int> entryIds = <int>[];
  final Set<int> _seenIds = <int>{};
  double popularitySum = 0;

  void add(DictionaryEntry entry) {
    final id = entry.id;
    if (id == null) return;
    if (_seenIds.add(id)) {
      entryIds.add(id);
      popularitySum += entry.popularity;
    }
  }
}
