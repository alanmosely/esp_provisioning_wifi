package how.virc.flutter_esp_ble_prov

import android.app.Activity
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.espressif.provisioning.DeviceConnectionEvent
import com.espressif.provisioning.ESPConstants
import com.espressif.provisioning.ESPDevice
import com.espressif.provisioning.ESPProvisionManager
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode

/**
 * Overall controller for method handling and state.
 *
 * Everything is asynchronous here, and this class handles that through manager classes.
 */
class Boss {
  private val logTag = "FlutterEspBleProv"

  // Method names as called from Flutter across the channel.
  private val scanBleMethod = "scanBleDevices"
  private val scanWifiMethod = "scanWifiNetworks"
  private val provisionWifiMethod = "provisionWifi"
  private val platformVersionMethod = "getPlatformVersion"

  /**
   * The available scanned BLE devices.
   */
  val devices = mutableMapOf<String, BleConnector>()

  /**
   * The available WiFi networks for the most recently scanned BLE device.
   */
  val networks = mutableSetOf<String>()

  // Managers performing the various actions.
  private val permissionManager = PermissionManager(this)
  private val bleScanner = BleScanManager(this)
  private val wifiScanner = WifiScanManager(this)
  private val wifiProvisioner = WifiProvisionManager(this)

  private lateinit var platformContext: Context
  lateinit var platformActivity: Activity

  val espManager: ESPProvisionManager
    get() = ESPProvisionManager.getInstance(platformContext)

  // Logging shortcuts.
  fun d(msg: String) = Log.d(logTag, msg)

  fun e(msg: String) = Log.e(logTag, msg)

  fun connector(deviceName: String): BleConnector? = devices[deviceName]

  fun hasAttachedActivity(): Boolean = this::platformActivity.isInitialized

  /**
   * Connect to a named device with proofOfPossession string, and once connected, execute callback.
   */
  fun connect(
      conn: BleConnector,
      proofOfPossession: String,
      onConnectCallback: (ESPDevice) -> Unit,
      onErrorCallback: (String, String, String?) -> Unit
  ) {
    val esp = espManager.createESPDevice(
        ESPConstants.TransportType.TRANSPORT_BLE,
        ESPConstants.SecurityType.SECURITY_1)
    val mainHandler = Handler(Looper.getMainLooper())
    val bus = EventBus.getDefault()
    var resolved = false
    var unregisterTarget: Any? = null

    fun resolveConnectError(code: String, message: String, details: String?) {
      if (resolved) {
        return
      }
      resolved = true
      mainHandler.removeCallbacksAndMessages(null)
      unregisterTarget?.let {
        if (bus.isRegistered(it)) {
          bus.unregister(it)
        }
      }
      onErrorCallback(code, message, details)
    }

    val timeoutRunnable = Runnable {
      resolveConnectError(
          "E_CONNECT_TIMEOUT",
          "Connection timed out",
          "ESP device did not report a successful BLE connection within timeout")
    }

    val eventSubscriber = object {
      @Subscribe(threadMode = ThreadMode.MAIN)
      fun onEvent(event: DeviceConnectionEvent) {
        if (resolved) {
          return
        }
        d("bus event $event ${event.eventType}")
        when (event.eventType) {
          ESPConstants.EVENT_DEVICE_CONNECTED -> {
            resolved = true
            mainHandler.removeCallbacks(timeoutRunnable)
            if (bus.isRegistered(this)) {
              bus.unregister(this)
            }
            esp.proofOfPossession = proofOfPossession
            onConnectCallback(esp)
          }
        }
      }
    }

    unregisterTarget = eventSubscriber
    bus.register(eventSubscriber)
    mainHandler.postDelayed(timeoutRunnable, 15000)

    try {
      esp.connectBLEDevice(conn.device, conn.primaryServiceUuid)
    } catch (e: Exception) {
      resolveConnectError("E_CONNECT", "Failed to start BLE connection", "Exception details $e")
    }
  }

  fun call(call: MethodCall, result: Result) {
    if (call.method == platformVersionMethod) {
      val ctx = CallContext(call, result)
      getPlatformVersion(ctx)
      return
    }

    permissionManager.ensure { granted ->
      if (!granted) {
        result.error("E_PERMISSION", "Bluetooth permissions not granted", null)
        return@ensure
      }
      val ctx = CallContext(call, result)
      when (call.method) {
        platformVersionMethod -> getPlatformVersion(ctx)
        scanBleMethod -> bleScanner.call(ctx)
        scanWifiMethod -> wifiScanner.call(ctx)
        provisionWifiMethod -> wifiProvisioner.call(ctx)
        else -> result.notImplemented()
      }
    }
  }

  private fun getPlatformVersion(ctx: CallContext) {
    ctx.result.success("Android ${Build.VERSION.RELEASE}")
  }

  fun attachActivity(activity: Activity) {
    platformActivity = activity
  }

  fun attachContext(context: Context) {
    platformContext = context
  }

  fun attachBinding(binding: ActivityPluginBinding) {
    binding.addRequestPermissionsResultListener(permissionManager)
  }

  fun detachBinding(binding: ActivityPluginBinding) {
    binding.removeRequestPermissionsResultListener(permissionManager)
  }
}
