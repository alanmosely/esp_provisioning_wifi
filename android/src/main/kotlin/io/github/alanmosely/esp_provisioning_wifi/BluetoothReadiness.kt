package io.github.alanmosely.esp_provisioning_wifi

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodChannel.Result

/** Main-thread-confined, bounded adapter readiness. Never scans or connects. */
internal class BluetoothReadiness(
    private val context: Context,
    private val boss: Boss,
    private val permissions: ((Boolean) -> Unit) -> Unit,
    private val readState: () -> Int? = {
      (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter?.state
    },
    private val launchEnable: (Activity, Int) -> Unit = { activity, code ->
      activity.startActivityForResult(Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE), code)
    }
) {
  private val handler = Handler(Looper.getMainLooper())
  private var activity: Activity? = null
  private var pending: Attempt? = null
  private var nextCode = 8100

  private class Attempt(val id: Int, val resolver: OperationResolver, val code: Int) {
    var receiver: BroadcastReceiver? = null
    var timeout: Runnable? = null
  }

  fun attach(activity: Activity) { this.activity = activity }

  fun detach(permanent: Boolean) {
    activity = null
    if (permanent) cancel()
  }

  fun cancel(requestId: Int? = null) {
    val attempt = pending ?: return
    if (requestId != null && requestId != attempt.id) return
    cleanup(attempt)
    attempt.resolver.cancelled()
  }

  fun ensureReady(id: Int, requestEnable: Boolean, timeoutMs: Long, result: Result) {
    cancel()
    val resolver = OperationResolver(boss, boss.startOperation(), result)
    boss.trackResolver(resolver)
    val attempt = Attempt(id, resolver, nextCode++)
    if (nextCode > 65000) nextCode = 8100
    pending = attempt
    attempt.timeout = Runnable {
      if (pending === attempt) {
        cleanup(attempt)
        resolver.error("E_BLUETOOTH_TIMEOUT", "Bluetooth readiness timed out", null)
      }
    }.also { handler.postDelayed(it, timeoutMs) }
    try {
      // A missing adapter requires no permission prompt.
      if (state() == "unavailable") {
        finish(attempt, "unavailable")
        return
      }
      permissions { granted ->
        if (!active(attempt)) return@permissions
        if (!granted) {
          finish(attempt, "unauthorized")
          return@permissions
        }
        val current = state()
        if (current == "on" || current == "unavailable" || current == "unauthorized" || !requestEnable) {
          finish(attempt, current)
          return@permissions
        }
        val owner = activity
        if (owner == null) {
          fail(attempt, "E_NO_ACTIVITY", "No Activity available for Bluetooth enable prompt")
          return@permissions
        }
        try {
          attempt.receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
              if (active(attempt) && state() == "on") finish(attempt, "on")
            }
          }.also {
            // Bluetooth broadcasts can originate from a privileged non-system UID.
            // Read the real adapter rather than trusting broadcast extras.
            ContextCompat.registerReceiver(context, it,
                IntentFilter(BluetoothAdapter.ACTION_STATE_CHANGED), ContextCompat.RECEIVER_EXPORTED)
          }
          launchEnable(owner, attempt.code)
        } catch (error: Exception) {
          fail(attempt, "E_BLUETOOTH_ENABLE", "Unable to request Bluetooth enable")
        }
      }
    } catch (error: Exception) {
      fail(attempt, "E_BLUETOOTH_STATE", "Unable to read Bluetooth readiness")
    }
  }

  fun onActivityResult(code: Int, resultCode: Int): Boolean {
    val attempt = pending ?: return false
    if (code != attempt.code) return false
    if (!active(attempt)) return true
    val current = state()
    if (current == "on" || resultCode != Activity.RESULT_OK) finish(attempt, current)
    // RESULT_OK can precede STATE_ON; the receiver waits within the same budget.
    return true
  }

  private fun state(): String = try {
    when (readState()) {
      null -> "unavailable"
      BluetoothAdapter.STATE_ON -> "on"
      BluetoothAdapter.STATE_OFF -> "off"
      else -> "unknown"
    }
  } catch (denied: SecurityException) { "unauthorized" }
    catch (_: Exception) { "unknown" }

  private fun active(attempt: Attempt): Boolean {
    if (pending !== attempt) return false
    if (!attempt.resolver.cancelledIfInactive()) return true
    cleanup(attempt)
    return false
  }

  private fun finish(attempt: Attempt, state: String) {
    if (!active(attempt)) return
    cleanup(attempt)
    attempt.resolver.success(state)
  }

  private fun fail(attempt: Attempt, code: String, message: String) {
    if (!active(attempt)) return
    cleanup(attempt)
    attempt.resolver.error(code, message, null)
  }

  private fun cleanup(attempt: Attempt) {
    if (pending === attempt) pending = null
    attempt.timeout?.let { handler.removeCallbacks(it) }
    attempt.receiver?.let {
      try { context.unregisterReceiver(it) } catch (_: IllegalArgumentException) {}
    }
    attempt.receiver = null
  }
}
