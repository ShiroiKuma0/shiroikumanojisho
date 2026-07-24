// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/docs/development/packages-and-plugins/developing-packages#plugin-platforms.

import 'dart:typed_data';

import 'document_file_save_plus_platform_interface.dart';

class DocumentFileSavePlus {
  Future<String?> get platformVersion {
    return DocumentFileSavePlusPlatform.instance.platformVersion;
  }

  Future<int?> get batteryPercentage {
    return DocumentFileSavePlusPlatform.instance.batteryPercentage;
  }

  Future<void> saveMultipleFiles({
    List<Uint8List>? dataList,
    required List<String> fileNameList,
    required List<String> mimeTypeList,
  }) async {
    return DocumentFileSavePlusPlatform.instance.saveMultipleFiles(
      dataList: dataList,
      fileNameList: fileNameList,
      mimeTypeList: mimeTypeList,
    );
  }

  Future<void> saveFile(
    Uint8List data,
    String fileName,
    String mimeType,
  ) async {
    return DocumentFileSavePlusPlatform.instance.saveMultipleFiles(
      dataList: [data],
      fileNameList: [fileName],
      mimeTypeList: [mimeType],
    );
  }
}
