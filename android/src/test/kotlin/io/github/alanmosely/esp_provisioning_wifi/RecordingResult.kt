package io.github.alanmosely.esp_provisioning_wifi

import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel.Result double recording every resolution, so tests can assert
 * the exactly-once contract as well as the delivered values.
 */
class RecordingResult : MethodChannel.Result {
  val successes = mutableListOf<Any?>()
  val errors = mutableListOf<Triple<String, String?, Any?>>()
  var notImplementedCalls = 0

  val resolutionCount: Int
    get() = successes.size + errors.size + notImplementedCalls

  override fun success(result: Any?) {
    successes.add(result)
  }

  override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
    errors.add(Triple(errorCode, errorMessage, errorDetails))
  }

  override fun notImplemented() {
    notImplementedCalls++
  }
}
