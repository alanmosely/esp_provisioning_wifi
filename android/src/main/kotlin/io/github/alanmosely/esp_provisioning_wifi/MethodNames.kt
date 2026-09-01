package io.github.alanmosely.esp_provisioning_wifi

object MethodNames {
  const val CHANNEL = "esp_provisioning_wifi"
  const val GET_PLATFORM_VERSION = "getPlatformVersion"
  const val SCAN_BLE_DEVICES = "scanBleDevices"
  const val SCAN_WIFI_NETWORKS = "scanWifiNetworks"
  const val PROVISION_WIFI = "provisionWifi"
  const val FETCH_CUSTOM_DATA = "fetchCustomData"
  const val CANCEL_OPERATIONS = "cancelOperations"
}

object ArgumentNames {
  const val CONNECT_TIMEOUT_MS = "connectTimeoutMs"
  const val ENDPOINT = "endpoint"
  const val PAYLOAD = "payload"
}
