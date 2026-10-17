import CoreBluetooth
import Flutter

/// All state and Flutter replies are confined to the platform main queue.
final class BluetoothReadiness {
    private let session = BluetoothReadinessSession(makeAdapter: { CoreBluetoothReadinessAdapter() })

    func ensureReady(id: Int, timeoutMs: Int, result: @escaping FlutterResult) {
        session.ensureReady(id: id, timeoutMs: timeoutMs) { outcome in
            switch outcome {
            case .state(let state): result(state)
            case .cancelled:
                result(FlutterError(code: "E_CANCELLED", message: "Operation cancelled", details: nil))
            case .timedOut:
                result(FlutterError(code: "E_BLUETOOTH_TIMEOUT", message: "Bluetooth readiness timed out", details: nil))
            }
        }
    }

    func cancel(id: Int? = nil) { session.cancel(id: id) }
}

private final class CoreBluetoothReadinessAdapter: NSObject, ReadinessAdapter, CBCentralManagerDelegate {
    private var manager: CBCentralManager?
    private var changed: ((ReadinessState) -> Void)?

    func start(_ changed: @escaping (ReadinessState) -> Void) {
        self.changed = changed
        // Core Bluetooth owns authorization. iOS has no radio-enable API.
        manager = CBCentralManager(delegate: self, queue: .main,
            options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func stop() {
        changed = nil
        manager?.delegate = nil
        manager = nil
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central === manager else { return }
        switch central.state {
        case .poweredOn: changed?(.on)
        case .poweredOff: changed?(.off)
        case .unauthorized: changed?(.unauthorized)
        case .unsupported: changed?(.unavailable)
        case .unknown, .resetting: changed?(.waiting)
        @unknown default: changed?(.unknown)
        }
    }
}
