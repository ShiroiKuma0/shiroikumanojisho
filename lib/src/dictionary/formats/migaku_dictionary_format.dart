import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_archive/flutter_archive.dart';
import 'package:isar_community/isar.dart';
import 'package:path/path.dart' as path;

import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/i18n/strings.g.dart';

/// A dictionary format for the JSON-based Migaku Dictionary archives.
class MigakuFormat extends DictionaryFormat {
  MigakuFormat._privateConstructor()
      : super(
          uniqueKey: 'migaku',
          name: 'Migaku Dictionary',
          icon: Icons.auto_stories_rounded,
          allowedExtensions: const ['zip'],
          isTextFormat: false,
          fileType: FileType.any,
          prepareDirectory: prepareDirectoryMigakuFormat,
          prepareName: prepareNameMigakuFormat,
          prepareEntries: prepareEntriesMigakuFormat,
          prepareTags: prepareTagsMigakuFormat,
          preparePitches: preparePitchesMigakuFormat,
          prepareFrequencies: prepareFrequenciesMigakuFormat,
        );

  /// Get the singleton instance of this dictionary format.
  static MigakuFormat get instance => _instance;
  static final MigakuFormat _instance = MigakuFormat._privateConstructor();
}

/// Top-level: extract the source archive into a working directory.
Future<void> prepareDirectoryMigakuFormat(PrepareDirectoryParams params) async {
  await ZipFile.extractToDirectory(
    zipFile: params.file,
    destinationDir: params.resourceDirectory,
  );
}

/// Top-level: dictionary name = original ZIP basename (Migaku has no
/// in-archive name).
Future<String> prepareNameMigakuFormat(PrepareDirectoryParams params) async {
  return path.basenameWithoutExtension(params.file.path);
}

/// Batch size for entry writes.
const int _kEntryWriteBatch = 1000;

/// Top-level: parse all JSON files in the archive, build entry rows with
/// zstd-compressed definitions, write in batches.
Future<void> prepareEntriesMigakuFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

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

  for (final file in files) {
    final List<dynamic> items =
        List.from(jsonDecode(file.readAsStringSync()));

    for (final dynamic item in items) {
      final Map<String, dynamic> map = Map<String, dynamic>.from(item);

      final String term = (map['term'] as String).trim();
      String definition = map['definition'] as String;
      final String reading = map['pronunciation'] ?? '';

      definition = definition
          .replaceAll('<br>', '\n')
          .replaceAll(RegExp('<[^<]+?>'), '');

      final compressed = await DefinitionCodec.encode([definition]);

      pendingEntries.add(DictionaryEntry(
        term: term,
        reading: reading,
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
  }

  await flushPending();
  params.send(t.import_found_entry(count: count));
}

/// Top-level: Migaku archives have no tag bank.
Future<void> prepareTagsMigakuFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {}

/// Top-level: Migaku archives have no pitch data.
Future<void> preparePitchesMigakuFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {}

/// Top-level: Migaku archives have no frequency data.
Future<void> prepareFrequenciesMigakuFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {}
