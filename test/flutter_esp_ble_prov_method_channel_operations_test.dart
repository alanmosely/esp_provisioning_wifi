import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_esp_ble_prov');
  final MethodChannelFlutterEspBleProv platform =
      MethodChannelFlutterEspBleProv();
  Future<Object?> Function(MethodCall call)? handler;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      if (handler == null) {
        return null;
      }
      return handler!(call);
    });
  });

  tearDown(() {
    handler = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('scanBleDevices forwards prefix and returns mapped list', () async {
    handler = (MethodCall call) async {
      expect(call.method, 'scanBleDevices');
      expect(call.arguments, {'prefix': 'PROV_'});
      return <Object?>['PROV_01', 'PROV_02'];
    };

    final devices = await platform.scanBleDevices('PROV_');
    expect(devices, <String>['PROV_01', 'PROV_02']);
  });

  test('scanWifiNetworks forwards args and returns mapped list', () async {
    handler = (MethodCall call) async {
      expect(call.method, 'scanWifiNetworks');
      expect(call.arguments, {
        'deviceName': 'PROV_01',
        'proofOfPossession': 'abcd1234',
      });
      return <Object?>['home-wifi', 'office-wifi'];
    };

    final networks = await platform.scanWifiNetworks('PROV_01', 'abcd1234');
    expect(networks, <String>['home-wifi', 'office-wifi']);
  });

  test('provisionWifi forwards args and returns plugin bool', () async {
    handler = (MethodCall call) async {
      expect(call.method, 'provisionWifi');
      expect(call.arguments, {
        'deviceName': 'PROV_01',
        'proofOfPossession': 'abcd1234',
        'ssid': 'home-wifi',
        'passphrase': 'secret',
      });
      return true;
    };

    final provisioned = await platform.provisionWifi(
      'PROV_01',
      'abcd1234',
      'home-wifi',
      'secret',
    );

    expect(provisioned, isTrue);
  });

  test('scan methods return empty lists on null response', () async {
    handler = (MethodCall call) async {
      if (call.method == 'scanBleDevices') {
        return null;
      }
      if (call.method == 'scanWifiNetworks') {
        return null;
      }
      throw UnimplementedError(call.method);
    };

    expect(await platform.scanBleDevices('PROV_'), isEmpty);
    expect(await platform.scanWifiNetworks('PROV_01', 'abcd1234'), isEmpty);
  });
}
