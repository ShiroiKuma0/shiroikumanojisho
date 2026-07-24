import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;
import 'package:shiroikumanojisho/language.dart';

part 'dictionary.g.dart';

/// A dictionary that can be imported into the application, encapsulating its
/// metadata and current preferences.
///
/// Backlinks to entries, tags, pitches and frequencies that previous schema
/// versions kept here have been removed. Those collections now hold a plain
/// indexed `dictionaryId` field and are queried directly when needed (for
/// example, when the user removes this dictionary).
@Collection()
class Dictionary {
  /// Initialise a dictionary with details determined from import.
  Dictionary({
    required this.id,
    required this.name,
    required this.formatKey,
    required this.order,
    this.primaryLanguage = '',
    this.bloomBits = const <byte>[],
    this.hiddenLanguages = const [],
    this.collapsedLanguages = const [],
  });

  /// Identifier for database purposes.
  final Id id;

  /// The name of the dictionary. For example, this could be 'Merriam-Webster
  /// Dictionary' or '大辞林' or 'JMdict'.
  ///
  /// Dictionary names are meant to be unique, meaning two dictionaries of the
  /// same name should not be allowed to be added in the database.
  @Index(unique: true, replace: true)
  final String name;

  /// The unique key for the format that the dictionary was sourced from.
  final String formatKey;

  /// The language code (e.g. 'ja', 'de-DE') under which this dictionary
  /// was imported. Set once at import time from `AppModel.targetLanguage`
  /// and used by the search pipeline to scope per-language lookups and
  /// by the UI to surface "dictionary X is tagged as language Y" so the
  /// user can notice mis-tagged imports.
  ///
  /// Empty string for dictionaries imported under schema versions that
  /// predate this field — callers should treat empty as "unknown" and
  /// fall back to the legacy `hiddenLanguages` heuristic.
  @Index()
  final String primaryLanguage;

  /// Serialised bloom filter over the set of `term` values present in
  /// this dictionary. Built once at import time and consulted by the
  /// search pipeline to skip per-dictionary Isar queries for terms that
  /// are definitely not present. Kept small (target ~10-16 bits per
  /// entry; ~100-200 KB for a typical 100k-entry dict).
  ///
  /// Empty list for dictionaries imported under earlier schemas — the
  /// search pipeline treats this as "bloom unknown, always query".
  ///
  /// Not `final` so the import helper can mutate-then-put after the
  /// dictionary row already exists (the row is written early so the
  /// entry-insert loop can reference its id, then we come back to
  /// fill the bloom once all terms are present).
  List<byte> bloomBits;

  /// The order of this dictionary in terms of user sorting, relative to
  /// other dictionaries.
  @Index()
  int order;

  /// Returns the resource path for within the applications documents
  /// directory.
  String getBasePath({required String appDirDocPath}) {
    return path.join(appDirDocPath, name);
  }

  /// Languages where this dictionary is hidden. If a language has set this
  /// dictionary to hidden, then its language code will be here.
  @Index()
  List<String> hiddenLanguages;

  /// Languages where this dictionary is collapsed. If a language has set
  /// this dictionary to collapsed, then its language code will be here.
  @Index()
  List<String> collapsedLanguages;

  /// Whether this dictionary is hidden for a given language.
  bool isHidden(Language language) {
    return hiddenLanguages.contains(language.languageCode);
  }

  /// Whether this dictionary is collapsed for a given language.
  bool isCollapsed(Language language) {
    return collapsedLanguages.contains(language.languageCode);
  }

  /// Given an asset name, returns an appropriate path to place the asset
  /// within this dictionary's resource path.
  String getResourcePath({
    required String appDirDocPath,
    required String resourceBasename,
  }) {
    return path.join(
      getBasePath(appDirDocPath: appDirDocPath),
      resourceBasename,
    );
  }

  @override
  bool operator ==(Object other) => other is Dictionary && name == other.name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  toString() {
    return 'Dictionary(name: $name, format: $formatKey)';
  }
}
