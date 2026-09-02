package io.github.alanmosely.esp_provisioning_wifi

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Combined context from a method channel call from the Flutter side.
 */
class CallContext(val call: MethodCall, val result: Result) {

  /**
   * Extracts an argument's value from the method call, and returns an error condition if it is
   * not present.
   */
  fun arg(name: String): String? {
    val value = call.argument<String>(name)
    if (value == null) {
      result.error(
          ErrorCodes.MISSING_ARGUMENT,
          "Missing argument: $name",
          "The argument $name was not provided")
    }
    return value
  }

  /**
   * Extracts an optional string argument from the method call without
   * resolving an error when it is absent.
   */
  fun optionalString(name: String): String? = call.argument<String>(name)

  /**
   * Extracts an optional integer argument from the method call.
   */
  fun optionalInt(name: String): Int? {
    val value = call.argument<Number>(name) ?: return null
    return value.toInt()
  }

  /**
   * Extracts the optional connect timeout, falling back to the default when
   * absent or non-positive.
   */
  fun connectTimeoutMs(): Long {
    return optionalInt(ArgumentNames.CONNECT_TIMEOUT_MS)
        ?.takeIf { it > 0 }
        ?.toLong()
        ?: Boss.DEFAULT_CONNECT_TIMEOUT_MS
  }

  /**
   * Extracts the optional security scheme (1 = Security 1, 2 = Security 2),
   * defaulting to Security 1.
   */
  fun security(): Int = optionalInt(ArgumentNames.SECURITY) ?: 1
}
