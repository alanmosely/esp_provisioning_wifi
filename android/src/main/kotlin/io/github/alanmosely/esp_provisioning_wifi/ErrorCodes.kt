package io.github.alanmosely.esp_provisioning_wifi

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
  const val PROV_SESSION_FAILED = "E_PROV_SESSION"
  const val PROV_CONFIG_FAILED = "E_PROV_CONFIG"
  const val PROV_AUTH_FAILED = "E_PROV_AUTH"
  const val PROV_NETWORK_NOT_FOUND = "E_PROV_NETWORK_NOT_FOUND"
  const val PROV_FAILED = "E_PROV_FAILED"
}
