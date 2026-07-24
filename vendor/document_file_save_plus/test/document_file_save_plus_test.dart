import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:document_file_save_plus/document_file_save_plus.dart';
import 'package:document_file_save_plus/document_file_save_plus_platform_interface.dart';
import 'package:document_file_save_plus/document_file_save_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockDocumentFileSavePlusPlatform
    with MockPlatformInterfaceMixin
    implements DocumentFileSavePlusPlatform {
  @override
  Future<int?> get batteryPercentage => Future.value(42);

  @override
  Future<String?> get platformVersion => Future.value('42');

  @override
  Future<void> saveMultipleFiles({
    List<Uint8List>? dataList,
    required List<String> fileNameList,
    required List<String> mimeTypeList,
  }) async {}
}

void main() {
  final initialPlatform = DocumentFileSavePlusPlatform.instance;

  test('$MethodChannelDocumentFileSavePlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelDocumentFileSavePlus>());
  });

  test('get platformVersion', () async {
    DocumentFileSavePlus documentFileSavePlusPlugin = DocumentFileSavePlus();
    final fakePlatform = MockDocumentFileSavePlusPlatform();
    DocumentFileSavePlusPlatform.instance = fakePlatform;

    expect(await documentFileSavePlusPlugin.platformVersion, '42');
  });
}
