import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/language.dart';

/// Language implementation of the Czech language.
class CzechLanguage extends Language {
  CzechLanguage._privateConstructor()
      : super(
          languageName: 'Čeština',
          languageCode: 'cs',
          countryCode: 'CZ',
          threeLetterCode: 'ces',
          preferVerticalReading: false,
          textDirection: TextDirection.ltr,
          isSpaceDelimited: true,
          textBaseline: TextBaseline.alphabetic,
          helloWorld: 'Ahoj světe',
          prepareSearchResults: prepareSearchResultsCzechLanguage,
          standardFormat: MigakuFormat.instance,
          defaultFontFamily: 'Roboto',
        );

  /// Get the singleton instance of this language.
  static CzechLanguage get instance => _instance;
  static final CzechLanguage _instance = CzechLanguage._privateConstructor();

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

/// Top-level function for use in compute. Same algorithm as German — see
/// [prepareSearchResultsGermanLanguage] in `german_language.dart` for
/// inline comments.
Future<SearchResultData?> prepareSearchResultsCzechLanguage(
    DictionarySearchParams params) async {
  return runStandardLatinSearch(params);
}
