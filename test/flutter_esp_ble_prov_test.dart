import 'package:esp_provisioning_wifi/esp_security_scheme.dart';
import 'package:esp_provisioning_wifi/esp_wifi_network.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_channel.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterEspBleProvPlatform
    with MockPlatformInterfaceMixin
    implements FlutterEspBleProvPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Records the most recent call so the facade's parameter forwarding can be
/// asserted method by method.
class RecordingFlutterEspBleProvPlatform
    with MockPlatformInterfaceMixin
    implements FlutterEspBleProvPlatform {
  String? lastMethod;
  Map<String, Object?> lastArgs = <String, Object?>{};

  @override
  Future<String?> getPlatformVersion() async {
    lastMethod = 'getPlatformVersion';
    lastArgs = <String, Object?>{};
    return '42';
  }

  @override
  Future<List<String>> scanBleDevices(String prefix) async {
    lastMethod = 'scanBleDevices';
    lastArgs = <String, Object?>{'prefix': prefix};
    return const <String>[];
  }

  @override
  Future<List<EspWifiNetwork>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) async {
    lastMethod = 'scanWifiNetworks';
    lastArgs = <String, Object?>{
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'security': security,
      'username': username,
      'connectTimeout': connectTimeout,
    };
    return const <EspWifiNetwork>[];
  }

  @override
  Future<bool> provisionWifi(
    String deviceName,
    String proofOfPossession,
    String ssid,
    String passphrase, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) async {
    lastMethod = 'provisionWifi';
    lastArgs = <String, Object?>{
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'ssid': ssid,
      'passphrase': passphrase,
      'security': security,
      'username': username,
      'connectTimeout': connectTimeout,
    };
    return true;
  }

  @override
  Future<bool> cancelOperations() async {
    lastMethod = 'cancelOperations';
    lastArgs = <String, Object?>{};
    return true;
  }

  @override
  Future<String?> fetchCustomData(
    String deviceName,
    String proofOfPossession, {
    String endpoint = 'custom-data',
    String payload = '',
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) async {
    lastMethod = 'fetchCustomData';
    lastArgs = <String, Object?>{
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'endpoint': endpoint,
      'payload': payload,
      'security': security,
      'username': username,
      'connectTimeout': connectTimeout,
    };
    return 'payload-response';
  }
}

void main() {
  final FlutterEspBleProvPlatform initialPlatform =
      FlutterEspBleProvPlatform.instance;

  tearDown(() {
    FlutterEspBleProvPlatform.instance = initialPlatform;
  });

  test('$MethodChannelFlutterEspBleProv is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterEspBleProv>());
  });

  test('getPlatformVersion', () async {
    FlutterEspBleProv flutterEspBleProvPlugin = FlutterEspBleProv();
    MockFlutterEspBleProvPlatform fakePlatform =
        MockFlutterEspBleProvPlatform();
    FlutterEspBleProvPlatform.instance = fakePlatform;

    expect(await flutterEspBleProvPlugin.getPlatformVersion(), '42');
  });

  test('facade forwards every named parameter to the platform', () async {
    final facade = FlutterEspBleProv();
    final platform = RecordingFlutterEspBleProvPlatform();
    FlutterEspBleProvPlatform.instance = platform;
    const timeout = Duration(seconds: 3);

    await facade.scanBleDevices('PROV_');
    expect(platform.lastMethod, 'scanBleDevices');
    expect(platform.lastArgs, <String, Object?>{'prefix': 'PROV_'});

    await facade.scanWifiNetworks(
      'PROV_01',
      'pop',
      security: EspSecurityScheme.security2,
      username: 'wifiprov',
      connectTimeout: timeout,
    );
    expect(platform.lastMethod, 'scanWifiNetworks');
    expect(platform.lastArgs, <String, Object?>{
      'deviceName': 'PROV_01',
      'proofOfPossession': 'pop',
      'security': EspSecurityScheme.security2,
      'username': 'wifiprov',
      'connectTimeout': timeout,
    });

    await facade.provisionWifi(
      'PROV_01',
      'pop',
      'home-wifi',
      'secret',
      security: EspSecurityScheme.security2,
      username: 'wifiprov',
      connectTimeout: timeout,
    );
    expect(platform.lastMethod, 'provisionWifi');
    expect(platform.lastArgs, <String, Object?>{
      'deviceName': 'PROV_01',
      'proofOfPossession': 'pop',
      'ssid': 'home-wifi',
      'passphrase': 'secret',
      'security': EspSecurityScheme.security2,
      'username': 'wifiprov',
      'connectTimeout': timeout,
    });

    expect(
      await facade.fetchCustomData(
        'PROV_01',
        'pop',
        endpoint: 'my-endpoint',
        payload: 'ping',
        security: EspSecurityScheme.security2,
        username: 'wifiprov',
        connectTimeout: timeout,
      ),
      'payload-response',
    );
    expect(platform.lastMethod, 'fetchCustomData');
    expect(platform.lastArgs, <String, Object?>{
      'deviceName': 'PROV_01',
      'proofOfPossession': 'pop',
      'endpoint': 'my-endpoint',
      'payload': 'ping',
      'security': EspSecurityScheme.security2,
      'username': 'wifiprov',
      'connectTimeout': timeout,
    });

    expect(await facade.cancelOperations(), isTrue);
    expect(platform.lastMethod, 'cancelOperations');
  });
}
