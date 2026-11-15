package io.github.alanmosely.esp_provisioning_wifi

/** Validate before permission prompts or cancellation of an existing operation. */
internal object ChannelArguments {
  fun integer(value: Any?): Long? = when (value) {
    is Int -> value.toLong()
    is Long -> value
    else -> null
  }

  fun requiredStrings(method: String): List<String>? = when (method) {
    MethodNames.SCAN_BLE_DEVICES -> listOf("prefix")
    MethodNames.SCAN_WIFI_NETWORKS -> listOf("deviceName", "proofOfPossession")
    MethodNames.PROVISION_WIFI -> listOf("deviceName", "proofOfPossession", "ssid", "passphrase")
    MethodNames.FETCH_CUSTOM_DATA -> listOf("deviceName", "proofOfPossession", "endpoint")
    else -> null
  }

  fun validOperation(arguments: Any?, required: List<String>): Boolean {
    val args = arguments as? Map<*, *> ?: return false
    if (required.any { args[it] !is String }) return false
    for (key in listOf("payload", "username")) {
      if (args[key] != null && args[key] !is String) return false
    }
    for (key in listOf("security", "connectTimeoutMs")) {
      if (args[key] != null) {
        val value = integer(args[key]) ?: return false
        if (value !in Int.MIN_VALUE.toLong()..Int.MAX_VALUE.toLong()) return false
      }
    }
    if (integer(args["security"]) == 2L && (args["username"] as? String).isNullOrEmpty()) return false
    return true
  }
}
