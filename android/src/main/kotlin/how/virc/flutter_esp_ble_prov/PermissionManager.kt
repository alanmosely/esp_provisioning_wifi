package how.virc.flutter_esp_ble_prov

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.PluginRegistry

/**
 * Allows for asynchronously requesting permissions based on platform version.
 *
 * The version switch is required because Bluetooth permission requirements changed at S (31).
 */
class PermissionManager(private val boss: Boss) :
    PluginRegistry.RequestPermissionsResultListener {
  private val requestCode = 7309
  private var requestInFlight = false
  private val pendingCallbacks = mutableListOf<(Boolean) -> Unit>()

  /**
   * Required permissions for the current version of the SDK.
   */
  val permissions: Array<String>
    get() {
      // https://developer.android.com/guide/topics/connectivity/bluetooth/permissions
      return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        arrayOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
      } else {
        arrayOf(
            Manifest.permission.ACCESS_FINE_LOCATION,
            Manifest.permission.BLUETOOTH,
            Manifest.permission.BLUETOOTH_ADMIN)
      }
    }

  /**
   * Check permissions are granted and request them otherwise.
   */
  fun ensure(callback: (Boolean) -> Unit) {
    if (!boss.hasAttachedActivity()) {
      callback(false)
      return
    }

    val toRequest = mutableListOf<String>()
    for (permission in permissions) {
      if (ActivityCompat.checkSelfPermission(boss.platformActivity, permission) !=
          PackageManager.PERMISSION_GRANTED) {
        toRequest.add(permission)
      }
    }
    if (toRequest.isEmpty()) {
      callback(true)
      return
    }

    pendingCallbacks.add(callback)
    if (requestInFlight) {
      return
    }

    requestInFlight = true
    ActivityCompat.requestPermissions(
        boss.platformActivity,
        toRequest.toTypedArray(),
        requestCode,
    )
  }

  /**
   * Called on permission request result.
   */
  override fun onRequestPermissionsResult(
      requestCode: Int,
      permissions: Array<out String>,
      grantResults: IntArray
  ): Boolean {
    if (requestCode != this.requestCode) {
      return false
    }

    boss.d("permission result")
    val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
    requestInFlight = false
    val callbacks = pendingCallbacks.toList()
    pendingCallbacks.clear()
    callbacks.forEach { it(granted) }
    return true
  }
}
