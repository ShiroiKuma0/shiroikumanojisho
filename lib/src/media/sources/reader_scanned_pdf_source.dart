import 'dart:io';

import 'package:filesystem_picker/filesystem_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';
import 'package:path/path.dart' as path;

import 'package:shiroikumanojisho/media.dart';
import 'package:shiroikumanojisho/models.dart';
import 'package:shiroikumanojisho/pages.dart';
import 'package:shiroikumanojisho/src/utils/ocr/pdf_ocr_importer.dart';
import 'package:shiroikumanojisho/utils.dart';

/// A media source that imports scanned (image-only) PDFs, OCRs each
/// page on-device, and reads the result as a mokuro-style volume: the
/// original page image with an invisible, tappable text overlay.
///
/// Extends [ReaderMokuroSource] because a generated volume *is* a
/// legacy-mokuro HTML file — display, tap-lookup, settings, and card
/// image mining are all inherited from the mokuro pipeline. Only the
/// identity and the import flow differ. Viewer-behaviour settings
/// delegate to [ReaderMokuroSource.instance] so both sources share one
/// set of toggles (and the same tweaks dialog).
class ReaderScannedPdfSource extends ReaderMokuroSource {
  /// Define this media source.
  ReaderScannedPdfSource._privateConstructor()
      : super.forSubclass(
          uniqueKey: 'reader_scanned_pdf',
          sourceName: 'Scanned PDF',
          description: 'Import a scanned PDF and study it with an on-device '
              'OCR text overlay.',
          icon: Icons.picture_as_pdf,
        );

  /// Get the singleton instance of this media type.
  static ReaderScannedPdfSource get instance => _instance;

  static final ReaderScannedPdfSource _instance =
      ReaderScannedPdfSource._privateConstructor();

  @override
  bool get volumePageTurningEnabled =>
      ReaderMokuroSource.instance.volumePageTurningEnabled;

  @override
  bool get volumePageTurningInverted =>
      ReaderMokuroSource.instance.volumePageTurningInverted;

  @override
  bool get extendPageBeyondNavigationBar =>
      ReaderMokuroSource.instance.extendPageBeyondNavigationBar;

  @override
  bool get highlightOnTap => ReaderMokuroSource.instance.highlightOnTap;

  @override
  bool get useDarkTheme => ReaderMokuroSource.instance.useDarkTheme;

  @override
  Future<void> onSearchBarTap({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) async {
    launchPdfPicker(context: context, ref: ref, appModel: appModel);
  }

  @override
  BasePage buildHistoryPage({MediaItem? item}) {
    return const ReaderScannedPdfHistoryPage();
  }

  @override
  List<Widget> getActions({
    required BuildContext context,
    required WidgetRef ref,
    required AppModel appModel,
  }) {
    return [
      buildTweaksButton(context: context, ref: ref, appModel: appModel),
      buildImportPdfButton(context: context, ref: ref, appModel: appModel),
    ];
  }

  /// Menu bar action.
  Widget buildImportPdfButton(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) {
    return FloatingSearchBarAction(
      child: JidoujishoIconButton(
        size: Theme.of(context).textTheme.titleLarge?.fontSize,
        tooltip: t.pick_file,
        icon: Icons.upload_file,
        onTap: () async {
          launchPdfPicker(
            context: context,
            ref: ref,
            appModel: appModel,
          );
        },
      ),
    );
  }

  /// Launches a file picker for a PDF, runs the OCR import, and opens
  /// the generated volume.
  void launchPdfPicker(
      {required BuildContext context,
      required WidgetRef ref,
      required AppModel appModel}) async {
    List<Directory> rootDirectories =
        await appModel.getFilePickerDirectoriesForMediaType(mediaType);

    Iterable<String>? filePaths;
    if (context.mounted) {
      filePaths = await FilesystemPicker.open(
        allowedExtensions: ['.pdf'],
        context: context,
        rootDirectories: rootDirectories,
        fsType: FilesystemType.file,
        title: '',
        pickText: t.dialog_select,
        cancelText: t.dialog_cancel,
        themeData: Theme.of(context),
        folderIconColor: Theme.of(context).colorScheme.primary,
      );
    }

    if (filePaths == null || filePaths.isEmpty) {
      return;
    }

    String filePath = filePaths.first;
    appModel.setLastPickedDirectory(
      type: ReaderMediaType.instance,
      directory: Directory(path.dirname(filePath)),
    );

    if (!context.mounted) {
      return;
    }
    MediaItem? item = await PdfOcrImporter.importPdf(
      appModel: appModel,
      context: context,
      pdfFile: File(filePath),
      mediaSource: this,
    );
    if (item == null) {
      return;
    }

    appModel.openMedia(
      item: item,
      ref: ref,
      mediaSource: this,
    );
  }
}
