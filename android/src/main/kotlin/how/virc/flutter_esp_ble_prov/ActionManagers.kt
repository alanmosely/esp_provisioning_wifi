package how.virc.flutter_esp_ble_prov

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import android.os.Handler
import android.os.Looper
import com.espressif.provisioning.ESPConstants
import com.espressif.provisioning.ESPDevice
import com.espressif.provisioning.WiFiAccessPoint
import com.espressif.provisioning.listeners.BleScanListener
import com.espressif.provisioning.listeners.ProvisionListener
import com.espressif.provisioning.listeners.WiFiScanListener

abstract class ActionManager(protected val boss: Boss) {
  abstract fun call(ctx: CallContext)
}

class BleScanManager(boss: Boss) : ActionManager(boss) {

  @SuppressLint("MissingPermission")
  override fun call(ctx: CallContext) {
    boss.d("searchBleEspDevices: start")
    val prefix = ctx.arg("prefix") ?: return
    val operationToken = boss.startOperation()
    boss.devices.clear()
    var resolved = false

    fun resolveError(code: String, message: String, details: String?) {
      if (resolved || !boss.isOperationActive(operationToken)) {
        return
      }
      resolved = true
      ctx.result.error(code, message, details)
    }

    fun resolveSuccess(devices: List<String>) {
      if (resolved || !boss.isOperationActive(operationToken)) {
        return
      }
      resolved = true
      ctx.result.success(ArrayList<String>(devices))
    }

    boss.espManager.searchBleEspDevices(prefix, object : BleScanListener {
      override fun scanStartFailed() {
        boss.e("searchBleEspDevices: scanStartFailed")
        resolveError(
            ErrorCodes.BLE_SCAN_START_FAILED,
            "BLE scan failed to start",
            "Espressif BLE scan could not be started")
      }

      override fun onPeripheralFound(device: BluetoothDevice?, scanResult: ScanResult?) {
        if (!boss.isOperationActive(operationToken)) {
          return
        }
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
        resolveError(ErrorCodes.BLE_SCAN_FAILED, "BLE scan failed", "Exception details $e")
      }
    })
  }
}

class WifiScanManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    val name = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val connectTimeoutMs = ctx.optionalInt(ArgumentNames.CONNECT_TIMEOUT_MS)
        ?.takeIf { it > 0 }
        ?.toLong()
        ?: Boss.DEFAULT_CONNECT_TIMEOUT_MS
    val operationToken = boss.startOperation()
    val conn = boss.connector(name)
    if (conn == null) {
      if (boss.isOperationActive(operationToken)) {
        ctx.result.error(
            ErrorCodes.DEVICE_NOT_FOUND,
            "WiFi scan failed",
            "No scanned BLE device named $name")
      }
      return
    }

    boss.networks.clear()
    boss.d("esp connect: start")
    var resolved = false

    fun resolveError(code: String, message: String, details: String?) {
      if (resolved || !boss.isOperationActive(operationToken)) {
        return
      }
      resolved = true
      ctx.result.error(code, message, details)
    }

    fun resolveSuccess(networks: List<String>) {
      if (resolved || !boss.isOperationActive(operationToken)) {
        return
      }
      resolved = true
      Handler(Looper.getMainLooper()).post {
        if (!boss.isOperationActive(operationToken)) {
          return@post
        }
        ctx.result.success(ArrayList<String>(networks))
      }
    }

    boss.connect(
        conn,
        proofOfPossession,
        operationToken,
        connectTimeoutMs,
        { esp ->
          if (!boss.isOperationActive(operationToken)) {
            disconnect(esp)
            return@connect
          }
          boss.d("scanNetworks: start")
          esp.scanNetworks(object : WiFiScanListener {
            override fun onWifiListReceived(wifiList: ArrayList<WiFiAccessPoint>?) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              wifiList?.forEach { boss.networks.add(it.wifiName) }
              boss.d("scanNetworks: complete (${boss.networks.size} networks)")
              resolveSuccess(boss.networks.toList())
              disconnect(esp)
            }

            override fun onWiFiScanFailed(e: java.lang.Exception?) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.e("scanNetworks: error $e")
              resolveError(ErrorCodes.WIFI_SCAN_FAILED, "WiFi scan failed", "Exception details $e")
              disconnect(esp)
            }
          })
        },
        { code, message, details ->
          resolveError(code, message, details)
        })
  }

  private fun disconnect(esp: ESPDevice?) {
    try {
      esp?.disconnectDevice()
    } catch (e: Exception) {
      boss.e("disconnect failed: $e")
    } finally {
      boss.clearActiveDevice(esp)
    }
  }
}

class WifiProvisionManager(boss: Boss) : ActionManager(boss) {
  override fun call(ctx: CallContext) {
    boss.d("provisionWifi: start")
    val ssid = ctx.arg("ssid") ?: return
    val passphrase = ctx.arg("passphrase") ?: return
    val deviceName = ctx.arg("deviceName") ?: return
    val proofOfPossession = ctx.arg("proofOfPossession") ?: return
    val connectTimeoutMs = ctx.optionalInt(ArgumentNames.CONNECT_TIMEOUT_MS)
        ?.takeIf { it > 0 }
        ?.toLong()
        ?: Boss.DEFAULT_CONNECT_TIMEOUT_MS
    val operationToken = boss.startOperation()
    val conn = boss.connector(deviceName)
    if (conn == null) {
      if (boss.isOperationActive(operationToken)) {
        ctx.result.error(
            ErrorCodes.DEVICE_NOT_FOUND,
            "WiFi provisioning failed",
            "No scanned BLE device named $deviceName")
      }
      return
    }

    var resolved = false

    fun resolve(success: Boolean) {
      if (resolved || !boss.isOperationActive(operationToken)) {
        return
      }
      resolved = true
      ctx.result.success(success)
    }

    fun resolveError(code: String, message: String, details: String?) {
      if (resolved || !boss.isOperationActive(operationToken)) {
        return
      }
      resolved = true
      ctx.result.error(code, message, details)
    }

    boss.connect(
        conn,
        proofOfPossession,
        operationToken,
        connectTimeoutMs,
        { esp ->
          if (!boss.isOperationActive(operationToken)) {
            disconnect(esp)
            return@connect
          }
          boss.d("provision: start")
          esp.provision(ssid, passphrase, object : ProvisionListener {
            override fun createSessionFailed(e: java.lang.Exception?) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.e("wifiprovision createSessionFailed $e")
              resolve(false)
              disconnect(esp)
            }

            override fun wifiConfigSent() {
              boss.d("wifiConfigSent")
            }

            override fun wifiConfigFailed(e: java.lang.Exception?) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.e("wifiConfiFailed $e")
              resolve(false)
              disconnect(esp)
            }

            override fun wifiConfigApplied() {
              boss.d("wifiConfigApplied")
            }

            override fun wifiConfigApplyFailed(e: java.lang.Exception?) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.e("wifiConfigApplyFailed $e")
              resolve(false)
              disconnect(esp)
            }

            override fun provisioningFailedFromDevice(
                failureReason: ESPConstants.ProvisionFailureReason?
            ) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.e("provisioningFailedFromDevice $failureReason")
              resolve(false)
              disconnect(esp)
            }

            override fun deviceProvisioningSuccess() {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.d("deviceProvisioningSuccess")
              resolve(true)
              disconnect(esp)
            }

            override fun onProvisioningFailed(e: java.lang.Exception?) {
              if (!boss.isOperationActive(operationToken)) {
                disconnect(esp)
                return
              }
              boss.e("onProvisioningFailed $e")
              resolve(false)
              disconnect(esp)
            }
          })
        },
        { code, message, details ->
          resolveError(code, message, details)
        })
  }

  private fun disconnect(esp: ESPDevice?) {
    try {
      esp?.disconnectDevice()
    } catch (e: Exception) {
      boss.e("disconnect failed: $e")
    } finally {
      boss.clearActiveDevice(esp)
    }
  }
}
