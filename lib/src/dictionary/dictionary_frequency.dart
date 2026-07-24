import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';

part 'dictionary_frequency.g.dart';

/// A frequency annotation for a `(term, reading)` pair within a single
/// dictionary.
///
/// Flat schema (no `IsarLink<DictionaryHeading>`). Looked up at search-
/// post-processing time by [term], filtered down by [reading] and
/// [dictionaryId] in Dart.
@Collection()
class DictionaryFrequency {
  /// Construct a frequency row.
  DictionaryFrequency({
    required this.term,
    required this.reading,
    required this.dictionaryId,
    required this.value,
    required this.displayValue,
    this.id,
  });

  /// Identifier for database purposes.
  Id? id;

  /// The headword the frequency applies to. Indexed for search.
  @Index(type: IndexType.value, caseSensitive: false)
  final String term;

  /// The reading the frequency applies to. Empty if the source dictionary
  /// did not specify a reading (frequency applies to any reading of
  /// [term]).
  final String reading;

  /// Foreign-key-style reference to the parent [Dictionary] row's id.
  /// Indexed so deletion of a single dictionary is fast.
  @Index()
  final int dictionaryId;

  /// Numeric value of the frequency. Lower = more common in some sources,
  /// higher = more common in others; interpretation is dictionary-specific.
  final double value;

  /// Display string as provided by the source dictionary, ready to render.
  final String displayValue;

  /// Transient. Owning dictionary resolved at search time — see
  /// [_FrequencyDictionaryLink].
  @ignore
  Dictionary? dictionaryRef;

  /// Compatibility shim for `frequency.dictionary.value!.xxx` access.
  @ignore
  _FrequencyDictionaryLink get dictionary => _FrequencyDictionaryLink(this);

  @override
  bool operator ==(Object other) =>
      other is DictionaryFrequency && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Tiny `.value`-shaped wrapper so existing code can reach the owning
/// [Dictionary] through `frequency.dictionary.value!` in the flat
/// schema.
class _FrequencyDictionaryLink {
  _FrequencyDictionaryLink(this._frequency);
  final DictionaryFrequency _frequency;
  Dictionary? get value => _frequency.dictionaryRef;
}
