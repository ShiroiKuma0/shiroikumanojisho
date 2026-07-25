import 'package:flutter/material.dart';
import 'package:shiroikumanojisho/src/pages/base_source_page.dart';
import 'package:shiroikumanojisho/utils.dart';

/// The media page used for unimplemented sources.
class PlaceholderSourcePage extends BaseSourcePage {
  /// Create an instance of this page.
  const PlaceholderSourcePage({
    super.item,
    super.key,
  });

  @override
  BaseSourcePageState createState() => _PlaceholderSourcePage();
}

class _PlaceholderSourcePage extends BaseSourcePageState {
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // Semantic port of the old WillPopScope contract: the
      // per-page onWillPop() decides whether the route pops,
      // and may consume the back press (dictionary dismiss,
      // exit-media confirm, killOnPop shutdown) by returning
      // false.
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final navigator = Navigator.of(context);
        if (await onWillPop() && mounted) {
          navigator.pop(result);
        }
      },
      child: Scaffold(
        body: Center(
          child: buildPlaceholder(),
        ),
      ),
    );
  }

  Widget buildPlaceholder() {
    return JidoujishoPlaceholderMessage(
      icon: Icons.construction,
      message: t.unimplemented_source,
    );
  }
}
