package io.github.alanmosely.esp_provisioning_wifi

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
import java.util.concurrent.atomic.AtomicInteger
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

  private val logTag = "EspProvisioningWifi"

  /**
   * The available scanned BLE devices.
   */
  val devices = mutableMapOf<String, BleConnector>()

  // Managers performing the various actions.
  private val permissionManager = PermissionManager(this)
  private val bleScanner = BleScanManager(this)
  private val wifiScanner = WifiScanManager(this)
  private val wifiProvisioner = WifiProvisionManager(this)
  private val customDataFetcher = CustomDataManager(this)

  private lateinit var platformContext: Context
  var platformActivity: Activity? = null
    private set

  @Volatile private var currentOperationToken = 0
  @Volatile private var activeDevice: ESPDevice? = null
  @Volatile private var activeResolver: OperationResolver? = null
  @Volatile private var activeConnectCancel: (() -> Unit)? = null
  @Volatile private var bleScanInFlight = false

  /**
   * Disconnects initiated by the plugin itself on devices that may hold a live
   * BLE link. DeviceConnectionEvent carries no device identity, so the connect
   * subscriber consumes from this count to ignore stale DISCONNECTED events
   * caused by a previous operation's asynchronous teardown, instead of failing
   * the current attempt. Over-counting only degrades a fast-fail into the
   * connect timeout; it never fails a healthy attempt.
   */
  private val selfInitiatedDisconnects = AtomicInteger(0)

  fun noteSelfInitiatedDisconnect() {
    selfInitiatedDisconnects.incrementAndGet()
  }

  fun consumeSelfInitiatedDisconnect(): Boolean {
    while (true) {
      val current = selfInitiatedDisconnects.get()
      if (current <= 0) {
        return false
      }
      if (selfInitiatedDisconnects.compareAndSet(current, current - 1)) {
        return true
      }
    }
  }

  val espManager: ESPProvisionManager
    get() = ESPProvisionManager.getInstance(platformContext)

  // Logging shortcuts.
  fun d(msg: String) = Log.d(logTag, msg)

  fun e(msg: String) = Log.e(logTag, msg)

  fun connector(deviceName: String): BleConnector? = devices[deviceName]

  @Synchronized
  fun startOperation(): Int {
    currentOperationToken += 1
    disconnectActiveDeviceLocked()
    cancelActiveResolverLocked()
    stopBleScanLocked()
    cancelActiveConnectLocked()
    return currentOperationToken
  }

  @Synchronized
  fun cancelOperations(): Boolean {
    currentOperationToken += 1
    disconnectActiveDeviceLocked()
    cancelActiveResolverLocked()
    stopBleScanLocked()
    cancelActiveConnectLocked()
    return true
  }

  @Synchronized
  fun trackResolver(resolver: OperationResolver) {
    activeResolver = resolver
  }

  private fun cancelActiveResolverLocked() {
    val resolver = activeResolver ?: return
    activeResolver = null
    resolver.cancelled()
  }

  /**
   * Registers the in-flight connect attempt's cancellation hook so
   * supersession/cancellation dismantles its EventBus subscriber immediately.
   * A stale subscriber would consume the self-initiated-disconnect credit
   * meant for the successor's connect (spuriously failing a healthy attempt
   * with E_CONNECT) or permanently over-count via its CONNECTED branch.
   */
  @Synchronized
  fun trackConnectCancel(cancel: () -> Unit) {
    activeConnectCancel = cancel
  }

  private fun cancelActiveConnectLocked() {
    val cancel = activeConnectCancel ?: return
    activeConnectCancel = null
    cancel()
  }

  fun noteBleScanStarted() {
    bleScanInFlight = true
  }

  fun noteBleScanFinished() {
    bleScanInFlight = false
  }

  /**
   * Stops an in-flight BLE device scan so cancellation actually releases the
   * radio (rapid rescans otherwise stack OS-level scans toward Android's scan
   * throttle). Must run after [cancelActiveResolverLocked]: stopping invokes
   * the listener's scanCompleted, which the already-cancelled resolver drops.
   */
  private fun stopBleScanLocked() {
    if (!bleScanInFlight) {
      return
    }
    bleScanInFlight = false
    try {
      espManager.stopBleScan()
    } catch (e: Exception) {
      e("stopBleScan failed: $e")
    }
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
      activeDevice?.let {
        noteSelfInitiatedDisconnect()
        it.disconnectDevice()
      }
    } catch (e: Exception) {
      e("disconnectActiveDevice failed: $e")
    } finally {
      activeDevice = null
    }
  }

  /**
   * Connect to a named device with proofOfPossession string, and once connected, execute callback.
   *
   * [security] selects the provisioning scheme (1 = Security 1, 2 = Security 2);
   * Security 2 requires the SRP6a [username] configured in the firmware.
   */
  fun connect(
      conn: BleConnector,
      proofOfPossession: String,
      security: Int,
      username: String?,
      operationToken: Int,
      connectTimeoutMs: Long,
      onConnectCallback: (ESPDevice) -> Unit,
      onErrorCallback: (String, String, String?) -> Unit
  ) {
    val securityType = if (security == 2) {
      ESPConstants.SecurityType.SECURITY_2
    } else {
      ESPConstants.SecurityType.SECURITY_1
    }
    val esp = espManager.createESPDevice(
        ESPConstants.TransportType.TRANSPORT_BLE,
        securityType)
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
      try {
        // In the connect-timeout path the GATT can be live (connected at the
        // Android level, service discovery pending), so this teardown can emit
        // a DISCONNECTED event; note the credit like every other
        // plugin-initiated disconnect. Over-counting on the paths where no
        // event follows only degrades a future fast-fail into the connect
        // timeout; an under-count fails a healthy attempt.
        noteSelfInitiatedDisconnect()
        esp.disconnectDevice()
      } catch (e: Exception) {
        e("disconnect after connect failure failed: $e")
      } finally {
        clearActiveDevice(esp)
      }
      onErrorCallback(code, message, details)
    }

    // Invoked by startOperation/cancelOperations when a new operation
    // supersedes this in-flight attempt. Device teardown (and its disconnect
    // credit) is handled by disconnectActiveDeviceLocked before this runs, so
    // only the subscriber and timeout need dismantling here.
    fun cancelAttempt() {
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
      clearActiveDevice(esp)
      onErrorCallback(ErrorCodes.CANCELLED, "Operation cancelled", null)
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
                noteSelfInitiatedDisconnect()
                esp.disconnectDevice()
              } catch (e: Exception) {
                e("disconnect cancelled connection failed: $e")
              } finally {
                clearActiveDevice(esp)
              }
              onErrorCallback(ErrorCodes.CANCELLED, "Operation cancelled", null)
              return
            }
            esp.proofOfPossession = proofOfPossession
            if (!username.isNullOrEmpty()) {
              esp.userName = username
            }
            onConnectCallback(esp)
          }
          ESPConstants.EVENT_DEVICE_CONNECTION_FAILED -> {
            resolveConnectError(
                ErrorCodes.CONNECT_FAILED,
                "Failed to connect to BLE device",
                "ESP device reported a connection failure")
          }
          ESPConstants.EVENT_DEVICE_DISCONNECTED -> {
            if (consumeSelfInitiatedDisconnect()) {
              d("ignoring DISCONNECTED event from self-initiated teardown")
            } else {
              resolveConnectError(
                  ErrorCodes.CONNECT_FAILED,
                  "BLE device disconnected during connect",
                  "ESP device disconnected before the session was established")
            }
          }
        }
      }
    }

    unregisterTarget = eventSubscriber
    bus.register(eventSubscriber)
    mainHandler.postDelayed(timeoutRunnable, connectTimeoutMs)
    trackConnectCancel { cancelAttempt() }

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

  /**
   * Clears the activity so new permission checks fail fast while detached.
   * Pending permission callbacks are failed only on [permanent] detach: across
   * a config change the same PermissionManager is re-registered on the new
   * binding and the recreated Activity re-delivers the dialog result.
   */
  fun detachActivity(permanent: Boolean) {
    platformActivity = null
    if (permanent) {
      permissionManager.onActivityDetached()
    }
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
