import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MethodChannelFlutterEspBleProv platform = MethodChannelFlutterEspBleProv();
  const MethodChannel channel = MethodChannel('flutter_esp_ble_prov');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'getPlatformVersion':
          return '42';
        default:
          throw UnimplementedError();
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
