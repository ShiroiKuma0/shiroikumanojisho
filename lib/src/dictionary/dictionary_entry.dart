import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';

part 'dictionary_entry.g.dart';

/// A flat, self-contained dictionary entry — a single Yomichan term-bank
/// row.
///
/// In contrast to earlier schema versions, entries are no longer joined to
/// shared `DictionaryHeading` rows via `IsarLinks`. The [term], [reading],
/// [dictionaryId] and tag fields live directly on the entry. Headings are
/// reconstructed at query time by grouping entries with equal `(term,
/// reading)`.
///
/// Definitions are stored in [compressedDefinitions] as zstd-compressed
/// bytes (see [DefinitionCodec]). The decoded form is populated lazily into
/// the transient [decodedDefinitionsCache] field by the search post-
/// processing step in `AppModel.searchDictionary`. The [decodedDefinitions]
/// getter throws if the cache has not been populated, which intentionally
/// converts "I forgot to await decode before render" from a silent
/// rendering bug into a loud crash.
@Collection()
class DictionaryEntry {
  /// Construct an entry. The [compressedDefinitions] payload should already
  /// have been produced by [DefinitionCodec.encode] before calling.
  DictionaryEntry({
    required this.term,
    required this.reading,
    required this.dictionaryId,
    required this.popularity,
    required this.compressedDefinitions,
    this.entryTagsRaw = '',
    this.headingTagsRaw = '',
    this.imagePaths,
    this.audioPaths,
    this.id,
  });

  /// Identifier for database purposes.
  Id? id;

  /// The headword. Indexed for search; case-insensitive.
  @Index(type: IndexType.value, caseSensitive: false)
  final String term;

  /// The reading (alternate form). For languages without distinct readings
  /// (e.g. English, German) this typically equals [term] or is empty.
  /// Indexed for search; case-insensitive.
  @Index(type: IndexType.value, caseSensitive: false)
  final String reading;

  /// Length of [term]. Indexed so prefix-based search can short-circuit
  /// candidate sets.
  @Index()
  int get termLength => term.length;

  /// Foreign-key-style reference to the parent [Dictionary] row's id.
  ///
  /// Indexed two ways. The standalone `@Index()` keeps
  /// `.dictionaryIdEqualTo()` available — used by the dictionary-
  /// delete path and by import-time bloom-filter construction. The
  /// composite `(dictionaryId, term)` index is what the language-
  /// scoped search path walks: per-dictionary queries like
  /// `.dictionaryIdEqualToTermStartsWith(id, prefix)` seek directly
  /// into that dictionary's slice of the term namespace instead of
  /// scanning a global term index and filtering after.
  ///
  /// Storage cost of the double indexing is minor compared to the
  /// term index itself and the saved query time.
  @Index()
  @Index(composite: [
    CompositeIndex('term', type: IndexType.value, caseSensitive: false)
  ])
  final int dictionaryId;

  /// Popularity score from the source dictionary. Higher = more common.
  /// Used at query time to sort headings.
  final double popularity;

  /// Compressed payload produced by [DefinitionCodec.encode]. Stored as a
  /// raw byte list so Isar can pack it efficiently without the ~33% overhead
  /// of a String/base64 representation.
  final List<byte> compressedDefinitions;

  /// Space-separated tag names that describe this single entry — the
  /// Yomichan term-bank "definitionTags" field stored verbatim. Looked up
  /// against the dictionary's tag map at render time.
  final String entryTagsRaw;

  /// Space-separated tag names that describe the headword (term/reading)
  /// this entry belongs to — the Yomichan term-bank "termTags" field stored
  /// verbatim.
  final String headingTagsRaw;

  /// Optional paths to image assets referenced by structured content. Kept
  /// as a list of relative filenames; resolved against the per-dictionary
  /// resource directory at render time.
  final List<String>? imagePaths;

  /// Optional paths to audio assets referenced by structured content.
  final List<String>? audioPaths;

  /// Transient. Populated by the search post-processing step in
  /// `AppModel.searchDictionary` after results are loaded but before they
  /// are returned to the UI. Reads are synchronous via
  /// [decodedDefinitions].
  @ignore
  List<String>? decodedDefinitionsCache;

  /// Transient. The owning [Dictionary] object, populated at search time
  /// by `AppModel.searchDictionary` so that call sites can keep the old
  /// `entry.dictionary.value!.name` syntax from the link-based schema.
  /// Null until populated.
  @ignore
  Dictionary? dictionaryRef;

  /// Transient. Resolved tag objects for the names listed in
  /// [entryTagsRaw], populated at search time. Empty until populated.
  /// Renderer code accesses this as `entry.tags` (matching the old
  /// `IsarLinks<DictionaryTag>` API shape).
  @ignore
  List<DictionaryTag> tags = <DictionaryTag>[];

  /// Compatibility shim that mimics the `IsarLink<Dictionary>` access
  /// pattern the rest of the codebase uses: `entry.dictionary.value!`.
  /// The [_EntryDictionaryLink.value] field returns [dictionaryRef]
  /// directly so the flat schema doesn't require touching every field
  /// and page that renders an entry.
  @ignore
  _EntryDictionaryLink get dictionary => _EntryDictionaryLink(this);

  /// Alias for [decodedDefinitions] preserved so existing field
  /// renderer code (`entry.definitions`) keeps working without per-
  /// site changes. Requires the entry to have been post-processed
  /// (i.e. passed through `AppModel.searchDictionary` or
  /// `AppModel.ensureDecoded`).
  @ignore
  List<String> get definitions => decodedDefinitions;

  /// Synchronous accessor for the decoded definitions list.
  ///
  /// Throws [StateError] if the cache has not been populated. This is
  /// intentional: it converts "forgot to pre-decode" into a hard failure
  /// during development rather than rendering compressed garbage.
  @ignore
  List<String> get decodedDefinitions {
    final cache = decodedDefinitionsCache;
    if (cache == null) {
      throw StateError(
          'DictionaryEntry.decodedDefinitions accessed before the entry '
          'was post-processed by AppModel.searchDictionary. Call '
          'AppModel.ensureDecoded(entry) first, or load entries via the '
          'search path.');
    }
    return cache;
  }

  /// Returns all definitions bullet-pointed if multiple, otherwise the
  /// single definition trimmed.
  ///
  /// Computed on-demand from [decodedDefinitions]; not stored.
  @ignore
  String get compactDefinitions {
    final defs = decodedDefinitions;
    if (defs.length > 1) {
      return defs.map((d) => '• ${d.trim()}').join('\n');
    }
    return defs.join().trim();
  }

  @override
  bool operator ==(Object other) => other is DictionaryEntry && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tiny `.value`-shaped wrapper so consumers can access the owning
/// [Dictionary] through `entry.dictionary.value!` — matching the
/// pattern the codebase uses with the old Isar link type without
/// forcing every call site to change shape. Pure getter, no
/// allocation of storage beyond the shim itself.
class _EntryDictionaryLink {
  _EntryDictionaryLink(this._entry);

  final DictionaryEntry _entry;

  /// The resolved dictionary, or null if the entry has not yet been
  /// post-processed by the search pipeline.
  Dictionary? get value => _entry.dictionaryRef;
}
