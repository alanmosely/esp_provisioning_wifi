/// Canonical error codes emitted by native platform implementations.
///
/// These values are part of the plugin contract and are used by
/// [EspProvisioningBloc] to map failures.
class EspProvisioningErrorCodes {
  EspProvisioningErrorCodes._();

  /// Missing/invalid method-call argument.
  static const String missingArgument = 'E0';

  /// Generic Wi-Fi scan failure (legacy Android code).
  static const String wifiScanFailed = 'E1';

  /// Bluetooth permission denied.
  static const String permission = 'E_PERMISSION';

  /// Operation timed out in the Dart BLoC layer.
  static const String timeout = 'E_TIMEOUT';

  /// Operation explicitly cancelled in native layer.
  static const String cancelled = 'E_CANCELLED';

  /// Unknown/unmapped error.
  static const String unknown = 'E_UNKNOWN';

  /// Could not start BLE scan.
  static const String bleScanStart = 'E_BLE_SCAN_START';

  /// BLE scan failed while running.
  static const String bleScan = 'E_BLE_SCAN';

  /// Device lookup failed from scanned cache.
  static const String deviceNotFound = 'E_DEVICE_NOT_FOUND';

  /// Platform response payload shape/type mismatch.
  static const String invalidResponse = 'E_INVALID_RESPONSE';

  /// BLE connect attempt timed out.
  static const String connectTimeout = 'E_CONNECT_TIMEOUT';

  /// BLE connect could not be started.
  static const String connect = 'E_CONNECT';

  /// iOS device creation failure.
  static const String iosDeviceCreate = 'E_DEVICE';

  /// iOS disconnect/fallback failure.
  static const String deviceDisconnected = 'DEVICE_DISCONNECTED';
}
