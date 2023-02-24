import 'package:flutter/services.dart';
import 'package:flutter_esp_ble_prov/src/flutter_esp_ble_prov_method_channel.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MethodChannelFlutterEspBleProv platform = MethodChannelFlutterEspBleProv();
  const MethodChannel channel = MethodChannel('flutter_esp_ble_prov');

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
    expect(await platform.getPlatformVersion(), '42');
  });
}
