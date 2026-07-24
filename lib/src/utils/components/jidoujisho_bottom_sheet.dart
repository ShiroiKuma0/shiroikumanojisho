import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shiroikumanojisho/models.dart';

/// An option to show in a bottom sheet.
class JidoujishoBottomSheetOption {
  /// Defines an option in a bottom sheet.
  JidoujishoBottomSheetOption({
    required this.label,
    required this.icon,
    required this.action,
    this.active = false,
    this.iconColor,
  });

  /// Label to display in the option.
  String label;

  /// Icon to display left of the label.
  IconData icon;

  /// Whether or not the option is available.
  bool active;

  /// Overrides the default (red) icon colour — e.g. the green tick on
  /// an already-OCRed subtitle track.
  Color? iconColor;

  /// Action to perform upon selecting the option.
  FutureOr<void> Function() action;
}

///
class JidoujishoBottomSheet extends ConsumerWidget {
  /// Initialise a bottom sheet.
  const JidoujishoBottomSheet({
    required this.options,
    this.scrollToExtent = true,
    super.key,
  });

  /// Options to show in the bottom sheet.
  final List<JidoujishoBottomSheetOption> options;

  /// Whether or not to scroll to bottom.
  final bool scrollToExtent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppModel appModel = ref.watch(appProvider);

    ScrollController scrollController = ScrollController();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && scrollToExtent) {
        scrollController.jumpTo(
          scrollController.position.maxScrollExtent,
        );
      }
    });

    // The sheet carries the black/yellow identity like dialogs do:
    // yellow rounded border around the whole panel (dark theme).
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: appModel.isDarkMode
            ? Border.all(color: Colors.yellow, width: 2)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
      controller: scrollController,
      shrinkWrap: true,
      itemCount: options.length,
      itemBuilder: (context, i) {
        JidoujishoBottomSheetOption option = options[i];

        // Rows are yellow by default so the red active row (text, icon,
        // and trailing check) actually stands out — previously every
        // row's icon was red and the active highlight drowned.
        final Color rowColor = option.active
            ? Colors.red
            : appModel.isDarkMode
                ? Colors.yellow
                : Colors.black;
        return ListTile(
          tileColor: Theme.of(context).cardColor,
          dense: true,
          leading: Icon(
            option.icon,
            size: 20,
            color: option.iconColor ?? rowColor,
          ),
          title: Text(
            option.label,
            maxLines: 1,
            style: TextStyle(
              color: rowColor,
            ),
          ),
          trailing: option.active
              ? const Icon(Icons.check, size: 20, color: Colors.red)
              : null,
          onTap: () async {
            Navigator.of(context).pop();
            await option.action();
          },
        );
      },
      ),
    );
  }
}
