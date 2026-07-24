import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:document_file_save_plus/document_file_save_plus_method_channel.dart';

void main() {
  final platform = MethodChannelDocumentFileSavePlus();
  const MethodChannel channel = MethodChannel('document_file_save_plus');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.platformVersion, '42');
  });
}
