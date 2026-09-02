import 'package:esp_provisioning_wifi/esp_security_scheme.dart';
import 'package:esp_provisioning_wifi/esp_wifi_network.dart';

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
  ///
  /// Uses [EspSecurityScheme.security1] by default. [EspSecurityScheme.security2]
  /// (SRP6a) additionally requires the [username] configured in the firmware.
  ///
  /// Returns one [EspWifiNetwork] per SSID.
  Future<List<EspWifiNetwork>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) {
    return FlutterEspBleProvPlatform.instance.scanWifiNetworks(
      deviceName,
      proofOfPossession,
      security: security,
      username: username,
      connectTimeout: connectTimeout,
    );
  }

  /// Provision the named WiFi network at [ssid] with the given [passphrase] for
  /// the named device [deviceName] and [proofOfPossession] string.
  ///
  /// Uses [EspSecurityScheme.security1] by default. [EspSecurityScheme.security2]
  /// (SRP6a) additionally requires the [username] configured in the firmware.
  Future<bool> provisionWifi(
    String deviceName,
    String proofOfPossession,
    String ssid,
    String passphrase, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) {
    return FlutterEspBleProvPlatform.instance.provisionWifi(
      deviceName,
      proofOfPossession,
      ssid,
      passphrase,
      security: security,
      username: username,
      connectTimeout: connectTimeout,
    );
  }

  /// Cancels in-flight native scan/provision operations.
  Future<bool> cancelOperations() {
    return FlutterEspBleProvPlatform.instance.cancelOperations();
  }

  /// Reads custom provisioning endpoint data from a connected ESP device.
  ///
  /// The [endpoint] defaults to `custom-data` which is expected to exist on the
  /// firmware provisioning manager.
  ///
  /// Uses [EspSecurityScheme.security1] by default. [EspSecurityScheme.security2]
  /// (SRP6a) additionally requires the [username] configured in the firmware.
  Future<String?> fetchCustomData(
    String deviceName,
    String proofOfPossession, {
    String endpoint = 'custom-data',
    String payload = '',
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) {
    return FlutterEspBleProvPlatform.instance.fetchCustomData(
      deviceName,
      proofOfPossession,
      endpoint: endpoint,
      payload: payload,
      security: security,
      username: username,
      connectTimeout: connectTimeout,
    );
  }

  /// Returns the native platform version
  Future<String?> getPlatformVersion() {
    return FlutterEspBleProvPlatform.instance.getPlatformVersion();
  }
}
