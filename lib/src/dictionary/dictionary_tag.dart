import 'dart:ui';

import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';

part 'dictionary_tag.g.dart';

/// A database entity for tags, heavily based on the Yomichan format.
///
/// Tags are display metadata only — they describe a tag's color, category,
/// human-readable notes etc. The actual relationship from entries to tags
/// lives inline on each [DictionaryEntry] as a space-separated string in
/// `entryTagsRaw` / `headingTagsRaw`. At render time, those names are
/// looked up against an in-memory `Map<String, DictionaryTag>` built per
/// dictionary.
@Collection()
class DictionaryTag {
  /// Initialise a tag with the given parameters.
  DictionaryTag({
    required this.dictionaryId,
    required this.name,
    required this.category,
    required this.sortingOrder,
    required this.notes,
    required this.popularity,
  });

  /// Convenience factory for the implicit tag that represents the
  /// dictionary itself (used as a chip on entries to identify their source
  /// dictionary).
  factory DictionaryTag.dictionary(Dictionary dictionary) {
    return DictionaryTag(
      dictionaryId: dictionary.id,
      name: dictionary.name,
      notes: '',
      sortingOrder: -100000000000,
      category: 'frequent',
      popularity: 0,
    );
  }

  /// Dictionary id this tag belongs to. Indexed for delete-by-dictionary.
  @Index()
  final int dictionaryId;

  /// Function to generate a stable lookup id for a tag from its composite
  /// key.
  static int hash({required int dictionaryId, required String name}) {
    return fastHash('$dictionaryId/$name');
  }

  /// Identifier for database purposes. Computed from [dictionaryId] and
  /// [name] so that lookups during import and at render time can use a
  /// known id without an index probe.
  Id get isarId => hash(dictionaryId: dictionaryId, name: name);

  /// Display name for the tag (the lookup key from the entry's
  /// `*TagsRaw` strings).
  @Index()
  final String name;

  /// Category for the tag, used to pick a color.
  final String category;

  /// Sorting order for the tag.
  final int sortingOrder;

  /// Notes for this tag.
  final String notes;

  /// Score used to determine popularity. Negative = rare, positive =
  /// frequent. Also used to sort search results in some legacy code paths.
  final double popularity;

  /// Get the color for this tag based on its category.
  @ignore
  Color get color {
    switch (category) {
      case 'name':
        return const Color(0xffd46a6a);
      case 'expression':
        return const Color(0xffff4d4d);
      case 'popular':
        return const Color(0xff550000);
      case 'partOfSpeech':
        return const Color(0xff565656);
      case 'archaism':
        return const Color(0xFF616161);
      case 'dictionary':
        return const Color(0xffa15151);
      case 'frequency':
        return const Color(0xffd46a6a);
      case 'frequent':
        return const Color(0xff801515);
    }

    return const Color(0xFF616161);
  }

  @override
  bool operator ==(Object other) =>
      other is DictionaryTag && isarId == other.isarId;

  @override
  int get hashCode => isarId.hashCode;
}
