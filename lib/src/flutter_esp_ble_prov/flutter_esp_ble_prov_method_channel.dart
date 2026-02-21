import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_error_codes.dart';

import 'flutter_esp_ble_prov_method_names.dart';
import 'flutter_esp_ble_prov_platform_interface.dart';

/// An implementation of [FlutterEspBleProvPlatform] that uses method channels.
class MethodChannelFlutterEspBleProv extends FlutterEspBleProvPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel =
      const MethodChannel(FlutterEspBleProvMethodNames.channel);

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel
        .invokeMethod<String>(FlutterEspBleProvMethodNames.getPlatformVersion);
    return version;
  }

  @override
  Future<List<String>> scanBleDevices(String prefix) async {
    final args = {'prefix': prefix};
    final raw = await methodChannel.invokeMethod<List<Object?>>(
      FlutterEspBleProvMethodNames.scanBleDevices,
      args,
    );
    return _decodeStringList(
      methodName: FlutterEspBleProvMethodNames.scanBleDevices,
      raw: raw,
    );
  }

  @override
  Future<List<String>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession, {
    Duration? connectTimeout,
  }) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      if (connectTimeout != null)
        FlutterEspBleProvMethodNames.connectTimeoutMsArg:
            connectTimeout.inMilliseconds,
    };
    final raw = await methodChannel.invokeMethod<List<Object?>>(
      FlutterEspBleProvMethodNames.scanWifiNetworks,
      args,
    );
    return _decodeStringList(
      methodName: FlutterEspBleProvMethodNames.scanWifiNetworks,
      raw: raw,
    );
  }

  @override
  Future<bool> provisionWifi(
    String deviceName,
    String proofOfPossession,
    String ssid,
    String passphrase, {
    Duration? connectTimeout,
  }) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'ssid': ssid,
      'passphrase': passphrase,
      if (connectTimeout != null)
        FlutterEspBleProvMethodNames.connectTimeoutMsArg:
            connectTimeout.inMilliseconds,
    };
    final result = await methodChannel.invokeMethod<bool?>(
      FlutterEspBleProvMethodNames.provisionWifi,
      args,
    );
    return result ?? false;
  }

  @override
  Future<bool> cancelOperations() async {
    final result = await methodChannel.invokeMethod<bool?>(
      FlutterEspBleProvMethodNames.cancelOperations,
    );
    return result ?? true;
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
          code: EspProvisioningErrorCodes.invalidResponse,
          message: 'Invalid response type from $methodName',
          details: 'Expected a list of strings from platform channel.',
        );
      }
    }
    return List<String>.from(raw);
  }
}
