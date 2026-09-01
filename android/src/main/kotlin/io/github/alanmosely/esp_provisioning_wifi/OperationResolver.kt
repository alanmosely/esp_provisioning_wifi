package io.github.alanmosely.esp_provisioning_wifi

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Resolves a method channel call exactly once, always on the main thread.
 *
 * Espressif listener callbacks arrive on background threads while [Result]
 * must only be invoked on the platform main thread. If the owning operation
 * has been cancelled or superseded by the time a resolution is delivered, the
 * call resolves with [ErrorCodes.CANCELLED] so the Dart future never dangles.
 */
class OperationResolver(
    private val boss: Boss,
    val operationToken: Int,
    private val result: Result
) {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val resolved = AtomicBoolean(false)

  fun success(value: Any?) = dispatch { result.success(value) }

  fun error(code: String, message: String, details: String?) = dispatch {
    result.error(code, message, details)
  }

  fun cancelled() = error(ErrorCodes.CANCELLED, "Operation cancelled", null)

  /**
   * Resolves with [ErrorCodes.CANCELLED] and returns true when the operation
   * is no longer active, otherwise returns false.
   */
  fun cancelledIfInactive(): Boolean {
    if (boss.isOperationActive(operationToken)) {
      return false
    }
    cancelled()
    return true
  }

  private fun dispatch(resolution: () -> Unit) {
    if (!resolved.compareAndSet(false, true)) {
      return
    }
    if (Looper.myLooper() == Looper.getMainLooper()) {
      deliver(resolution)
    } else {
      mainHandler.post { deliver(resolution) }
    }
  }

  private fun deliver(resolution: () -> Unit) {
    if (boss.isOperationActive(operationToken)) {
      resolution()
    } else {
      result.error(ErrorCodes.CANCELLED, "Operation cancelled", null)
    }
  }
}
