import 'dart:convert';
import 'dart:io';

import 'package:async_zip/async_zip.dart';
import 'package:beautiful_soup_dart/beautiful_soup.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:isar_community/isar.dart';
import 'package:list_counter/list_counter.dart';
import 'package:path/path.dart' as path;
import 'package:recase/recase.dart';
import 'package:collection/collection.dart';
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/utils.dart';

/// A dictionary format for archives following the latest Yomichan bank
/// schema. Example dictionaries for this format may be downloaded from the
/// Yomitan website.
///
/// Details on the format:
///   https://github.com/yomidevs/yomitan/blob/master/docs/development/yomitan-dictionary-format.md
class YomichanFormat extends DictionaryFormat {
  YomichanFormat._privateConstructor()
      : super(
          uniqueKey: 'yomichan',
          name: 'Yomichan Dictionary',
          icon: Icons.auto_stories_rounded,
          allowedExtensions: const ['zip'],
          isTextFormat: false,
          fileType: FileType.custom,
          prepareDirectory: prepareDirectoryYomichanFormat,
          prepareName: prepareNameYomichanFormat,
          prepareEntries: prepareEntriesYomichanFormat,
          prepareTags: prepareTagsYomichanFormat,
          preparePitches: preparePitchesYomichanFormat,
          prepareFrequencies: prepareFrequenciesYomichanFormat,
        );

  /// Get the singleton instance of this dictionary format.
  static YomichanFormat get instance => _instance;
  static final YomichanFormat _instance = YomichanFormat._privateConstructor();

  @override
  bool shouldUseCustomDefinitionWidget(String definition) {
    try {
      jsonDecode(definition);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  String getCustomDefinitionText(String meaning) {
    final node =
        StructuredContent.processContent(jsonDecode(meaning))?.toNode();
    if (node == null) return '';

    final document = dom.Document.html('');
    document.body?.append(node);
    for (final e in document.querySelectorAll('li')) {
      final css = e.bs4.findParent('ul')?.attributes['style'] ?? '';
      final text = e.text;
      final name = css
              .split(';')
              .where((e) => e.contains('list-style-type'))
              .firstOrNull
              ?.split(':')
              .lastOrNull ??
          'square';
      final counterStyle = CounterStyleRegistry.lookup(name);
      final counter = counterStyle.generateMarkerContent(0);
      e.text = '$counter $text';
    }
    document.querySelectorAll('table').map((e) => e.remove());
    final html = document.body?.innerHtml ?? '';

    return BeautifulSoup(html).getText(separator: '\n');
  }

  /// Recursively get HTML for a structured content definition.
  static String getStructuredContentHtml(dynamic content) {
    if (content is Map) {
      return getNodeHtml(
        tag: content['tag'],
        content: getStructuredContentHtml(content['content']),
        style: getStyle(content['style'] ?? {}),
      );
    } else if (content is List) {
      return content.map(getStructuredContentHtml).join();
    }
    return content;
  }

  /// Convert style to appropriate format.
  static Map<String, String> getStyle(Map<String, dynamic> styleMap) {
    return Map<String, String>.fromEntries(
      styleMap.entries.map(
        (e) => MapEntry(ReCase(e.key).paramCase, e.value.toString()),
      ),
    );
  }

  /// Get the HTML for a certain node.
  static String getNodeHtml({
    required String content,
    String? tag,
    Map<String, String> style = const {},
  }) {
    if (tag == null) return content;
    dom.Element element = dom.Element.tag(tag);
    element.attributes.addAll(style);
    element.innerHtml = content;
    return element.outerHtml;
  }

  /// Reduce a single Yomichan term-bank glossary entry to a string. For
  /// structured-content / image entries, the content is JSON-encoded so the
  /// renderer can later parse it back. Plain-text entries are returned as
  /// their literal string. Returns null for entries we don't know how to
  /// represent.
  static String? processDefinition(var definition) {
    if (definition is String) return definition;
    if (definition is Map) {
      final type = definition['type'];
      switch (type) {
        case 'text':
          return definition['text'];
        case 'structured-content':
        case 'image':
          return jsonEncode(definition['content']);
      }
    }
    return null;
  }
}

/// Top-level: extract the source archive into a working directory.
Future<void> prepareDirectoryYomichanFormat(
    PrepareDirectoryParams params) async {
  int n = 0;
  extractZipArchiveSync(params.file, params.resourceDirectory,
      callback: (_, _) {
    n++;
    params.send(t.import_extract_count(n: n));
  });
}

/// Top-level: extract the dictionary's display name from `index.json`.
Future<String> prepareNameYomichanFormat(PrepareDirectoryParams params) async {
  final indexFilePath = path.join(params.resourceDirectory.path, 'index.json');
  final indexFile = File(indexFilePath);
  final indexJson = indexFile.readAsStringSync();
  final Map<String, dynamic> index = jsonDecode(indexJson);

  final dictionaryName = (index['title'] as String).trim();
  return dictionaryName;
}

/// Batch size for entry writes — keeps memory bounded on large dicts.
const int _kEntryWriteBatch = 1000;

/// Top-level: read all `term_bank_*.json` and `kanji_bank_*.json` files,
/// build [DictionaryEntry] rows with zstd-compressed definitions, and
/// write them to Isar in batches.
Future<void> prepareEntriesYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  // Pre-count to give the user a meaningful progress denominator.
  int total = 0;
  for (final file in files) {
    final filename = path.basename(file.path);
    if (filename.startsWith('term_bank') ||
        filename.startsWith('kanji_bank')) {
      final List<dynamic> items = jsonDecode(file.readAsStringSync());
      total += items.length;
      params.send(t.import_found_entry(count: total));
    }
  }

  int n = 0;
  final dictionaryId = params.dictionary.id;
  final pendingEntries = <DictionaryEntry>[];

  Future<void> flushPending() async {
    if (pendingEntries.isEmpty) return;
    final toWrite = List<DictionaryEntry>.from(pendingEntries);
    pendingEntries.clear();
    isar.writeTxnSync(() {
      isar.dictionaryEntrys.putAllSync(toWrite);
    });
  }

  for (final file in files) {
    final filename = path.basename(file.path);

    if (filename.startsWith('term_bank')) {
      final List<dynamic> items = jsonDecode(file.readAsStringSync());

      for (final List<dynamic> item in items) {
        final String term = item[0];
        final String reading = item[1];
        final String? spaceSeparatedDefinitionTags = item[2];
        // item[3] = ruleIdentifier — unused
        final num rawPopularity = item[4];
        final List<dynamic> rawDefinitions = item[5];
        // item[6] = sequenceNumber — unused
        final String spaceSeparatedTermTags = item[7];

        final List<String> definitions = rawDefinitions
            .map(YomichanFormat.processDefinition)
            .whereType<String>()
            .toList();

        final compressed = await DefinitionCodec.encode(definitions);

        pendingEntries.add(DictionaryEntry(
          term: term,
          reading: reading,
          dictionaryId: dictionaryId,
          popularity: rawPopularity.toDouble(),
          compressedDefinitions: compressed,
          entryTagsRaw: spaceSeparatedDefinitionTags ?? '',
          headingTagsRaw: spaceSeparatedTermTags,
        ));

        if (pendingEntries.length >= _kEntryWriteBatch) {
          await flushPending();
        }

        n++;
        if ((n & 0xFF) == 0) {
          params.send(t.import_write_entry(count: n, total: total));
        }
      }
    } else if (filename.startsWith('kanji_bank')) {
      final List<dynamic> items = jsonDecode(file.readAsStringSync());

      for (final List<dynamic> item in items) {
        final String term = item[0] as String;
        final List<String> onyomis = (item[1] as String).split(' ');
        final List<String> kunyomis = (item[2] as String).split(' ');
        final String spaceSeparatedHeadingTags = item[3] as String;
        final List<String> meanings = List<String>.from(item[4]);

        final buffer = StringBuffer();
        if (onyomis.join().trim().isNotEmpty) {
          buffer.writeln('音読み');
          for (final on in onyomis) {
            buffer.writeln('  • $on');
          }
          buffer.writeln();
        }
        if (kunyomis.join().trim().isNotEmpty) {
          buffer.writeln('訓読み');
          for (final kun in kunyomis) {
            buffer.writeln('  • $kun');
          }
          buffer.writeln();
        }
        if (meanings.isNotEmpty) {
          buffer.writeln('意味');
          for (final meaning in meanings) {
            buffer.writeln('  • $meaning');
          }
          buffer.writeln();
        }

        final definition = buffer.toString().trim();
        if (definition.isEmpty) continue;

        final compressed = await DefinitionCodec.encode([definition]);

        pendingEntries.add(DictionaryEntry(
          term: term,
          reading: '',
          dictionaryId: dictionaryId,
          popularity: 0,
          compressedDefinitions: compressed,
          headingTagsRaw: spaceSeparatedHeadingTags,
        ));

        if (pendingEntries.length >= _kEntryWriteBatch) {
          await flushPending();
        }

        n++;
        if ((n & 0xFF) == 0) {
          params.send(t.import_write_entry(count: n, total: total));
        }
      }
    }
  }

  await flushPending();
  params.send(t.import_write_entry(count: n, total: total));
}

/// Top-level: read all `tag_bank_*.json` files and write [DictionaryTag]
/// rows. Tags are small and few, so a single transaction is fine.
Future<void> prepareTagsYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  // Pre-count for progress.
  int count = 0;
  for (final file in files) {
    final filename = path.basename(file.path);
    if (filename.startsWith('tag_bank')) {
      final List<dynamic> items = jsonDecode(file.readAsStringSync());
      count += items.length;
      params.send(t.import_found_tag(count: count));
    }
  }

  final dictionaryId = params.dictionary.id;
  final tags = <DictionaryTag>[];

  for (final file in files) {
    final filename = path.basename(file.path);
    if (!filename.startsWith('tag_bank')) continue;

    final List<dynamic> items = jsonDecode(file.readAsStringSync());

    for (final List<dynamic> item in items) {
      tags.add(DictionaryTag(
        dictionaryId: dictionaryId,
        name: item[0] as String,
        category: item[1] as String,
        sortingOrder: item[2] as int,
        notes: item[3] as String,
        popularity: (item[4] as num).toDouble(),
      ));
    }
  }

  isar.writeTxnSync(() {
    isar.dictionaryTags.putAllSync(tags);
  });

  params.send(t.import_write_tag(count: tags.length, total: count));
}

/// Top-level: read all `term_meta_bank_*.json` files for `pitch` mode and
/// write [DictionaryPitch] rows.
Future<void> preparePitchesYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  // Pre-count meta items for progress.
  int count = 0;
  for (final file in files) {
    final filename = path.basename(file.path);
    if (filename.startsWith('term_meta_bank')) {
      final List<dynamic> items = jsonDecode(file.readAsStringSync());
      count += items.length;
      params.send(t.import_found_pitch(count: count));
    }
  }

  final dictionaryId = params.dictionary.id;
  final pitches = <DictionaryPitch>[];

  for (final file in files) {
    final filename = path.basename(file.path);
    if (!filename.startsWith('term_meta_bank')) continue;

    final List<dynamic> items = jsonDecode(file.readAsStringSync());

    for (final List<dynamic> item in items) {
      final String term = item[0] as String;
      final String type = item[1] as String;
      if (type != 'pitch') continue;

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(item[2] as Map);
      final String reading = data['reading'] ?? '';

      final List<Map<String, dynamic>> distinctPitchJsons =
          List<Map<String, dynamic>>.from(data['pitches']);
      for (final distinctPitch in distinctPitchJsons) {
        pitches.add(DictionaryPitch(
          term: term,
          reading: reading,
          dictionaryId: dictionaryId,
          downstep: distinctPitch['position'] as int,
        ));
      }
    }
  }

  isar.writeTxnSync(() {
    isar.dictionaryPitchs.putAllSync(pitches);
  });

  params.send(t.import_write_pitch(count: pitches.length, total: count));
}

/// Top-level: read all `term_meta_bank_*.json` files for `freq` mode and
/// write [DictionaryFrequency] rows.
Future<void> prepareFrequenciesYomichanFormat({
  required PrepareDictionaryParams params,
  required Isar isar,
}) async {
  final List<FileSystemEntity> entities = params.resourceDirectory.listSync();
  final Iterable<File> files = entities.whereType<File>();

  // Pre-count for progress.
  int count = 0;
  for (final file in files) {
    final filename = path.basename(file.path);
    if (filename.startsWith('term_meta_bank')) {
      final List<dynamic> items = jsonDecode(file.readAsStringSync());
      count += items.length;
      params.send(t.import_found_frequency(count: count));
    }
  }

  final dictionaryId = params.dictionary.id;
  final frequencies = <DictionaryFrequency>[];

  for (final file in files) {
    final filename = path.basename(file.path);
    if (!filename.startsWith('term_meta_bank')) continue;

    final List<dynamic> items = jsonDecode(file.readAsStringSync());

    for (final List<dynamic> item in items) {
      final String term = item[0] as String;
      final String type = item[1] as String;
      if (type != 'freq') continue;

      // The Yomichan term-meta freq format has many shapes.
      String reading = '';
      double value = 0;
      String displayValue = '';

      final raw = item[2];
      if (raw is num) {
        value = raw.toDouble();
        displayValue = (raw % 1 == 0)
            ? raw.toInt().toString()
            : raw.toString();
      } else if (raw is Map) {
        final data = Map<String, dynamic>.from(raw);
        reading = data['reading'] ?? '';

        if (data['frequency'] is Map) {
          final freq = Map<String, dynamic>.from(data['frequency']);
          final num n = freq['value'] ?? 0;
          value = n.toDouble();
          displayValue = (freq['displayValue'] as String?) ??
              (n % 1 == 0 ? n.toInt().toString() : n.toString());
        } else if (data['displayValue'] != null) {
          final num n = data['value'] ?? 0;
          value = n.toDouble();
          displayValue = data['displayValue'] as String;
        } else if (data['value'] != null) {
          final num n = data['value'];
          value = n.toDouble();
          displayValue = n.toInt().toString();
        } else if (data['frequency'] is num) {
          final num n = data['frequency'];
          value = n.toDouble();
          displayValue =
              n % 1 == 0 ? n.toInt().toString() : n.toString();
        }
      } else {
        displayValue = raw.toString();
      }

      frequencies.add(DictionaryFrequency(
        term: term,
        reading: reading,
        dictionaryId: dictionaryId,
        value: value,
        displayValue: displayValue,
      ));
    }
  }

  isar.writeTxnSync(() {
    isar.dictionaryFrequencys.putAllSync(frequencies);
  });

  params.send(
      t.import_write_frequency(count: frequencies.length, total: count));
}
