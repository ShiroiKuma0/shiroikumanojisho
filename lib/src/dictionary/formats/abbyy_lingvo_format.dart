import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;

import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/i18n/strings.g.dart';

/// A dictionary format for files following the ABBYY Lingvo or DSL format
/// compatible with GoldenDict.
///
/// Details on the format:
/// http://lingvo.helpmax.net/en/troubleshooting/dsl-compiler/dsl-dictionary-structure/
class AbbyyLingvoFormat extends DictionaryFormat {
  AbbyyLingvoFormat._privateConstructor()
      : super(
          uniqueKey: 'abbyy_lingvo',
          name: 'ABBYY Lingvo (DSL)',
          icon: Icons.auto_stories_rounded,
          allowedExtensions: const ['dsl'],
          isTextFormat: true,
          fileType: FileType.any,
          prepareDirectory: prepareDirectoryAbbyyLingvoFormat,
          prepareName: prepareNameAbbyyLingvoFormat,
          prepareEntries: prepareEntriesAbbyyLingvoFormat,
          prepareTags: prepareTagsAbbyyLingvoFormat,
          preparePitches: preparePitchesAbbyyLingvoFormat,
          prepareFrequencies: prepareFrequenciesAbbyyLingvoFormat,
        );

  static AbbyyLingvoFormat get instance => _instance;
  static final AbbyyLingvoFormat _instance =
      AbbyyLingvoFormat._privateConstructor();
}

/// Top-level: copy the .dsl into the working directory, decoding from
/// UTF-16 if needed.
Future<void> prepareDirectoryAbbyyLingvoFormat(
    PrepareDirectoryParams params) async {
  final dictionaryFilePath =
      path.join(params.resourceDirectory.path, 'dictionary.dsl');
  final originalFile = params.file;
  final newFile = File(dictionaryFilePath);

  if (params.charset.startsWith('UTF-16')) {
    final utf16CodeUnits =
        originalFile.readAsBytesSync().buffer.asUint16List();
    final converted = String.fromCharCodes(utf16CodeUnits);
    newFile.createSync();
    newFile.writeAsStringSync(converted);
  } else {
    originalFile.copySync(newFile.path);
  }
}

/// Top-level: dictionary name comes from the `#NAME` directive line.
Future<String> prepareNameAbbyyLingvoFormat(
    PrepareDirectoryParams params) async {
  final dictionaryFilePath =
      path.join(params.resourceDirectory.path, 'dictionary.dsl');
  final dictionaryFile = File(dictionaryFilePath);

  final nameLine =
      dictionaryFile.readAsLinesSync().first.replaceFirst('#NAME', '').trim();

  return nameLine.substring(1, nameLine.length - 1);
}

/// Batch size for entry writes.
const int _kEntryWriteBatch = 1000;

/// Top-level: parse the .dsl line by line, build entry rows with zstd-
/// compressed definitions, write in batches.
Future<void> prepareEntriesAbbyyLingvoFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final dictionaryFilePath =
      path.join(params.resourceDirectory.path, 'dictionary.dsl');
  final dictionaryFile = File(dictionaryFilePath);

  // Strip / canonicalise common DSL inline markup.
  final text = dictionaryFile
      .readAsStringSync()
      .replaceAll('<br>', '\n')
      .replaceAll('[', '<')
      .replaceAll(']', '>')
      .replaceAll('{{', '<')
      .replaceAll('}}', '>')
      .replaceAll('<m0>', '')
      .replaceAll('<m1>', ' ')
      .replaceAll('<m2>', '  ')
      .replaceAll('<m3>', '   ')
      .replaceAll('\\<', '<')
      .replaceAll('\\>', '>')
      .replaceAll('<<', '')
      .replaceAll('>>', '')
      .replaceAll(RegExp('<[^<]+?>'), '');

  final lines = text.split('\n');
  final dictionaryId = params.dictionary.id;
  final pendingEntries = <DictionaryEntry>[];
  int count = 0;

  Future<void> flushPending() async {
    if (pendingEntries.isEmpty) return;
    final toWrite = List<DictionaryEntry>.from(pendingEntries);
    pendingEntries.clear();
    isar.writeTxnSync(() {
      isar.dictionaryEntrys.putAllSync(toWrite);
    });
  }

  String term = '';
  final buffer = StringBuffer();

  for (final line in lines) {
    if (line.startsWith('#')) continue;

    if (line.characters.isNotEmpty &&
        line.characters.first.codeUnits.first == 9) {
      // Tab-indented = part of the current term's definition.
      buffer.writeln(line);
    } else {
      // New term boundary — flush the previous one.
      final definition = buffer.toString();
      buffer.clear();

      if (term.isNotEmpty && definition.isNotEmpty) {
        final compressed = await DefinitionCodec.encode([definition]);
        pendingEntries.add(DictionaryEntry(
          term: term,
          reading: '',
          dictionaryId: dictionaryId,
          popularity: 0,
          compressedDefinitions: compressed,
        ));

        if (pendingEntries.length >= _kEntryWriteBatch) {
          await flushPending();
        }

        count++;
        if ((count & 0xFF) == 0) {
          params.send(t.import_found_entry(count: count));
        }
      }

      term = line.trim();
    }
  }

  // Final pending entry (last term in file).
  final definition = buffer.toString();
  if (term.isNotEmpty && definition.isNotEmpty) {
    final compressed = await DefinitionCodec.encode([definition]);
    pendingEntries.add(DictionaryEntry(
      term: term,
      reading: '',
      dictionaryId: dictionaryId,
      popularity: 0,
      compressedDefinitions: compressed,
    ));
    count++;
  }

  await flushPending();
  params.send(t.import_found_entry(count: count));
}

/// Top-level: DSL has no tag bank.
Future<void> prepareTagsAbbyyLingvoFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {}

/// Top-level: DSL has no pitch data.
Future<void> preparePitchesAbbyyLingvoFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {}

/// Top-level: DSL has no frequency data.
Future<void> prepareFrequenciesAbbyyLingvoFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {}
