/// Canonical method/channel names used by the platform interface.
class FlutterEspBleProvMethodNames {
  FlutterEspBleProvMethodNames._();

  static const String channel = 'flutter_esp_ble_prov';
  static const String getPlatformVersion = 'getPlatformVersion';
  static const String scanBleDevices = 'scanBleDevices';
  static const String scanWifiNetworks = 'scanWifiNetworks';
  static const String provisionWifi = 'provisionWifi';
  static const String fetchCustomData = 'fetchCustomData';
  static const String cancelOperations = 'cancelOperations';

  static const String connectTimeoutMsArg = 'connectTimeoutMs';
  static const String endpointArg = 'endpoint';
  static const String payloadArg = 'payload';
}
