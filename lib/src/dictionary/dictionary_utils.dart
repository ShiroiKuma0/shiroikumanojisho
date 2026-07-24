import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/models.dart';

/// FNV-1a 64-bit hash algorithm optimised for Dart Strings.
///
/// Used to generate deterministic integer ids for entities whose natural
/// keys are strings (currently only [DictionaryTag]). Collision risk is
/// negligible for the cardinalities involved (a few hundred tags per
/// dictionary).
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}

/// Top-level helper invoked through `compute()` for dictionary import.
///
/// Opens Isar in the worker isolate, then asks the format implementation to
/// write its tags, entries, pitch and frequency rows. Each prepare\* step
/// is responsible for its own write transactions and batching — this
/// function no longer wraps everything in a single transaction because
/// compression is asynchronous and `writeTxnSync` does not honour async
/// callbacks.
Future<void> depositDictionaryDataHelper(PrepareDictionaryParams params) async {
  try {
    final Isar isar = await Isar.open(
      globalSchemas,
      directory: params.directoryPath,
      maxSizeMiB: 8192,
    );

    isar.writeTxnSync(() {
      isar.dictionarys.putSync(params.dictionary);
    });

    await params.dictionaryFormat.prepareTags(params: params, isar: isar);
    await params.dictionaryFormat.prepareEntries(params: params, isar: isar);
    await params.dictionaryFormat.preparePitches(params: params, isar: isar);
    await params.dictionaryFormat
        .prepareFrequencies(params: params, isar: isar);

    // After entries are in the database, build a bloom filter over this
    // dictionary's terms and persist it on the Dictionary row. The
    // search pipeline consults this filter before issuing a per-
    // dictionary term query, which lets it skip dictionaries that
    // definitely don't contain the term — a significant win for
    // multi-language installs where most candidate prefixes miss in
    // most dictionaries.
    //
    // The query uses the composite `(dictionaryId, term)` index so
    // the scan is O(entries_in_this_dict), not O(entries_total). We
    // materialise the full term list (strings only, cheap) and feed it
    // straight to `TermBloom.build`. No extra Isar round-trip at
    // runtime.
    final List<String> terms = isar.dictionaryEntrys
        .where()
        .dictionaryIdEqualTo(params.dictionary.id)
        .termProperty()
        .findAllSync();
    final bloom = TermBloom.build(terms);
    params.dictionary.bloomBits = bloom.toBytes();
    isar.writeTxnSync(() {
      isar.dictionarys.putSync(params.dictionary);
    });
  } catch (e, stack) {
    debugPrint('$e');
    debugPrint('$stack');
    params.send('$stack');
    rethrow;
  }
}

/// Clears all dictionary data from the database.
///
/// Used both by the user-facing "delete all dictionaries" action and by
/// the schema migration on first launch under the v2 schema.
Future<void> deleteDictionariesHelper(DeleteDictionaryParams params) async {
  final Isar database = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );

  database.writeTxnSync(() {
    database.dictionaryTags.clearSync();
    database.dictionaryEntrys.clearSync();
    database.dictionaryPitchs.clearSync();
    database.dictionaryFrequencys.clearSync();
    database.dictionarys.clearSync();
  });
}

/// Clears a single dictionary's data from the database.
///
/// Uses indexed `dictionaryId` field on each collection — fast even at
/// scale because no link tables need walking.
Future<void> deleteDictionaryHelper(DeleteDictionaryParams params) async {
  final Isar database = await Isar.open(
    globalSchemas,
    directory: params.directoryPath,
    maxSizeMiB: 8192,
  );

  final int id = params.dictionaryId!;
  final Dictionary dictionary = database.dictionarys.getSync(id)!;

  database.writeTxnSync(() {
    database.dictionaryEntrys
        .where()
        .dictionaryIdEqualTo(id)
        .deleteAllSync();
    database.dictionaryTags
        .where()
        .dictionaryIdEqualTo(id)
        .deleteAllSync();
    database.dictionaryPitchs
        .where()
        .dictionaryIdEqualTo(id)
        .deleteAllSync();
    database.dictionaryFrequencys
        .where()
        .dictionaryIdEqualTo(id)
        .deleteAllSync();
    database.dictionarys.deleteSync(dictionary.id);
  });
}
