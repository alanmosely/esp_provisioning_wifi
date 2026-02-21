import 'flutter_esp_ble_prov_platform_interface.dart';

/// Plugin provides core functionality to provision ESP32 devices over BLE
class FlutterEspBleProv {
  /// Initiates a scan of BLE devices with the given [prefix].
  ///
  /// ESP32 Arduino demo defaults this value to "PROV_"
  Future<List<String>> scanBleDevices(String prefix) {
    return FlutterEspBleProvPlatform.instance.scanBleDevices(prefix);
  }

  /// Scan the available WiFi networks for the given [deviceName] and
  /// [proofOfPossession] string.

  /// This library uses SECURITY_1 by default which insists on a
  /// [proofOfPossession] string. ESP32 Arduino demo defaults this value to
  /// "abcd1234"
  Future<List<String>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession, {
    Duration? connectTimeout,
  }) {
    return FlutterEspBleProvPlatform.instance.scanWifiNetworks(
      deviceName,
      proofOfPossession,
      connectTimeout: connectTimeout,
    );
  }

  /// Provision the named WiFi network at [ssid] with the given [passphrase] for
  /// the named device [deviceName] and [proofOfPossession] string.
  Future<bool> provisionWifi(
    String deviceName,
    String proofOfPossession,
    String ssid,
    String passphrase, {
    Duration? connectTimeout,
  }) {
    return FlutterEspBleProvPlatform.instance.provisionWifi(
      deviceName,
      proofOfPossession,
      ssid,
      passphrase,
      connectTimeout: connectTimeout,
    );
  }

  /// Cancels in-flight native scan/provision operations.
  Future<bool> cancelOperations() {
    return FlutterEspBleProvPlatform.instance.cancelOperations();
  }

  /// Returns the native platform version
  Future<String?> getPlatformVersion() {
    return FlutterEspBleProvPlatform.instance.getPlatformVersion();
  }
}
