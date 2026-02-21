package how.virc.flutter_esp_ble_prov

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
   * Extracts an optional integer argument from the method call.
   */
  fun optionalInt(name: String): Int? {
    val value = call.argument<Number>(name) ?: return null
    return value.toInt()
  }
}
