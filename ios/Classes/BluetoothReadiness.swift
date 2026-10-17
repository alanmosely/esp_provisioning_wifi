import CoreBluetooth
import Flutter

/// All state and Flutter replies are confined to the platform main queue.
final class BluetoothReadiness: NSObject, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var pending: FlutterResult?
    private var requestId: Int?
    private var timeout: DispatchWorkItem?

    func ensureReady(id: Int, timeoutMs: Int, result: @escaping FlutterResult) {
        cancel()
        requestId = id
        pending = result
        let deadline = DispatchWorkItem { [weak self] in
            guard let self = self, self.requestId == id else { return }
            self.finish(FlutterError(code: "E_BLUETOOTH_TIMEOUT",
                message: "Bluetooth readiness timed out", details: nil))
        }
        timeout = deadline
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: deadline)
        // Core Bluetooth owns authorization. iOS does not expose a radio-enable API.
        // The app provides its existing guidance when the radio is powered off.
        manager = CBCentralManager(delegate: self, queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func cancel(id: Int? = nil) {
        guard pending != nil, id == nil || id == requestId else { return }
        finish(FlutterError(code: "E_CANCELLED", message: "Operation cancelled", details: nil))
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === manager, pending != nil else { return }
        switch central.state {
        case .poweredOn: finish("on")
        case .poweredOff: finish("off")
        case .unauthorized: finish("unauthorized")
        case .unsupported: finish("unavailable")
        case .unknown, .resetting: break // Wait within the original deadline.
        @unknown default: finish("unknown")
        }
    }

    private func finish(_ value: Any?) {
        guard let result = pending else { return }
        pending = nil
        requestId = nil
        timeout?.cancel()
        timeout = nil
        manager?.delegate = nil
        manager = nil
        result(value)
    }
}
