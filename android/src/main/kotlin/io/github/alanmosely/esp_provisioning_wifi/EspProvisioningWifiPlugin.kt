package io.github.alanmosely.esp_provisioning_wifi

import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** EspProvisioningWifiPlugin */
class EspProvisioningWifiPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {
  private val logTag = "EspProvisioningWifi"
  private val boss = Boss()
  private lateinit var channel: MethodChannel
  private var activityBinding: ActivityPluginBinding? = null
  private var bluetooth: BluetoothReadiness? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(logTag, "onAttachedToEngine: $binding")
    channel = MethodChannel(binding.binaryMessenger, MethodNames.CHANNEL)
    channel.setMethodCallHandler(this)
    boss.attachContext(binding.applicationContext)
    bluetooth = BluetoothReadiness(binding.applicationContext, boss, boss::ensurePermissions)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    Log.d(logTag, "onDetachedFromEngine: $binding")
    channel.setMethodCallHandler(null)
    bluetooth?.cancel()
    bluetooth = null
    boss.cancelOperations()
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    Log.d(logTag, "onMethodCall: ${call.method}")
    if (call.method == MethodNames.CANCEL_BLUETOOTH_READINESS) {
      val arguments = call.arguments as? Map<*, *>
      bluetooth?.cancel((arguments?.get("requestId") as? Number)?.toInt())
      result.success(null)
      return
    }
    if (call.method == MethodNames.ENSURE_BLUETOOTH_READY) {
      val arguments = call.arguments as? Map<*, *>
      val id = (arguments?.get("requestId") as? Number)?.toInt()
      val timeout = (arguments?.get("timeoutMs") as? Number)?.toLong()
      val requestEnable = arguments?.get("requestEnable") as? Boolean
      if (id == null || timeout == null || timeout !in 1L..120000L || requestEnable == null) {
        result.error(ErrorCodes.MISSING_ARGUMENT, "Invalid Bluetooth readiness arguments", null)
      } else {
        bluetooth?.ensureReady(id, requestEnable, timeout, result)
            ?: result.error("E_NO_ENGINE", "Bluetooth plugin is detached", null)
      }
      return
    }
    if (call.method != MethodNames.GET_PLATFORM_VERSION) bluetooth?.cancel()
    boss.call(call, result)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    Log.d(logTag, "onAttachedToActivity: $binding")
    init(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    Log.d(logTag, "onDetachedFromActivityForConfigChanges")
    activityBinding?.let { tearDown(it, permanent = false) }
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    Log.d(logTag, "onReattachedToActivityForConfigChanges: $binding")
    init(binding)
  }

  override fun onDetachedFromActivity() {
    Log.d(logTag, "onDetachedFromActivity")
    activityBinding?.let { tearDown(it, permanent = true) }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    Log.d(logTag, "onActivityResult $requestCode $resultCode $data")
    return bluetooth?.onActivityResult(requestCode, resultCode) ?: false
  }

  private fun init(binding: ActivityPluginBinding) {
    activityBinding = binding
    binding.addActivityResultListener(this)
    boss.attachBinding(binding)
    boss.attachActivity(binding.activity)
    bluetooth?.attach(binding.activity)
  }

  private fun tearDown(binding: ActivityPluginBinding, permanent: Boolean) {
    bluetooth?.detach(permanent)
    binding.removeActivityResultListener(this)
    boss.detachBinding(binding)
    boss.detachActivity(permanent)
    activityBinding = null
  }
}
