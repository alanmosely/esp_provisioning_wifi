package how.virc.flutter_esp_ble_prov

import android.bluetooth.BluetoothDevice
import android.bluetooth.le.ScanResult

/**
 * The data required to be able to connect to an Espressif BLE device.
 *
 * @param device The BLE device from a BLE scan.
 * @param scanResult The ScanResult from a BLE scan.
 */
class BleConnector(val device: BluetoothDevice, scanResult: ScanResult) {

  /**
   * The service ID used when connecting.
   */
  val primaryServiceUuid: String

  init {
    primaryServiceUuid = scanResult.scanRecord?.serviceUuids?.get(0)?.toString() ?: ""
  }
}
