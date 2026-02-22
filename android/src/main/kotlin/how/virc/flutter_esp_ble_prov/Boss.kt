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
  companion object {
    const val DEFAULT_CONNECT_TIMEOUT_MS = 15000L
  }

  private val logTag = "FlutterEspBleProv"

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
  private val customDataFetcher = CustomDataManager(this)

  private lateinit var platformContext: Context
  lateinit var platformActivity: Activity

  @Volatile private var currentOperationToken = 0
  @Volatile private var activeDevice: ESPDevice? = null

  val espManager: ESPProvisionManager
    get() = ESPProvisionManager.getInstance(platformContext)

  // Logging shortcuts.
  fun d(msg: String) = Log.d(logTag, msg)

  fun e(msg: String) = Log.e(logTag, msg)

  fun connector(deviceName: String): BleConnector? = devices[deviceName]

  fun hasAttachedActivity(): Boolean = this::platformActivity.isInitialized

  @Synchronized
  fun startOperation(): Int {
    currentOperationToken += 1
    disconnectActiveDeviceLocked()
    return currentOperationToken
  }

  @Synchronized
  fun cancelOperations(): Boolean {
    currentOperationToken += 1
    disconnectActiveDeviceLocked()
    return true
  }

  @Synchronized
  fun isOperationActive(token: Int): Boolean = token == currentOperationToken

  @Synchronized
  private fun trackActiveDevice(device: ESPDevice) {
    activeDevice = device
  }

  @Synchronized
  fun clearActiveDevice(device: ESPDevice?) {
    if (device == null || activeDevice === device) {
      activeDevice = null
    }
  }

  @Synchronized
  private fun disconnectActiveDeviceLocked() {
    try {
      activeDevice?.disconnectDevice()
    } catch (e: Exception) {
      e("disconnectActiveDevice failed: $e")
    } finally {
      activeDevice = null
    }
  }

  /**
   * Connect to a named device with proofOfPossession string, and once connected, execute callback.
   */
  fun connect(
      conn: BleConnector,
      proofOfPossession: String,
      operationToken: Int,
      connectTimeoutMs: Long,
      onConnectCallback: (ESPDevice) -> Unit,
      onErrorCallback: (String, String, String?) -> Unit
  ) {
    val esp = espManager.createESPDevice(
        ESPConstants.TransportType.TRANSPORT_BLE,
        ESPConstants.SecurityType.SECURITY_1)
    trackActiveDevice(esp)
    val mainHandler = Handler(Looper.getMainLooper())
    val bus = EventBus.getDefault()
    var resolved = false
    var unregisterTarget: Any? = null
    var timeoutRunnable = Runnable {}

    fun resolveConnectError(code: String, message: String, details: String?) {
      if (resolved) {
        return
      }
      resolved = true
      mainHandler.removeCallbacks(timeoutRunnable)
      unregisterTarget?.let {
        if (bus.isRegistered(it)) {
          bus.unregister(it)
        }
      }
      if (!isOperationActive(operationToken)) {
        clearActiveDevice(esp)
        return
      }
      clearActiveDevice(esp)
      onErrorCallback(code, message, details)
    }

    timeoutRunnable = Runnable {
      resolveConnectError(
          ErrorCodes.CONNECT_TIMEOUT,
          "Connection timed out",
          "ESP device did not report a successful BLE connection within $connectTimeoutMs ms")
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
            if (!isOperationActive(operationToken)) {
              try {
                esp.disconnectDevice()
              } catch (e: Exception) {
                e("disconnect cancelled connection failed: $e")
              } finally {
                clearActiveDevice(esp)
              }
              return
            }
            esp.proofOfPossession = proofOfPossession
            onConnectCallback(esp)
          }
        }
      }
    }

    unregisterTarget = eventSubscriber
    bus.register(eventSubscriber)
    mainHandler.postDelayed(timeoutRunnable, connectTimeoutMs)

    if (!isOperationActive(operationToken)) {
      resolveConnectError(ErrorCodes.CANCELLED, "Operation cancelled", null)
      return
    }

    try {
      esp.connectBLEDevice(conn.device, conn.primaryServiceUuid)
    } catch (e: Exception) {
      resolveConnectError(
          ErrorCodes.CONNECT_FAILED,
          "Failed to start BLE connection",
          "Exception details $e")
    }
  }

  fun call(call: MethodCall, result: Result) {
    if (call.method == MethodNames.GET_PLATFORM_VERSION) {
      val ctx = CallContext(call, result)
      getPlatformVersion(ctx)
      return
    }
    if (call.method == MethodNames.CANCEL_OPERATIONS) {
      result.success(cancelOperations())
      return
    }

    permissionManager.ensure { granted ->
      if (!granted) {
        result.error(ErrorCodes.PERMISSION_DENIED, "Bluetooth permissions not granted", null)
        return@ensure
      }
      val ctx = CallContext(call, result)
      when (call.method) {
        MethodNames.SCAN_BLE_DEVICES -> bleScanner.call(ctx)
        MethodNames.SCAN_WIFI_NETWORKS -> wifiScanner.call(ctx)
        MethodNames.PROVISION_WIFI -> wifiProvisioner.call(ctx)
        MethodNames.FETCH_CUSTOM_DATA -> customDataFetcher.call(ctx)
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
