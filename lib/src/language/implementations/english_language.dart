import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:lemmatizerx/lemmatizerx.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/language.dart';
import 'package:shiroikumanojisho/models.dart';

/// Language implementation of the English language.
class EnglishLanguage extends Language {
  EnglishLanguage._privateConstructor()
      : super(
          languageName: 'English',
          languageCode: 'en',
          countryCode: 'US',
          threeLetterCode: 'eng',
          preferVerticalReading: false,
          textDirection: TextDirection.ltr,
          isSpaceDelimited: true,
          textBaseline: TextBaseline.alphabetic,
          helloWorld: 'Hello world',
          prepareSearchResults: prepareSearchResultsEnglishLanguage,
          standardFormat: MigakuFormat.instance,
          defaultFontFamily: 'Roboto',
        );

  /// Get the singleton instance of this language.
  static EnglishLanguage get instance => _instance;
  static final EnglishLanguage _instance =
      EnglishLanguage._privateConstructor();

  @override
  Future<void> prepareResources() async {}

  @override
  List<String> textToWords(String text) {
    final splitText = text.splitWithDelim(RegExp(r'[-\n\r\s]+'));
    return splitText
        .mapIndexed((index, element) {
          if (index.isEven && index + 1 < splitText.length) {
            return [splitText[index], splitText[index + 1]].join();
          } else if (index + 1 == splitText.length) {
            return splitText[index];
          } else {
            return '';
          }
        })
        .where((e) => e.isNotEmpty)
        .toList();
  }
}

/// Expand common English contractions in the search term so that
/// "I'm" matches "I am", "won't" matches "will not", etc.
String _expandContractions(String input) {
  return input
      .replaceAll('won\'t', 'will not')
      .replaceAll('can\'t', 'cannot')
      .replaceAll('i\'m', 'i am')
      .replaceAll('ain\'t', 'is not')
      .replaceAll('\'ll', ' will')
      .replaceAll('n\'t', ' not')
      .replaceAll('\'ve', ' have')
      .replaceAll('\'s', ' is')
      .replaceAll('\'re', ' are')
      .replaceAll('\'d', ' would')
      // Curly-quote variants.
      .replaceAll('won\u2019t', 'will not')
      .replaceAll('can\u2019t', 'cannot')
      .replaceAll('i\u2019m', 'i am')
      .replaceAll('ain\u2019t', 'is not')
      .replaceAll('\u2019ll', ' will')
      .replaceAll('n\u2019t', ' not')
      .replaceAll('\u2019ve', ' have')
      .replaceAll('\u2019s', ' is')
      .replaceAll('\u2019re', ' are')
      .replaceAll('\u2019d', ' would');
}

/// Top-level function for use in compute.
///
/// English search has a few extra wrinkles vs the standard latin path:
///   * contractions are expanded before searching
///   * the candidate-prefix split keeps three leading words (not just one)
///     so that compound expressions like "give it up" can match
///   * the last word in each prefix is lemmatised so "running" can also
///     match "run"
Future<SearchResultData?> prepareSearchResultsEnglishLanguage(
    DictionarySearchParams params) async {
  final lemmatizer = Lemmatizer();
  // Reuse the isolate's existing Isar handle if one is already
  // cached (persistent-worker isolate, second and subsequent calls).
  // See the same note in standard_searches.dart.
  final database = Isar.getInstance() ??
      await Isar.open(
        globalSchemas,
        directory: params.directoryPath,
        maxSizeMiB: 8192,
      );

  String searchTerm = _expandContractions(params.searchTerm.toLowerCase().trim());
  if (searchTerm.isEmpty) return null;

  final maxGroups = params.maximumDictionaryTermsInResult;
  final builder =
      SearchResultBuilder(searchTerm: searchTerm, maxGroups: maxGroups);

  int entryFetchLimit() {
    final remaining = builder.remainingGroups();
    if (remaining <= 0) return 0;
    return remaining * 8;
  }

  final shouldSearchWildcards = params.searchWithWildcards &&
      (searchTerm.contains('*') || searchTerm.contains('?'));

  if (shouldSearchWildcards) {
    final noExactMatches = database.dictionaryEntrys
        .where()
        .termEqualTo(searchTerm)
        .isEmptySync();

    if (noExactMatches) {
      final matchesTerm = searchTerm;
      final questionMarkOnly = !matchesTerm.contains('*');
      final noAsterisks = searchTerm
          .replaceAll('\u203B', '*')
          .replaceAll('\uFF1F', '?')
          .replaceAll('*', '');

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
    // Build the candidate-prefix list — preserve the original three-word
    // unrolling logic so multi-word expressions can match.
    List<String> segments = searchTerm.splitWithDelim(RegExp('[ -\']'));
    if (segments.length > 20) segments = segments.sublist(0, 10);

    if (segments.length >= 3) {
      final firstWord = segments.removeAt(0);
      final secondWord = segments.removeAt(0);
      final thirdWord = segments.removeAt(0);
      segments = [
        if (firstWord.length > 3)
          if (firstWord.split('').length > 3) ...[
            firstWord.substring(0, firstWord.length - 3),
            firstWord[firstWord.length - 3],
            firstWord[firstWord.length - 2],
            firstWord[firstWord.length - 1],
          ] else
            ...firstWord.split('')
        else
          firstWord,
        if (secondWord.length > 3)
          if (secondWord.split('').length > 3) ...[
            secondWord.substring(0, secondWord.length - 3),
            secondWord[secondWord.length - 3],
            secondWord[secondWord.length - 2],
            secondWord[secondWord.length - 1],
          ] else
            ...secondWord.split('')
        else
          secondWord,
        if (thirdWord.length > 3)
          if (thirdWord.split('').length > 3) ...[
            thirdWord.substring(0, thirdWord.length - 3),
            thirdWord[thirdWord.length - 3],
            thirdWord[thirdWord.length - 2],
            thirdWord[thirdWord.length - 1],
          ] else
            ...thirdWord.split('')
        else
          thirdWord,
      ];
    } else {
      final firstWord = segments.removeAt(0);
      segments = [
        if (firstWord.length >= 3) ...firstWord.split('') else firstWord,
      ];
    }

    final exactByLength = <int, List<DictionaryEntry>>{};
    final deinflectedByLength = <int, List<DictionaryEntry>>{};
    final startsWithByLength = <int, List<DictionaryEntry>>{};

    for (int i = 0; i < segments.length; i++) {
      final partialTerm = segments
          .sublist(0, segments.length - i)
          .join()
          .replaceAll(RegExp(r'[^\p{L}\p{M} -]', unicode: true), '');

      if (partialTerm.endsWith(' ')) continue;
      if (entryFetchLimit() <= 0) break;

      // Lemmatise the trailing word for deinflection candidates.
      final blocks = partialTerm.split(' ');
      final lastBlock = blocks.removeLast();
      final possibleDeinflections = lemmatizer
          .lemmas(lastBlock)
          .map((lemma) => lemma.lemmas)
          .flattened
          .where((e) => e.isNotEmpty)
          .map((e) => [...blocks, e].join())
          .toList();

      // Exact term match.
      final exact = database.dictionaryEntrys
          .where(sort: Sort.desc)
          .termEqualTo(partialTerm)
          .limit(entryFetchLimit())
          .findAllSync();

      // Deinflected term match (only if there are candidate lemmas).
      List<DictionaryEntry> deinflected = const <DictionaryEntry>[];
      if (possibleDeinflections.isNotEmpty && entryFetchLimit() > 0) {
        deinflected = database.dictionaryEntrys
            .where()
            .anyOf<String, String>(
                possibleDeinflections, (q, term) => q.termEqualTo(term))
            .limit(entryFetchLimit())
            .findAllSync();
      }

      // Starts-with for non-trivial prefixes.
      List<DictionaryEntry> startsWith = const <DictionaryEntry>[];
      if (partialTerm.length >= 3 && entryFetchLimit() > 0) {
        startsWith = database.dictionaryEntrys
            .where()
            .termStartsWith(partialTerm)
            .sortByTermLength()
            .limit(entryFetchLimit())
            .findAllSync();
      }

      if (exact.isNotEmpty) {
        exactByLength[partialTerm.length] = exact;
        builder.recordMatchLength(partialTerm.length);
      }
      if (deinflected.isNotEmpty) {
        deinflectedByLength[partialTerm.length] = deinflected;
        builder.recordMatchLength(partialTerm.length);
      }
      if (startsWith.isNotEmpty) {
        startsWithByLength[partialTerm.length] = startsWith;
        builder.recordMatchLength(partialTerm.length);
      }
    }

    // Insertion order: exact > deinflected, both walked from longest
    // prefix to shortest. Starts-with entries come last (or earlier if
    // wildcard mode requested them sooner — see the original logic).
    for (int length = searchTerm.length; length > 0; length--) {
      final batch = exactByLength[length];
      if (batch != null) builder.addEntries(batch);
    }
    for (int length = searchTerm.length; length > 0; length--) {
      final batch = deinflectedByLength[length];
      if (batch != null) builder.addEntries(batch);
    }
    for (int length = searchTerm.length; length > 0; length--) {
      final batch = startsWithByLength[length];
      if (batch != null) builder.addEntries(batch);
    }
  }

  return builder.build(database);
}
