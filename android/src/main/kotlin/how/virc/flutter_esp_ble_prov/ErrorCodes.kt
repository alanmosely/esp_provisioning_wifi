package how.virc.flutter_esp_ble_prov

object ErrorCodes {
  const val MISSING_ARGUMENT = "E0"
  const val WIFI_SCAN_FAILED = "E1"
  const val BLE_SCAN_START_FAILED = "E_BLE_SCAN_START"
  const val BLE_SCAN_FAILED = "E_BLE_SCAN"
  const val DEVICE_NOT_FOUND = "E_DEVICE_NOT_FOUND"
  const val CONNECT_TIMEOUT = "E_CONNECT_TIMEOUT"
  const val CONNECT_FAILED = "E_CONNECT"
  const val CUSTOM_DATA_FAILED = "E_CUSTOM_DATA"
  const val CANCELLED = "E_CANCELLED"
  const val PERMISSION_DENIED = "E_PERMISSION"
}
