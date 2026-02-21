import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_channel.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_names.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel channel =
      MethodChannel(FlutterEspBleProvMethodNames.channel);
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
      expect(call.method, FlutterEspBleProvMethodNames.scanBleDevices);
      expect(call.arguments, {'prefix': 'PROV_'});
      return <Object?>['PROV_01', 'PROV_02'];
    };

    final devices = await platform.scanBleDevices('PROV_');
    expect(devices, <String>['PROV_01', 'PROV_02']);
  });

  test('scanWifiNetworks forwards args and returns mapped list', () async {
    handler = (MethodCall call) async {
      expect(call.method, FlutterEspBleProvMethodNames.scanWifiNetworks);
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
      expect(call.method, FlutterEspBleProvMethodNames.provisionWifi);
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

  test('scanWifiNetworks forwards connect timeout when provided', () async {
    handler = (MethodCall call) async {
      expect(call.method, FlutterEspBleProvMethodNames.scanWifiNetworks);
      expect(call.arguments, {
        'deviceName': 'PROV_01',
        'proofOfPossession': 'abcd1234',
        FlutterEspBleProvMethodNames.connectTimeoutMsArg: 5000,
      });
      return <Object?>[];
    };

    final networks = await platform.scanWifiNetworks(
      'PROV_01',
      'abcd1234',
      connectTimeout: const Duration(seconds: 5),
    );
    expect(networks, isEmpty);
  });

  test('provisionWifi forwards connect timeout when provided', () async {
    handler = (MethodCall call) async {
      expect(call.method, FlutterEspBleProvMethodNames.provisionWifi);
      expect(call.arguments, {
        'deviceName': 'PROV_01',
        'proofOfPossession': 'abcd1234',
        'ssid': 'home-wifi',
        'passphrase': 'secret',
        FlutterEspBleProvMethodNames.connectTimeoutMsArg: 3000,
      });
      return true;
    };

    final provisioned = await platform.provisionWifi(
      'PROV_01',
      'abcd1234',
      'home-wifi',
      'secret',
      connectTimeout: const Duration(seconds: 3),
    );
    expect(provisioned, isTrue);
  });

  test('provisionWifi returns false on null response', () async {
    handler = (MethodCall call) async {
      expect(call.method, FlutterEspBleProvMethodNames.provisionWifi);
      return null;
    };

    final provisioned = await platform.provisionWifi(
      'PROV_01',
      'abcd1234',
      'home-wifi',
      'secret',
    );

    expect(provisioned, isFalse);
  });

  test('scan methods return empty lists on null response', () async {
    handler = (MethodCall call) async {
      if (call.method == FlutterEspBleProvMethodNames.scanBleDevices) {
        return null;
      }
      if (call.method == FlutterEspBleProvMethodNames.scanWifiNetworks) {
        return null;
      }
      throw UnimplementedError(call.method);
    };

    expect(await platform.scanBleDevices('PROV_'), isEmpty);
    expect(await platform.scanWifiNetworks('PROV_01', 'abcd1234'), isEmpty);
  });

  test('scan methods throw when response contains non-string values', () async {
    handler = (MethodCall call) async {
      if (call.method == FlutterEspBleProvMethodNames.scanBleDevices) {
        return <Object?>['ok', 1];
      }
      if (call.method == FlutterEspBleProvMethodNames.scanWifiNetworks) {
        return <Object?>[true];
      }
      throw UnimplementedError(call.method);
    };

    await expectLater(
      platform.scanBleDevices('PROV_'),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      platform.scanWifiNetworks('PROV_01', 'abcd1234'),
      throwsA(isA<PlatformException>()),
    );
  });

  test('cancelOperations forwards to native and returns bool', () async {
    handler = (MethodCall call) async {
      expect(call.method, FlutterEspBleProvMethodNames.cancelOperations);
      return true;
    };

    final cancelled = await platform.cancelOperations();
    expect(cancelled, isTrue);
  });
}
