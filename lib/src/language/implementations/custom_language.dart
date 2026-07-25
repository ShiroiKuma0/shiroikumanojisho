import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/language.dart';

/// A user-configurable language implementation. Search behaviour follows
/// the standard latin-script algorithm — see [runStandardLatinSearch].
///
/// For non-space-delimited custom languages (e.g. Chinese, Thai), the
/// segmentation in [textToWords] falls back to per-character splitting,
/// which still produces sensible search candidates because the
/// underlying Isar query uses prefix matching.
class CustomLanguage extends Language {
  CustomLanguage({
    required super.languageName,
    required super.languageCode,
    required super.countryCode,
    required super.threeLetterCode,
    required super.textDirection,
    required super.preferVerticalReading,
    required super.isSpaceDelimited,
    required super.textBaseline,
    required super.helloWorld,
    required super.defaultFontFamily,
  }) : super(
          standardFormat: YomichanFormat.instance,
          prepareSearchResults: prepareSearchResultsCustomLanguage,
        );

  @override
  Future<void> prepareResources() async {}

  @override
  List<String> textToWords(String text) {
    if (isSpaceDelimited) {
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
    } else {
      // Character-by-character for non-space-delimited.
      return text.characters.map((c) => c).toList();
    }
  }

  /// Save custom language config to Hive.
  static Future<void> saveConfig(Box box, CustomLanguage lang) async {
    await box.put('custom_lang_name', lang.languageName);
    await box.put('custom_lang_code', lang.languageCode);
    await box.put('custom_lang_country', lang.countryCode);
    await box.put('custom_lang_three', lang.threeLetterCode);
    await box.put('custom_lang_rtl', lang.textDirection == TextDirection.rtl);
    await box.put('custom_lang_vertical', lang.preferVerticalReading);
    await box.put('custom_lang_spaced', lang.isSpaceDelimited);
    await box.put('custom_lang_ideographic',
        lang.textBaseline == TextBaseline.ideographic);
    await box.put('custom_lang_hello', lang.helloWorld);
    await box.put('custom_lang_font', lang.defaultFontFamily);
    await box.put('custom_lang_enabled', true);
  }

  /// Load custom language from Hive, or null if not configured.
  static CustomLanguage? loadConfig(Box box) {
    if (box.get('custom_lang_enabled', defaultValue: false) != true) {
      return null;
    }
    return CustomLanguage(
      languageName: box.get('custom_lang_name', defaultValue: 'Custom'),
      languageCode: box.get('custom_lang_code', defaultValue: 'xx'),
      countryCode: box.get('custom_lang_country', defaultValue: 'XX'),
      threeLetterCode: box.get('custom_lang_three', defaultValue: 'xxx'),
      textDirection: box.get('custom_lang_rtl', defaultValue: false)
          ? TextDirection.rtl
          : TextDirection.ltr,
      preferVerticalReading:
          box.get('custom_lang_vertical', defaultValue: false),
      isSpaceDelimited: box.get('custom_lang_spaced', defaultValue: true),
      textBaseline: box.get('custom_lang_ideographic', defaultValue: false)
          ? TextBaseline.ideographic
          : TextBaseline.alphabetic,
      helloWorld: box.get('custom_lang_hello', defaultValue: 'Hello'),
      defaultFontFamily: box.get('custom_lang_font', defaultValue: 'Roboto'),
    );
  }

  /// Remove custom language config.
  static Future<void> removeConfig(Box box) async {
    await box.put('custom_lang_enabled', false);
  }
}

/// Language presets for quick configuration.
class LanguagePreset {

  const LanguagePreset({
    required this.name,
    required this.code,
    required this.country,
    required this.threeLetterCode,
    required this.hello, this.rtl = false,
    this.vertical = false,
    this.spaceDelimited = true,
    this.ideographic = false,
    this.font = 'Roboto',
  });
  final String name;
  final String code;
  final String country;
  final String threeLetterCode;
  final bool rtl;
  final bool vertical;
  final bool spaceDelimited;
  final bool ideographic;
  final String hello;
  final String font;

  static const List<LanguagePreset> presets = [
    LanguagePreset(name: 'العربية (Arabic)', code: 'ar', country: 'SA',
        threeLetterCode: 'ara', rtl: true, hello: 'مرحبا بالعالم',
        font: 'Noto Sans Arabic'),
    LanguagePreset(name: 'বাংলা (Bengali)', code: 'bn', country: 'BD',
        threeLetterCode: 'ben', hello: 'হ্যালো বিশ্ব',
        font: 'Noto Sans Bengali'),
    LanguagePreset(name: '中文 (Chinese)', code: 'zh', country: 'CN',
        threeLetterCode: 'zho', spaceDelimited: false, ideographic: true,
        hello: '你好世界', font: 'Noto Sans SC'),
    LanguagePreset(name: 'Dansk (Danish)', code: 'da', country: 'DK',
        threeLetterCode: 'dan', hello: 'Hej verden'),
    LanguagePreset(name: 'Nederlands (Dutch)', code: 'nl', country: 'NL',
        threeLetterCode: 'nld', hello: 'Hallo wereld'),
    LanguagePreset(name: 'Suomi (Finnish)', code: 'fi', country: 'FI',
        threeLetterCode: 'fin', hello: 'Hei maailma'),
    LanguagePreset(name: 'Français (French)', code: 'fr', country: 'FR',
        threeLetterCode: 'fra', hello: 'Bonjour le monde'),
    LanguagePreset(name: 'Ελληνικά (Greek)', code: 'el', country: 'GR',
        threeLetterCode: 'ell', hello: 'Γεια σου κόσμε'),
    LanguagePreset(name: 'עברית (Hebrew)', code: 'he', country: 'IL',
        threeLetterCode: 'heb', rtl: true, hello: 'שלום עולם',
        font: 'Noto Sans Hebrew'),
    LanguagePreset(name: 'हिन्दी (Hindi)', code: 'hi', country: 'IN',
        threeLetterCode: 'hin', hello: 'नमस्ते दुनिया',
        font: 'Noto Sans Devanagari'),
    LanguagePreset(name: 'Magyar (Hungarian)', code: 'hu', country: 'HU',
        threeLetterCode: 'hun', hello: 'Helló világ'),
    LanguagePreset(name: 'Bahasa Indonesia', code: 'id', country: 'ID',
        threeLetterCode: 'ind', hello: 'Halo dunia'),
    LanguagePreset(name: 'Italiano (Italian)', code: 'it', country: 'IT',
        threeLetterCode: 'ita', hello: 'Ciao mondo'),
    LanguagePreset(name: '한국어 (Korean)', code: 'ko', country: 'KR',
        threeLetterCode: 'kor', ideographic: true, hello: '안녕하세요',
        font: 'Noto Sans KR'),
    LanguagePreset(name: 'Norsk (Norwegian)', code: 'no', country: 'NO',
        threeLetterCode: 'nor', hello: 'Hei verden'),
    LanguagePreset(name: 'فارسی (Persian)', code: 'fa', country: 'IR',
        threeLetterCode: 'fas', rtl: true, hello: 'سلام دنیا',
        font: 'Noto Sans Arabic'),
    LanguagePreset(name: 'Português (Portuguese)', code: 'pt', country: 'BR',
        threeLetterCode: 'por', hello: 'Olá mundo'),
    LanguagePreset(name: 'Română (Romanian)', code: 'ro', country: 'RO',
        threeLetterCode: 'ron', hello: 'Salut lume'),
    LanguagePreset(name: 'Slovenčina (Slovak)', code: 'sk', country: 'SK',
        threeLetterCode: 'slk', hello: 'Ahoj svet'),
    LanguagePreset(name: 'Español (Spanish)', code: 'es', country: 'ES',
        threeLetterCode: 'spa', hello: 'Hola mundo'),
    LanguagePreset(name: 'Svenska (Swedish)', code: 'sv', country: 'SE',
        threeLetterCode: 'swe', hello: 'Hej världen'),
    LanguagePreset(name: 'ภาษาไทย (Thai)', code: 'th', country: 'TH',
        threeLetterCode: 'tha', spaceDelimited: false, hello: 'สวัสดีชาวโลก',
        font: 'Noto Sans Thai'),
    LanguagePreset(name: 'Türkçe (Turkish)', code: 'tr', country: 'TR',
        threeLetterCode: 'tur', hello: 'Merhaba dünya'),
    LanguagePreset(name: 'Tiếng Việt (Vietnamese)', code: 'vi', country: 'VN',
        threeLetterCode: 'vie', hello: 'Xin chào thế giới'),
  ];
}

/// Top-level function for use in compute. Reuses [runStandardLatinSearch].
Future<SearchResultData?> prepareSearchResultsCustomLanguage(
    DictionarySearchParams params) async {
  return runStandardLatinSearch(params);
}
