import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_esp_ble_prov_platform_interface.dart';

/// An implementation of [FlutterEspBleProvPlatform] that uses method channels.
class MethodChannelFlutterEspBleProv extends FlutterEspBleProvPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_esp_ble_prov');

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<List<String>> scanBleDevices(String prefix) async {
    final args = {'prefix': prefix};
    final raw =
        await methodChannel.invokeMethod<List<Object?>>('scanBleDevices', args);
    final List<String> devices = [];
    if (raw != null) {
      devices.addAll(raw.cast<String>());
    }
    return devices;
  }

  @override
  Future<List<WiFiNetwork>> scanWifiNetworks(
      String deviceName, String proofOfPossession) async {
    final List<dynamic> result =
        await methodChannel.invokeMethod('scanWifiNetworks', {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
    });

    return result.map((networkMap) {
      return WiFiNetwork(
        ssid: networkMap['ssid'],
        rssi: networkMap['rssi'],
      );
    }).toList();
  }

  @override
  Future<bool?> provisionWifi(String deviceName, String proofOfPossession,
      String ssid, String passphrase) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'ssid': ssid,
      'passphrase': passphrase
    };
    return await methodChannel.invokeMethod<bool?>('provisionWifi', args);
  }
}
