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
    return _decodeStringList(methodName: 'scanBleDevices', raw: raw);
  }

  @override
  Future<List<String>> scanWifiNetworks(
      String deviceName, String proofOfPossession) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
    };
    final raw = await methodChannel.invokeMethod<List<Object?>>(
        'scanWifiNetworks', args);
    return _decodeStringList(methodName: 'scanWifiNetworks', raw: raw);
  }

  @override
  Future<bool> provisionWifi(String deviceName, String proofOfPossession,
      String ssid, String passphrase) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'ssid': ssid,
      'passphrase': passphrase
    };
    final result =
        await methodChannel.invokeMethod<bool?>('provisionWifi', args);
    return result ?? false;
  }

  List<String> _decodeStringList({
    required String methodName,
    required List<Object?>? raw,
  }) {
    if (raw == null) {
      return const <String>[];
    }
    for (final item in raw) {
      if (item is! String) {
        throw PlatformException(
          code: 'E_INVALID_RESPONSE',
          message: 'Invalid response type from $methodName',
          details: 'Expected a list of strings from platform channel.',
        );
      }
    }
    return List<String>.from(raw);
  }
}
