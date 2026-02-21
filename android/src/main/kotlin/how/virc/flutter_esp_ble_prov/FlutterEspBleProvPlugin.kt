package how.virc.flutter_esp_ble_prov

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.app.ActivityCompat
import com.espressif.provisioning.*
import com.espressif.provisioning.listeners.BleScanListener
import com.espressif.provisioning.listeners.ProvisionListener
import com.espressif.provisioning.listeners.WiFiScanListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import org.greenrobot.eventbus.EventBus
import org.greenrobot.eventbus.Subscribe
import org.greenrobot.eventbus.ThreadMode


/**
 * The data required to be able to connect to an Espressif BLE device.
 *
 * @param device The BLE device from a BLE scan
 * @param scanResult The ScanResult from a BLE scan
 */
class BleConnector(val device: BluetoothDevice, scanResult: ScanResult) {

  /**
   * The service ID used when connecting
   */
  val primaryServiceUuid: String

  init {
    primaryServiceUuid = scanResult.scanRecord?.serviceUuids?.get(0)?.toString() ?: ""
  }
}


/**
 * Combined context from a method channel call from the Flutter side.
 */
class CallContext(val call: MethodCall, val result: Result) {

  /**
   * Extracts an argument's value from the method call, and returns an error condition if it is not
   * present.
   */
  fun arg(name: String): String? {
    val v = call.argument<String>(name)
    if (v == null) {
      result.error("E0", "Missing argument: $name", "The argument $name was not provided")
    }
    return v
  }

}


/**
 * Allows for asynchronously requesting permissions based on platform version.
 *
 * The version switch is required because Bluetooth permission requirements changed at S (31).
 */
class PermissionManager(val boss: Boss) : PluginRegistry.RequestPermissionsResultListener {
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
        arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.BLUETOOTH, Manifest.permission.BLUETOOTH_ADMIN)
      }
    }

  /**
   * Check permissions are granted and request them otherwise.
   */
  fun ensure(fCallback: (Boolean) -> Unit) {
    if (!boss.hasAttachedActivity()) {
      fCallback(false)
      return
    }
    val toRequest: MutableList<String> = mutableListOf()
    for (p in permissions) {
      if (ActivityCompat.checkSelfPermission(boss.platformActivity, p) != PackageManager.PERMISSION_GRANTED) {
        toRequest.add(p)
      }
    }
    if (toRequest.isEmpty()) {
      fCallback(true)
      return
    }

    pendingCallbacks.add(fCallback)
    if (requestInFlight) {
      return
    }

    requestInFlight = true
    ActivityCompat.requestPermissions(boss.platformActivity, toRequest.toTypedArray(), requestCode)
  }

  /**
   * Called on permission request result.
   */
  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
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


abstract class ActionManager(val boss: Boss) {
  abstract fun call(ctx: CallContext)
}


/**
 * Overall controller for method handling and state.
 *
 * Everything is asynchronous here, and this class handles that stuff through a series of
 * "manager" classes.
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

  // Managers performing the various actions
  private val permissionManager: PermissionManager = PermissionManager(this)
  private val bleScanner: BleScanManager = BleScanManager(this)
  private val wifiScanner: WifiScanManager = WifiScanManager(this)
  private val wifiProvisioner: WifiProvisionManager = WifiProvisionManager(this)

  private lateinit var platformContext: Context
  lateinit var platformActivity: Activity

  val espManager: ESPProvisionManager get() = ESPProvisionManager.getInstance(platformContext)

  // Logging shortcuts
  fun d(msg: String) = Log.d(logTag, msg)
  fun e(msg: String) = Log.e(logTag, msg)
  fun i(msg: String) = Log.i(logTag, msg)

  fun connector(deviceName: String): BleConnector? {
    return devices[deviceName]
  }

  fun hasAttachedActivity(): Boolean {
    return this::platformActivity.isInitialized
  }

  /**
   * Connect to a named device with proofOfPossession string, and once connected, execute the
   * callback.
   */
  fun connect(
      conn: BleConnector,
      proofOfPossession: String,
      onConnectCallback: (ESPDevice) -> Unit,
      onErrorCallback: (String, String, String?) -> Unit
  ) {
    val esp = espManager.createESPDevice(ESPConstants.TransportType.TRANSPORT_BLE, ESPConstants.SecurityType.SECURITY_1)
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
          "ESP device did not report a successful BLE connection within timeout"
      )
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
    permissionManager.ensure(fun(granted: Boolean) {
      if (!granted) {
        result.error("E_PERMISSION", "Bluetooth permissions not granted", null)
        return
      }
      val ctx = CallContext(call, result)
      when (call.method) {
        platformVersionMethod -> getPlatformVersion(ctx)
        scanBleMethod -> bleScanner.call(ctx)
        scanWifiMethod -> wifiScanner.call(ctx)
        provisionWifiMethod -> wifiProvisioner.call(ctx)
        else -> result.notImplemented()
      }
    })
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


class BleScanManager(boss: Boss) : ActionManager(boss) {

  @SuppressLint("MissingPermission")
  override fun call(ctx: CallContext) {
    boss.d("searchBleEspDevices: start")
    val prefix = ctx.arg("prefix") ?: return
    boss.devices.clear()
    var resolved = false
    fun resolveError(code: String, message: String, details: String?) {
      if (resolved) {
        return
      }
      resolved = true
      ctx.result.error(code, message, details)
    }
    fun resolveSuccess(devices: List<String>) {
      if (resolved) {
        return
      }
      resolved = true
      ctx.result.success(ArrayList<String>(devices))
    }

    boss.espManager.searchBleEspDevices(prefix, object : BleScanListener {
      override fun scanStartFailed() {
        boss.e("searchBleEspDevices: scanStartFailed")
        resolveError("E_BLE_SCAN_START", "BLE scan failed to start", "Espressif BLE scan could not be started")
      }

      override fun onPeripheralFound(device: BluetoothDevice?, scanResult: ScanResult?) {
        device ?: return
        scanResult ?: return
        val name = device.name ?: device.address
        boss.devices[name] = BleConnector(device, scanResult)
      }

      override fun scanCompleted() {
        resolveSuccess(boss.devices.keys.toList())
        boss.d("searchBleEspDevices: scanComplete")
      }

      override fun onFailure(e: java.lang.Exception?) {
        boss.e("searchBleEspDevices: onFailure $e")
        resolveError("E_BLE_SCAN", "BLE scan failed", "Exception details $e")
      }

    })
  }

}

class WifiScanManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    val name = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val conn = boss.connector(name)
    if (conn == null) {
      ctx.result.error("E_DEVICE_NOT_FOUND", "WiFi scan failed", "No scanned BLE device named $name")
      return
    }
    boss.networks.clear()
    boss.d("esp connect: start")
    var resolved = false
    fun resolveError(code: String, message: String, details: String?) {
      if (resolved) {
        return
      }
      resolved = true
      ctx.result.error(code, message, details)
    }
    fun resolveSuccess(networks: List<String>) {
      if (resolved) {
        return
      }
      resolved = true
      Handler(Looper.getMainLooper()).post {
        ctx.result.success(ArrayList<String>(networks))
      }
    }
    boss.connect(
        conn,
        proofOfPossession,
        { esp ->
      boss.d("scanNetworks: start")
      esp.scanNetworks(object : WiFiScanListener {
        override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>?) {
          wifiList?.forEach { boss.networks.add(it.wifiName) }
          boss.d("scanNetworks: complete ${boss.networks}")
          resolveSuccess(boss.networks.toList())
          esp.disconnectDevice()
        }

        override fun onWiFiScanFailed(e: java.lang.Exception?) {
          boss.e("scanNetworks: error $e")
          resolveError("E1", "WiFi scan failed", "Exception details $e")
          esp.disconnectDevice()
        }
      })
    },
        { code, message, details ->
          resolveError(code, message, details)
        }
    )
  }
}


class WifiProvisionManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    boss.e("provisionWifi ${ctx.call.arguments}")
    val ssid = ctx.arg("ssid") ?: return
    val passphrase = ctx.arg("passphrase") ?: return
    val deviceName = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val conn = boss.connector(deviceName)
    if (conn == null) {
      ctx.result.error("E_DEVICE_NOT_FOUND", "WiFi provisioning failed", "No scanned BLE device named $deviceName")
      return
    }

    var resolved = false
    fun resolve(success: Boolean) {
      if (resolved) {
        return
      }
      resolved = true
      ctx.result.success(success)
    }
    fun resolveError(code: String, message: String, details: String?) {
      if (resolved) {
        return
      }
      resolved = true
      ctx.result.error(code, message, details)
    }

    boss.connect(
        conn,
        proofOfPossession,
        { esp ->
      boss.d("provision: start")
      esp.provision(ssid, passphrase, object : ProvisionListener {
        override fun createSessionFailed(e: java.lang.Exception?) {
          boss.e("wifiprovision createSessionFailed $e")
          resolve(false)
          esp.disconnectDevice()
        }

        override fun wifiConfigSent() {
          boss.d("wifiConfigSent")
        }

        override fun wifiConfigFailed(e: java.lang.Exception?) {
          boss.e("wifiConfiFailed $e")
          resolve(false)
          esp.disconnectDevice()
        }

        override fun wifiConfigApplied() {
          boss.d("wifiConfigApplied")
        }

        override fun wifiConfigApplyFailed(e: java.lang.Exception?) {
          boss.e("wifiConfigApplyFailed $e")
          resolve(false)
          esp.disconnectDevice()
        }

        override fun provisioningFailedFromDevice(failureReason: ESPConstants.ProvisionFailureReason?) {
          boss.e("provisioningFailedFromDevice $failureReason")
          resolve(false)
          esp.disconnectDevice()
        }

        override fun deviceProvisioningSuccess() {
          boss.d("deviceProvisioningSuccess")
          resolve(true)
          esp.disconnectDevice()
        }

        override fun onProvisioningFailed(e: java.lang.Exception?) {
          boss.e("onProvisioningFailed $e")
          resolve(false)
          esp.disconnectDevice()
        }

      })
    },
        { code, message, details ->
          resolveError(code, message, details)
        }
    )
  }

}


/** FlutterEspBleProvPlugin */
class FlutterEspBleProvPlugin : FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {

  private val logTag = "FlutterEspBleProvChannel"
  private val boss = Boss()
  private lateinit var channel: MethodChannel
  private var activityBinding: ActivityPluginBinding? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(logTag, "onAttachedToEngine: $binding")
    channel = MethodChannel(binding.binaryMessenger, "flutter_esp_ble_prov")
    channel.setMethodCallHandler(this)
    boss.attachContext(binding.applicationContext)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(logTag, "onDetachedFromEngine: $binding")
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d(logTag, "onMethodCall: ${call.method} ${call.arguments}")
    boss.call(call, result)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Log.d(logTag, "onAttachedToActivity: $binding")
    init(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    Log.d(logTag, "onDetachedFromActivityForConfigChanges")
    activityBinding?.let { tearDown(it) }
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    Log.d(logTag, "onReattachedToActivityForConfigChanges: $binding")
    init(binding)
  }

  override fun onDetachedFromActivity() {
    Log.d(logTag, "onDetachedFromActivity")
    activityBinding?.let { tearDown(it) }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    Log.d(logTag, "onActivityResult $requestCode $resultCode $data")
    return false
  }

  private fun init(binding: ActivityPluginBinding) {
    activityBinding = binding;
    binding.addActivityResultListener(this)
    boss.attachBinding(binding)
    boss.attachActivity(binding.activity)
  }

  private fun tearDown(binding: ActivityPluginBinding) {
    binding.removeActivityResultListener(this)
    boss.detachBinding(binding)
    activityBinding = null;
  }
}
