package how.virc.flutter_esp_ble_prov

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import com.espressif.provisioning.ESPConstants
import com.espressif.provisioning.ESPDevice
import com.espressif.provisioning.WiFiAccessPoint
import com.espressif.provisioning.listeners.BleScanListener
import com.espressif.provisioning.listeners.ProvisionListener
import com.espressif.provisioning.listeners.ResponseListener
import com.espressif.provisioning.listeners.WiFiScanListener
import java.nio.charset.StandardCharsets

abstract class ActionManager(protected val boss: Boss) {
  abstract fun call(ctx: CallContext)

  /**
   * Starts a fresh operation (cancelling any in-flight one) and returns its
   * resolver, registered with the boss so a later cancellation can resolve it.
   */
  protected fun startResolver(ctx: CallContext): OperationResolver {
    val operationToken = boss.startOperation()
    val resolver = OperationResolver(boss, operationToken, ctx.result)
    boss.trackResolver(resolver)
    return resolver
  }

  protected fun disconnect(esp: ESPDevice?) {
    try {
      esp?.disconnectDevice()
    } catch (e: Exception) {
      boss.e("disconnect failed: $e")
    } finally {
      boss.clearActiveDevice(esp)
    }
  }
}

class BleScanManager(boss: Boss) : ActionManager(boss) {

  @SuppressLint("MissingPermission")
  override fun call(ctx: CallContext) {
    boss.d("searchBleEspDevices: start")
    val prefix = ctx.arg("prefix") ?: return
    val resolver = startResolver(ctx)
    boss.devices.clear()

    boss.espManager.searchBleEspDevices(prefix, object : BleScanListener {
      override fun scanStartFailed() {
        boss.e("searchBleEspDevices: scanStartFailed")
        resolver.error(
            ErrorCodes.BLE_SCAN_START_FAILED,
            "BLE scan failed to start",
            "Espressif BLE scan could not be started")
      }

      override fun onPeripheralFound(device: BluetoothDevice?, scanResult: ScanResult?) {
        if (!boss.isOperationActive(resolver.operationToken)) {
          return
        }
        device ?: return
        scanResult ?: return
        val name = device.name ?: device.address
        boss.devices[name] = BleConnector(device, scanResult)
      }

      override fun scanCompleted() {
        resolver.success(ArrayList<String>(boss.devices.keys.toList()))
        boss.d("searchBleEspDevices: scanComplete")
      }

      override fun onFailure(e: java.lang.Exception?) {
        boss.e("searchBleEspDevices: onFailure $e")
        resolver.error(ErrorCodes.BLE_SCAN_FAILED, "BLE scan failed", "Exception details $e")
      }
    })
  }
}

class WifiScanManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    val name = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val connectTimeoutMs = ctx.connectTimeoutMs()
    val resolver = startResolver(ctx)
    val conn = boss.connector(name)
    if (conn == null) {
      resolver.error(
          ErrorCodes.DEVICE_NOT_FOUND,
          "WiFi scan failed",
          "No scanned BLE device named $name")
      return
    }

    boss.networks.clear()
    boss.d("esp connect: start")

    boss.connect(
        conn,
        proofOfPossession,
        resolver.operationToken,
        connectTimeoutMs,
        { esp ->
          if (resolver.cancelledIfInactive()) {
            disconnect(esp)
            return@connect
          }
          boss.d("scanNetworks: start")
          esp.scanNetworks(object : WiFiScanListener {
            override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>?) {
              if (resolver.cancelledIfInactive()) {
                disconnect(esp)
                return
              }
              wifiList?.forEach { boss.networks.add(it.wifiName) }
              boss.d("scanNetworks: complete (${boss.networks.size} networks)")
              resolver.success(ArrayList<String>(boss.networks.toList()))
              disconnect(esp)
            }

            override fun onWiFiScanFailed(e: java.lang.Exception?) {
              boss.e("scanNetworks: error $e")
              resolver.error(ErrorCodes.WIFI_SCAN_FAILED, "WiFi scan failed", "Exception details $e")
              disconnect(esp)
            }
          })
        },
        { code, message, details ->
          resolver.error(code, message, details)
        })
  }
}

class CustomDataManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    val name = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val endpoint = ctx.arg(ArgumentNames.ENDPOINT) ?: return
    val payload = ctx.optionalString(ArgumentNames.PAYLOAD) ?: ""
    val connectTimeoutMs = ctx.connectTimeoutMs()
    val resolver = startResolver(ctx)
    val conn = boss.connector(name)
    if (conn == null) {
      resolver.error(
          ErrorCodes.DEVICE_NOT_FOUND,
          "Custom data request failed",
          "No scanned BLE device named $name")
      return
    }

    boss.connect(
        conn,
        proofOfPossession,
        resolver.operationToken,
        connectTimeoutMs,
        { esp ->
          if (resolver.cancelledIfInactive()) {
            disconnect(esp)
            return@connect
          }
          esp.sendDataToCustomEndPoint(
              endpoint,
              payload.toByteArray(StandardCharsets.UTF_8),
              object : ResponseListener {
                override fun onSuccess(returnData: ByteArray?) {
                  if (resolver.cancelledIfInactive()) {
                    disconnect(esp)
                    return
                  }
                  val response = if (returnData == null) {
                    ""
                  } else {
                    String(returnData, StandardCharsets.UTF_8)
                  }
                  resolver.success(response)
                  disconnect(esp)
                }

                override fun onFailure(e: java.lang.Exception?) {
                  resolver.error(
                      ErrorCodes.CUSTOM_DATA_FAILED,
                      "Custom data request failed",
                      "Exception details $e")
                  disconnect(esp)
                }
              })
        },
        { code, message, details ->
          resolver.error(code, message, details)
        })
  }
}

class WifiProvisionManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    boss.d("provisionWifi: start")
    val ssid = ctx.arg("ssid") ?: return
    val passphrase = ctx.arg("passphrase") ?: return
    val deviceName = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val connectTimeoutMs = ctx.connectTimeoutMs()
    val resolver = startResolver(ctx)
    val conn = boss.connector(deviceName)
    if (conn == null) {
      resolver.error(
          ErrorCodes.DEVICE_NOT_FOUND,
          "WiFi provisioning failed",
          "No scanned BLE device named $deviceName")
      return
    }

    boss.connect(
        conn,
        proofOfPossession,
        resolver.operationToken,
        connectTimeoutMs,
        { esp ->
          if (resolver.cancelledIfInactive()) {
            disconnect(esp)
            return@connect
          }
          boss.d("provision: start")
          esp.provision(ssid, passphrase, object : ProvisionListener {
            override fun createSessionFailed(e: java.lang.Exception?) {
              boss.e("wifiprovision createSessionFailed $e")
              resolver.success(false)
              disconnect(esp)
            }

            override fun wifiConfigSent() {
              boss.d("wifiConfigSent")
            }

            override fun wifiConfigFailed(e: java.lang.Exception?) {
              boss.e("wifiConfigFailed $e")
              resolver.success(false)
              disconnect(esp)
            }

            override fun wifiConfigApplied() {
              boss.d("wifiConfigApplied")
            }

            override fun wifiConfigApplyFailed(e: java.lang.Exception?) {
              boss.e("wifiConfigApplyFailed $e")
              resolver.success(false)
              disconnect(esp)
            }

            override fun provisioningFailedFromDevice(
                failureReason: ESPConstants.ProvisionFailureReason?
            ) {
              boss.e("provisioningFailedFromDevice $failureReason")
              resolver.success(false)
              disconnect(esp)
            }

            override fun deviceProvisioningSuccess() {
              boss.d("deviceProvisioningSuccess")
              resolver.success(true)
              disconnect(esp)
            }

            override fun onProvisioningFailed(e: java.lang.Exception?) {
              boss.e("onProvisioningFailed $e")
              resolver.success(false)
              disconnect(esp)
            }
          })
        },
        { code, message, details ->
          resolver.error(code, message, details)
        })
  }
}
