package how.virc.flutter_esp_ble_prov

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult
import android.os.Handler
import android.os.Looper
import com.espressif.provisioning.ESPConstants
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
              boss.d("scanNetworks: complete (${boss.networks.size} networks)")
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
    val conn = boss.connector(deviceName)
    if (conn == null) {
      ctx.result.error(
          "E_DEVICE_NOT_FOUND",
          "WiFi provisioning failed",
          "No scanned BLE device named $deviceName")
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
        })
  }
}
