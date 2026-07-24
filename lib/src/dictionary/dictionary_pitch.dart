import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';

part 'dictionary_pitch.g.dart';

/// A pitch-accent annotation for a `(term, reading)` pair within a single
/// dictionary.
///
/// Flat schema (no `IsarLink<DictionaryHeading>`). Looked up at search-
/// post-processing time by [term], filtered down by [reading] and
/// [dictionaryId] in Dart.
@Collection()
class DictionaryPitch {
  /// Construct a pitch row.
  DictionaryPitch({
    required this.term,
    required this.reading,
    required this.dictionaryId,
    required this.downstep,
    this.id,
  });

  /// Identifier for database purposes.
  Id? id;

  /// The headword the pitch applies to. Indexed for search.
  @Index(type: IndexType.value, caseSensitive: false)
  final String term;

  /// The reading the pitch applies to.
  final String reading;

  /// Foreign-key-style reference to the parent [Dictionary] row's id.
  /// Indexed so deletion of a single dictionary is fast.
  @Index()
  final int dictionaryId;

  /// Mora index of the downstep (Yomichan's `position` field). 0 indicates
  /// a flat (heiban-equivalent) pitch contour.
  final int downstep;

  /// Transient. Owning dictionary resolved at search time — see
  /// [_PitchDictionaryLink].
  @ignore
  Dictionary? dictionaryRef;

  /// Compatibility shim for `pitch.dictionary.value!.xxx` access.
  @ignore
  _PitchDictionaryLink get dictionary => _PitchDictionaryLink(this);

  @override
  bool operator ==(Object other) => other is DictionaryPitch && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tiny `.value`-shaped wrapper so existing code can reach the owning
/// [Dictionary] through `pitch.dictionary.value!` in the flat schema.
class _PitchDictionaryLink {
  _PitchDictionaryLink(this._pitch);
  final DictionaryPitch _pitch;
  Dictionary? get value => _pitch.dictionaryRef;
}
