import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:path/path.dart' as path;
import 'package:shiroikumanojisho/dictionary.dart';
import 'package:shiroikumanojisho/language.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/utils.dart';

/// Provides and caches the processed HTML of a [DictionaryEntry] to improve
/// performance.
final dictionaryEntryHtmlProvider =
    Provider.family<String, DictionaryEntry>((ref, entry) {
  return entry.definitions
      .map((e) {
        try {
          final node =
              StructuredContent.processContent(jsonDecode(e))?.toNode();
          if (node == null) {
            return '';
          }

          final document = dom.Document.html('');
          document.body?.append(node);
          final html = document.body?.innerHtml ?? '';

          return html;
        } catch (_) {
          return e.replaceAll('\n', '<br>');
        }
      })
      .toList()
      .join('<br>');
});

/// Get the [Directory] used as a resource directory for a certain [Dictionary].
final dictionaryResourceDirectoryProvider =
    Provider.family<Directory, int>((ref, dictionaryId) {
  final appModel = ref.watch(appProvider);

  return Directory(
      path.join(appModel.dictionaryResourceDirectory.path, '$dictionaryId'));
});

/// Provides the same HTML as [dictionaryEntryHtmlProvider] but with every
/// word in its visible text nodes wrapped in a <scanword> element so each
/// word becomes individually tappable for recursive dictionary lookup.
/// Segmentation uses the active [Language.textToWords] so Japanese goes
/// through Mecab and Latin-script languages through their whitespace
/// splitter. Tokens that contain no Japanese-script character are left as
/// plain text — they would never resolve to a Japanese dictionary entry
/// and wrapping them would just clutter the tap surface.
///
/// The output renders visually identical to the base HTML because
/// <scanword> is a custom tag that flutter_html ignores unless a matching
/// [TagExtension] is registered; that extension returns a [GestureDetector]
/// around a plain [Text] that inherits the surrounding body style.
final dictionaryEntryScannedHtmlProvider =
    Provider.family<String, DictionaryEntry>((ref, entry) {
  final baseHtml = ref.watch(dictionaryEntryHtmlProvider(entry));
  final language = ref.watch(appProvider).targetLanguage;
  try {
    return _injectScanWords(baseHtml, language);
  } catch (_) {
    // If anything about the DOM walk or segmenter fails, fall back to
    // the unmodified HTML so the entry still renders.
    return baseHtml;
  }
});

/// Walks [html] as a DOM fragment and returns a copy with every visible
/// text node segmented via [language] and each Japanese-script token
/// wrapped in a <scanword> element.
String _injectScanWords(String html, Language language) {
  // html: 0.15.2 exposes innerHtml as a getter on Element only;
  // DocumentFragment doesn't have it. Parsing via Document.html wraps
  // loose content in an auto-generated <html><body> and gives us a
  // proper body Element to walk and serialize, which is the same
  // pattern dictionaryEntryHtmlProvider already uses above.
  final document = dom.Document.html(html);
  final body = document.body;
  if (body == null) {
    return html;
  }
  _walkAndInject(body, language);
  return body.innerHtml;
}

void _walkAndInject(dom.Node node, Language language) {
  // Copy to a list because _replaceTextNode mutates node.nodes during
  // iteration; iterating the live collection would miss siblings.
  final children = List<dom.Node>.from(node.nodes);
  for (final child in children) {
    if (child is dom.Text) {
      if (child.data.trim().isEmpty) {
        continue;
      }
      _replaceTextNode(child, language);
    } else if (child is dom.Element) {
      final tag = child.localName?.toLowerCase();
      // Skip descendants of anchors (preserve existing cross-reference
      // behaviour), script/style (no visible text), and <scanword>
      // itself (keeps the walk idempotent).
      if (tag == 'a' ||
          tag == 'script' ||
          tag == 'style' ||
          tag == 'scanword') {
        continue;
      }
      _walkAndInject(child, language);
    }
  }
}

void _replaceTextNode(dom.Text textNode, Language language) {
  final parent = textNode.parent;
  if (parent == null) {
    return;
  }

  final tokens = language.textToWords(textNode.data);
  if (tokens.isEmpty) {
    return;
  }

  final replacements = <dom.Node>[];
  for (final token in tokens) {
    // Tokens from textToWords may embed leading or trailing whitespace /
    // punctuation (Mecab keeps delimiters attached to the preceding
    // word). Peel those off so the <scanword> element holds only the
    // word itself and the surrounding whitespace stays as plain text.
    // Concatenating all replacements reconstructs the original string
    // byte-for-byte, so the rendered layout is unchanged.
    final trimmedRight = token.trimRight();
    final trailing = token.substring(trimmedRight.length);
    final trimmed = trimmedRight.trimLeft();
    final leading =
        trimmedRight.substring(0, trimmedRight.length - trimmed.length);

    if (leading.isNotEmpty) {
      replacements.add(dom.Text(leading));
    }
    if (trimmed.isEmpty) {
      // Whole token was whitespace; leading already captured it.
    } else if (_containsJapanese(trimmed)) {
      replacements.add(dom.Element.tag('scanword')..text = trimmed);
    } else {
      replacements.add(dom.Text(trimmed));
    }
    if (trailing.isNotEmpty) {
      replacements.add(dom.Text(trailing));
    }
  }

  final idx = parent.nodes.indexOf(textNode);
  parent.nodes.removeAt(idx);
  parent.nodes.insertAll(idx, replacements);
}

/// True if [text] contains at least one character in the Japanese writing
/// system (hiragana, katakana, or CJK unified ideographs and common
/// extensions). Used to decide whether a segmented token should become a
/// tappable scan word.
bool _containsJapanese(String text) {
  for (final code in text.runes) {
    if ((code >= 0x3040 && code <= 0x30FF) || // Hiragana + Katakana
        (code >= 0x4E00 && code <= 0x9FFF) || // CJK Unified Ideographs
        (code >= 0x3400 && code <= 0x4DBF) || // CJK Extension A
        (code >= 0xF900 && code <= 0xFAFF) || // CJK Compatibility Ideographs
        (code >= 0x31F0 && code <= 0x31FF)) { // Katakana Phonetic Extensions
      return true;
    }
  }
  return false;
}

/// HTML renderer for dictionary definitions.
class DictionaryHtmlWidget extends ConsumerWidget {
  /// Create an instance of this page.
  const DictionaryHtmlWidget({
    required this.entry,
    required this.onSearch,
    super.key,
  });

  /// Dictionary entry to be rendered.
  final DictionaryEntry entry;

  /// Action to be done upon selecting the search option.
  final Function(String) onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textColor = Color(ref.read(appProvider).dictionaryFontColor);
    final linkColor = Theme.of(context).colorScheme.error;
    final dictionaryFontSize = ref.read(appProvider).dictionaryFontSize;
    final fontSize = FontSize(dictionaryFontSize);
    const tableWidth = 0.3;
    final tableBorder = Border.all(color: textColor, width: tableWidth);
    final tableStyle = Style(
      border: tableBorder,
    );

    return Html(
      data: ref.watch(dictionaryEntryScannedHtmlProvider(entry)),
      shrinkWrap: true,
      onAnchorTap: (url, attributes, element) {
        onSearch.call(attributes['query'] ?? element?.text ?? 'f');
      },
      style: {
        '*': Style(
          fontSize: fontSize,
          color: textColor,
        ),
        'td': tableStyle,
        'th': tableStyle,
        'ul': Style(
          padding: HtmlPaddings.zero,
        ),
        'li': Style(
          padding: HtmlPaddings.zero,
        ),
        'a': Style(color: linkColor),
      },
      extensions: [
        const TableHtmlExtension(),
        ImageExtension.inline(
          networkSchemas: {'jidoujisho'},
          builder: (extensionContext) => WidgetSpan(
            child: JidoujishoDictionaryImage(
              entry: entry,
              extensionContext: extensionContext,
            ),
          ),
        ),
        // Makes every Japanese word previously wrapped by
        // _injectScanWords tappable. The rendered Text inherits the
        // surrounding body style (colour, size, weight, italic) via
        // styledElement.style.generateTextStyle(), so visually the
        // word looks exactly like the plain text it replaced — no
        // underline, no colour change. Tap dispatches to the same
        // onSearch callback the cross-reference anchors use, giving
        // identical recursive-lookup behaviour.
        TagExtension(
          tagsToExtend: const {'scanword'},
          builder: (ctx) {
            final word = ctx.innerHtml;
            return GestureDetector(
              onTap: () => onSearch(word),
              child: Text(
                word,
                style: ctx.styledElement?.style.generateTextStyle(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Handles image rendering of images in a dictionary definition.
class JidoujishoDictionaryImage extends ConsumerWidget {
  /// Initialise this widget.
  const JidoujishoDictionaryImage({
    required this.entry,
    required this.extensionContext,
    super.key,
  });

  /// Dictionary entry to be rendered.
  final DictionaryEntry entry;

  /// Provides attributes for building the image.
  final ExtensionContext extensionContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = (extensionContext.attributes['src'] ?? '')
        .replaceFirst('jidoujisho://', '');

    final width = double.tryParse((extensionContext.attributes['width'] ?? '')
        .replaceAll(RegExp(r'\D'), ''));
    final height = double.tryParse((extensionContext.attributes['height'] ?? '')
        .replaceAll(RegExp(r'\D'), ''));

    final directory = ref
        .read(dictionaryResourceDirectoryProvider(entry.dictionary.value!.id));
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.file(
          File(path.join(directory.path, src)),
          height: height,
          width: width,
          scale: 3,
        )
      ],
    );
  }
}

/// Special delegate for text selection from a dictionary search result.
class DictionarySelectionDelegate
    extends MultiSelectableSelectionContainerDelegate {
  /// Initialise this widget.
  DictionarySelectionDelegate({
    required this.onTextSelectionGuessLength,
  });

  /// Callback with a [JidoujishoTextSelection] which contains the text of all
  /// selectables as well as a [TextRange] representing the substring to use
  /// for dictionary search. Returns the guess length of the text selection.
  final JidoujishoTextSelection Function(JidoujishoTextSelection)
      onTextSelectionGuessLength;

  // This method is called when newly added selectable is in the current
  // selected range.
  @override
  void ensureChildUpdated(Selectable selectable) {}

  /// Handles a [JidoujishoTextSelection].
  SelectionResult handleTextSelection(
      SelectWordSelectionEvent event, JidoujishoTextSelection selection) {
    handleClearSelection(const ClearSelectionEvent());

    super.handleSelectWord(event);
    while ((getSelectedContent()?.plainText ?? '').length > 1) {
      super.handleGranularlyExtendSelection(
        const GranularlyExtendSelectionEvent(
            forward: false,
            isEnd: true,
            granularity: TextGranularity.character),
      );
    }

    final highlightLength = selection.textInside.length;

    SelectionResult? result;
    for (int i = 0; i < highlightLength - 1; i++) {
      result = super.handleGranularlyExtendSelection(
        const GranularlyExtendSelectionEvent(
          forward: true,
          isEnd: true,
          granularity: TextGranularity.character,
        ),
      );
    }

    return result ?? super.handleSelectWord(event);
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    // _expectSearchSelection = event is SelectWordSelectionEvent;
    return super.dispatchSelectionEvent(event);
  }

  //  bool _expectSearchSelection = false;
  SelectionEvent? _lastEvent;
  JidoujishoTextSelection? _guessSelection;
  JidoujishoTextSelection? _searchSelection;

  @override
  SelectionResult handleSelectWord(SelectWordSelectionEvent event) {
    if (_searchSelection != null && _lastEvent == event) {
      final selection = _searchSelection;
      _searchSelection = null;

      final startDiff = selection!.range.start - _guessSelection!.range.start;
      final endDiff = selection.range.end - _guessSelection!.range.end;

      SelectionResult? result;
      for (int i = 0; i < startDiff.abs(); i++) {
        result = super.handleGranularlyExtendSelection(
          GranularlyExtendSelectionEvent(
            forward: !startDiff.isNegative,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
      }

      for (int i = 0; i < endDiff.abs(); i++) {
        result = super.handleGranularlyExtendSelection(
          GranularlyExtendSelectionEvent(
            forward: !endDiff.isNegative,
            isEnd: true,
            granularity: TextGranularity.character,
          ),
        );
      }

      return result!;
    }

    super.handleSelectWord(event);
    _lastEvent = event;
    // _expectSearchSelection = true;

    if (!(currentSelectionEndIndex < selectables.length &&
        currentSelectionEndIndex >= 0)) {
      return handleClearSelection(const ClearSelectionEvent());
    }

    handleGranularlyExtendSelection(
      const GranularlyExtendSelectionEvent(
        forward: false,
        isEnd: true,
        granularity: TextGranularity.document,
      ),
    );

    handleClearSelection(const ClearSelectionEvent());

    final textBefore = getSelectedContent()?.plainText ?? '';

    super.handleSelectWord(event);
    handleGranularlyExtendSelection(
      const GranularlyExtendSelectionEvent(
        forward: true,
        isEnd: true,
        granularity: TextGranularity.document,
      ),
    );

    final textAfter = getSelectedContent()?.plainText ?? '';

    final text = '$textBefore$textAfter';

    final eventSelection = JidoujishoTextSelection(
      text: text,
      range: TextRange(
        start: textBefore.length,
        end: text.length,
      ),
    );

    late SelectionResult result;
    final guessSelection = onTextSelectionGuessLength(eventSelection);
    result = handleTextSelection(event, guessSelection);

    // onTextSelectionSearchLength(eventSelection, (searchSelection) {
    //   _guessSelection = guessSelection;
    //   _searchSelection = searchSelection;
    //   if (getSelectedContent()?.plainText == guessSelection.textInside &&
    //       searchSelection.textInside != guessSelection.textInside) {
    //     dispatchSelectionEvent(event);
    //   }
    // });

    return result;
  }
}
