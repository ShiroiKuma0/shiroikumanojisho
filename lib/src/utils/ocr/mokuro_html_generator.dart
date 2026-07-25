import 'package:flutter/services.dart' show rootBundle;
import 'package:shiroikumanojisho/pages.dart' show MokuroCatalogBrowsePage;
import 'package:shiroikumanojisho/src/pages/implementations/mokuro_catalog_browse_page.dart' show MokuroCatalogBrowsePage;

import 'package:shiroikumanojisho/src/utils/misc/mokuro_payload.dart';

/// Generates a self-contained legacy-mokuro HTML volume from a
/// [MokuroPayload]. This is a Dart port of mokuro 0.2.5's
/// `legacy/overlay_generator.py` (GPL-3, kha-white/mokuro — same licence
/// family as this app), kept structurally identical so the output is
/// bit-compatible with what [MokuroCatalogBrowsePage] and its injected
/// tap-lookup JS were written against: `.pageContainer` divs with
/// unitless style dimensions (the file deliberately has no doctype, so
/// quirks mode accepts them, exactly like real mokuro output),
/// `.textBox` overlays with `<p>` lines, the `#popupAbout` marker, and
/// mokuro's own embedded `script.js` runtime (`state`, `updatePage`,
/// `storageKey`) that the app drives for paging and progress saving.
///
/// The runtime assets are vendored under `assets/mokuro-template/`.
class MokuroHtmlGenerator {
  static const String _templateRoot = 'assets/mokuro-template';

  static const List<String> _menuIcons = [
    'cross-svgrepo-com',
    'chevron-left-double-svgrepo-com',
    'chevron-left-svgrepo-com',
    'chevron-right-svgrepo-com',
    'chevron-right-double-svgrepo-com',
    'menu-hamburger-svgrepo-com',
    'expand-svgrepo-com',
    'expand-width-svgrepo-com',
    'fullscreen-svgrepo-com',
  ];

  /// Build the complete volume HTML for [payload], titled [title].
  /// Image URLs inside the payload must already be relative to where
  /// the HTML file will be written.
  static Future<String> generate({
    required MokuroPayload payload,
    required String title,
  }) async {
    final styles = await rootBundle.loadString('$_templateRoot/styles.css');
    final panzoom = await rootBundle.loadString('$_templateRoot/panzoom.min.js');
    final script = await rootBundle.loadString('$_templateRoot/script.js');
    final icons = <String, String>{};
    for (final icon in _menuIcons) {
      icons[icon] = await rootBundle.loadString('$_templateRoot/icons/$icon.svg');
    }

    final buffer = StringBuffer();
    // No doctype on purpose: quirks mode makes the unitless CSS lengths
    // in the generated style attributes valid, matching real mokuro.
    buffer
      ..write('<html>')
      ..write('<meta content="text/html;charset=utf-8" '
          'http-equiv="Content-Type">')
      ..write('<meta content="utf-8" http-equiv="encoding">')
      ..write('<meta name="viewport" content="width=device-width, '
          'initial-scale=1, minimum-scale=1, user-scalable=no"/>')
      ..write('<head><title>${_escape(title)} | mokuro</title>')
      ..write('<style>$styles</style></head>')
      ..write('<body>');

    _writeTopMenu(buffer, icons, payload.images.length);

    buffer
      ..write('<div id="dimOverlay"></div>')
      ..write('<div id="popupAbout" class="popup">'
          '<p>HTML overlay generated on-device by 白い熊 辞書 '
          '(shiroikumanojisho) from a scanned PDF, in the format of '
          '<a href="https://github.com/kha-white/mokuro" target="_blank">'
          'mokuro</a> 0.2.5.</p>'
          '<p>Text is the result of on-device OCR and may contain '
          'recognition errors.</p>'
          '</div>')
      ..write('<a id="leftAScreen" href="#"></a>')
      ..write('<a id="rightAScreen" href="#"></a>')
      ..write('<div id="pagesContainer">');

    for (var i = 0; i < payload.images.length; i++) {
      buffer.write('<div id="page$i" class="page">');
      _writePage(buffer, payload.images[i]);
      buffer.write('</div>');
    }

    buffer
      ..write('<a id="leftAPage" href="#"></a>')
      ..write('<a id="rightAPage" href="#"></a>')
      ..write('</div>')
      ..write('<script>$panzoom</script>')
      ..write('<script>$script</script>')
      ..write('</body></html>');

    return buffer.toString();
  }

  static void _writeTopMenu(
    StringBuffer buffer,
    Map<String, String> icons,
    int numPages,
  ) {
    String button(String id, String icon) =>
        '<button id="$id" class="menuButton">${icons[icon]}</button>';
    String toggle(String id, String label) =>
        '<label class="dropdown-option">$label'
        '<input type="checkbox" id="$id"></label>';

    buffer
      ..write('<a id="showMenuA" href="#"></a>')
      ..write('<div id="topMenu">')
      ..write(button('buttonHideMenu', 'cross-svgrepo-com'))
      ..write(button('buttonLeftLeft', 'chevron-left-double-svgrepo-com'))
      ..write(button('buttonLeft', 'chevron-left-svgrepo-com'))
      ..write(button('buttonRight', 'chevron-right-svgrepo-com'))
      ..write(button('buttonRightRight', 'chevron-right-double-svgrepo-com'))
      ..write('<input required type="number" id="pageIdxInput" min="1" '
          'max="$numPages" value="1" size="3">')
      ..write('<span id="pageIdxDisplay"></span>')
      // Mokuro's workaround for dictionary tools including the menu bar
      // in mined sentences; kept for output parity.
      ..write('<span style="color:rgba(255,255,255,0.1);font-size:1px;">'
          '。</span>')
      ..write('<div class="dropdown">')
      ..write('<button id="dropbtn" class="menuButton">'
          '${icons['menu-hamburger-svgrepo-com']}</button>')
      ..write('<div class="dropdown-content">')
      ..write('<div class="buttonRow">')
      ..write(button('menuFitToScreen', 'expand-svgrepo-com'))
      ..write(button('menuFitToWidth', 'expand-width-svgrepo-com'))
      ..write('<button id="menuOriginalSize" class="menuButton">1:1</button>')
      ..write(button('menuFullScreen', 'fullscreen-svgrepo-com'))
      ..write('</div>')
      ..write('<label class="dropdown-option">on page turn: '
          '<select id="menuDefaultZoom">'
          '<option value="fit to screen">fit to screen</option>'
          '<option value="fit to width">fit to width</option>'
          '<option value="original size">original size</option>'
          '<option value="keep zoom level">keep zoom level</option>'
          '</select></label>')
      ..write(toggle('menuR2l', 'right to left'))
      ..write(toggle('menuDoublePageView', 'display two pages '))
      ..write(toggle('menuHasCover', 'first page is cover '))
      ..write(toggle('menuCtrlToPan', 'ctrl+mouse to move '))
      ..write(toggle('menuDisplayOCR', 'OCR enabled '))
      ..write(toggle('menuTextBoxBorders', 'display boxes outlines '))
      ..write(toggle('menuEditableText', 'editable text '))
      ..write('<label class="dropdown-option">font size: '
          '<select id="menuFontSize">'
          '${['auto', 9, 10, 11, 12, 14, 16, 18, 20, 24, 32, 40, 48, 60].map((v) => '<option value="$v">$v</option>').join()}'
          '</select></label>')
      ..write(toggle('menuEInkMode', 'e-ink mode '))
      ..write(toggle('menuToggleOCRTextBoxes', 'toggle OCR text boxes on click'))
      ..write('<label class="dropdown-option">background color'
          '<input type="color" value="#C4C3D0" id="menuBackgroundColor">'
          '</label>')
      ..write('<a href="#" class="dropdown-option" id="menuReset">'
          'reset settings</a>')
      ..write('<a href="#" class="dropdown-option" id="menuAbout">'
          'about/help</a>')
      ..write('</div></div>')
      ..write('</div>');
  }

  static void _writePage(StringBuffer buffer, MokuroImage image) {
    final width = image.size.width.round();
    final height = image.size.height.round();

    // Mokuro stacks smaller boxes above larger ones so they stay
    // reachable: z-index is the block's rank by area, largest first,
    // offset by 10.
    final indexed = image.blocks.toList();
    final byAreaDesc = indexed.toList()
      ..sort((a, b) => (b.rectangle.width * b.rectangle.height)
          .compareTo(a.rectangle.width * a.rectangle.height));
    final zIndexes = <MokuroBlock, int>{};
    for (var rank = 0; rank < byAreaDesc.length; rank++) {
      zIndexes[byAreaDesc[rank]] = rank + 10;
    }

    buffer.write('<div class="pageContainer" style="width:$width; '
        'height:$height; background-image:url(&quot;${image.url}&quot;);">');
    for (final block in indexed) {
      final left = block.rectangle.left.round();
      final top = block.rectangle.top.round();
      final blockWidth = block.rectangle.width.round();
      final blockHeight = block.rectangle.height.round();
      final fontSize = block.fontSize.toStringAsFixed(0);
      final writingMode =
          block.isVertical ? ' writing-mode:vertical-rl;' : '';

      buffer.write('<div class="textBox" style="left:$left; top:$top; '
          'width:$blockWidth; height:$blockHeight; '
          'font-size:${fontSize}px; z-index:${zIndexes[block]};'
          '$writingMode">');
      for (final line in block.lines) {
        buffer.write('<p>${_escape(line)}</p>');
      }
      buffer.write('</div>');
    }
    buffer.write('</div>');
  }

  static String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
