import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nowplaying/nowplaying.dart';

void main() {
  const MethodChannel channel = MethodChannel('NowPlaying');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('instance exists', () async {
    expect(NowPlaying.instance == null, false);
  });
}
