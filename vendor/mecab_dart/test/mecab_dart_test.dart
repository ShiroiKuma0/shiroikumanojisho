import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mecab_dart/mecab_dart.dart';

void main() {
  const MethodChannel channel = MethodChannel('mecab_dart');

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
    expect(await MecabDart.platformVersion, '42');
  });
}
