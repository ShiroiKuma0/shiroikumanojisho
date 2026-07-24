import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'document_file_save_plus_method_channel.dart';

abstract class DocumentFileSavePlusPlatform extends PlatformInterface {
  /// Constructs a DocumentFileSavePlusPlatform.
  DocumentFileSavePlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static DocumentFileSavePlusPlatform _instance =
      MethodChannelDocumentFileSavePlus();

  /// The default instance of [DocumentFileSavePlusPlatform] to use.
  ///
  /// Defaults to [MethodChannelDocumentFileSavePlus].
  static DocumentFileSavePlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DocumentFileSavePlusPlatform] when
  /// they register themselves.
  static set instance(DocumentFileSavePlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> get platformVersion {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<int?> get batteryPercentage {
    throw UnimplementedError('batteryPercentage() has not been implemented.');
  }

  Future<void> saveMultipleFiles({
    List<Uint8List>? dataList,
    required List<String> fileNameList,
    required List<String> mimeTypeList,
  }) async {
    throw UnimplementedError('saveMultipleFiles() has not been implemented.');
  }
}
