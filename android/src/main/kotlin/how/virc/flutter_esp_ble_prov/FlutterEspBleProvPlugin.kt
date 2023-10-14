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

  lateinit var callback: (Boolean) -> Unit

  val callbacks = mutableMapOf<Int, (Boolean) -> Unit>()
  var lastCallbackId = 0

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
    callback = fCallback
    val toRequest: MutableList<String> = mutableListOf()
    for (p in permissions) {
      if (ActivityCompat.checkSelfPermission(boss.platformActivity, p) != PackageManager.PERMISSION_GRANTED) {
        toRequest.add(p)
      }
    }
    if (toRequest.size > 0) {
      ActivityCompat.requestPermissions(boss.platformActivity, toRequest.toTypedArray(), 0)
    } else {
      fCallback(true)
    }
  }

  /**
   * Called on permission request result.
   */
  override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray): Boolean {
    boss.d("permission result")
    if (this::callback.isInitialized) {
      callback(true)
    }
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

  /**
   * Connect to a named device with proofOfPossession string, and once connected, execute the
   * callback.
   */
  fun connect(conn: BleConnector, proofOfPossession: String, onConnectCallback: (ESPDevice) -> Unit) {
    val esp = espManager.createESPDevice(ESPConstants.TransportType.TRANSPORT_BLE, ESPConstants.SecurityType.SECURITY_1)
    EventBus.getDefault().register(object {
      @Subscribe(threadMode = ThreadMode.MAIN)
      fun onEvent(event: DeviceConnectionEvent) {
        d("bus event $event ${event.eventType}")
        when (event.eventType) {
          ESPConstants.EVENT_DEVICE_CONNECTED -> {
            EventBus.getDefault().unregister(this)
            esp.proofOfPossession = proofOfPossession
            onConnectCallback(esp)
          }
        }
      }
    })
    esp.connectBLEDevice(conn.device, conn.primaryServiceUuid)
  }

  fun call(call: MethodCall, result: Result) {
    permissionManager.ensure(fun(_: Boolean) {
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

    boss.espManager.searchBleEspDevices(prefix, object : BleScanListener {
      override fun scanStartFailed() {
        TODO("Not yet implemented")
      }

      override fun onPeripheralFound(device: BluetoothDevice?, scanResult: ScanResult?) {
        device ?: return
        scanResult ?: return
        boss.devices.put(device.name, BleConnector(device, scanResult))
      }

      override fun scanCompleted() {
        ctx.result.success(ArrayList<String>(boss.devices.keys))
        boss.d("searchBleEspDevices: scanComplete")
      }

      override fun onFailure(e: java.lang.Exception?) {
        TODO("Not yet implemented")
      }

    })
  }

}

class WifiScanManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    val name = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val conn = boss.connector(name) ?: return
    boss.d("esp connect: start")
    boss.connect(conn, proofOfPossession) { esp ->
      boss.d("scanNetworks: start")
      esp.scanNetworks(object : WiFiScanListener {
        override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>?) {
          wifiList ?: return
          wifiList.forEach { boss.networks.add(it.wifiName) }
          boss.d("scanNetworks: complete ${boss.networks}")
          Handler(Looper.getMainLooper()).post {
            ctx.result.success(ArrayList<String>(boss.networks))
          }
          boss.d("scanNetworks: complete 2 ${boss.networks}")
          esp.disconnectDevice()
        }

        override fun onWiFiScanFailed(e: java.lang.Exception?) {
          boss.e("scanNetworks: error $e")
          ctx.result.error("E1", "WiFi scan failed", "Exception details $e")
        }
      })
    }
  }
}


class WifiProvisionManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    boss.e("provisionWifi ${ctx.call.arguments}")
    val ssid = ctx.arg("ssid") ?: return
    val passphrase = ctx.arg("passphrase") ?: return
    val deviceName = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val conn = boss.connector(deviceName) ?: return

    boss.connect(conn, proofOfPossession) { esp ->
      boss.d("provision: start")
      esp.provision(ssid, passphrase, object : ProvisionListener {
        override fun createSessionFailed(e: java.lang.Exception?) {
          boss.e("wifiprovision createSessionFailed")
        }

        override fun wifiConfigSent() {
          boss.d("wifiConfigSent")
        }

        override fun wifiConfigFailed(e: java.lang.Exception?) {
          boss.e("wifiConfiFailed $e")
          ctx.result.success(false)
        }

        override fun wifiConfigApplied() {
          boss.d("wifiConfigApplied")
        }

        override fun wifiConfigApplyFailed(e: java.lang.Exception?) {
          boss.e("wifiConfigApplyFailed $e")
          ctx.result.success(false)
        }

        override fun provisioningFailedFromDevice(failureReason: ESPConstants.ProvisionFailureReason?) {
          boss.e("provisioningFailedFromDevice $failureReason")
          ctx.result.success(false)
        }

        override fun deviceProvisioningSuccess() {
          boss.d("deviceProvisioningSuccess")
          ctx.result.success(true)
        }

        override fun onProvisioningFailed(e: java.lang.Exception?) {
          boss.e("onProvisioningFailed")
          ctx.result.success(false)
        }

      })
    }
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
