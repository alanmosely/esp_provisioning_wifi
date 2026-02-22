import Flutter
import UIKit
import ESPProvision

private enum ErrorCodes {
    static let missingArgument = "E0"
    static let iosDeviceCreate = "E_DEVICE"
    static let deviceDisconnected = "DEVICE_DISCONNECTED"
    static let customData = "E_CUSTOM_DATA"
    static let cancelled = "E_CANCELLED"
    static let connectTimeout = "E_CONNECT_TIMEOUT"
}

private enum MethodNames {
    static let channel = "flutter_esp_ble_prov"
    static let getPlatformVersion = "getPlatformVersion"
    static let scanBleDevices = "scanBleDevices"
    static let scanWifiNetworks = "scanWifiNetworks"
    static let provisionWifi = "provisionWifi"
    static let fetchCustomData = "fetchCustomData"
    static let cancelOperations = "cancelOperations"
}

private enum ArgumentKeys {
    static let prefix = "prefix"
    static let deviceName = "deviceName"
    static let proofOfPossession = "proofOfPossession"
    static let ssid = "ssid"
    static let passphrase = "passphrase"
    static let endpoint = "endpoint"
    static let payload = "payload"
    static let connectTimeoutMs = "connectTimeoutMs"
}

private enum TimeoutDefaults {
    static let connectTimeoutMs = 15000
}

private final class ProvisionOperationCoordinator {
    private let lock = NSLock()
    private var currentOperationToken = 0
    private var activeDevice: ESPDevice?

    func startOperation() -> Int {
        lock.lock()
        defer { lock.unlock() }
        currentOperationToken += 1
        disconnectActiveDeviceLocked()
        return currentOperationToken
    }

    func cancelOperations() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        currentOperationToken += 1
        disconnectActiveDeviceLocked()
        return true
    }

    func isOperationActive(_ token: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentOperationToken == token
    }

    func trackActiveDevice(_ device: ESPDevice?) {
        lock.lock()
        defer { lock.unlock() }
        activeDevice = device
    }

    func clearActiveDevice(_ device: ESPDevice?) {
        lock.lock()
        defer { lock.unlock() }
        if device == nil || activeDevice === device {
            activeDevice = nil
        }
    }

    private func disconnectActiveDeviceLocked() {
        activeDevice?.disconnect()
        activeDevice = nil
    }
}

public class SwiftFlutterEspBleProvPlugin: NSObject, FlutterPlugin {
    private let coordinator = ProvisionOperationCoordinator()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: MethodNames.channel, binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterEspBleProvPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == MethodNames.getPlatformVersion {
            result("iOS " + UIDevice.current.systemVersion)
            return
        }

        if call.method == MethodNames.cancelOperations {
            result(coordinator.cancelOperations())
            return
        }

        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: ErrorCodes.missingArgument, message: "Invalid arguments", details: "Expected arguments map for method \(call.method)"))
            return
        }

        if call.method == MethodNames.scanBleDevices {
            guard let prefix = requiredStringArg(ArgumentKeys.prefix, in: arguments, result: result) else { return }
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: TimeoutDefaults.connectTimeoutMs
            )
            provisionService.searchDevices(prefix: prefix)
        } else if call.method == MethodNames.scanWifiNetworks {
            guard let deviceName = requiredStringArg(ArgumentKeys.deviceName, in: arguments, result: result) else { return }
            guard let proofOfPossession = requiredStringArg(ArgumentKeys.proofOfPossession, in: arguments, result: result) else { return }
            let connectTimeoutMs = optionalConnectTimeoutMs(in: arguments)
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: connectTimeoutMs
            )
            provisionService.scanWifiNetworks(deviceName: deviceName, proofOfPossession: proofOfPossession)
        } else if call.method == MethodNames.provisionWifi {
            guard let deviceName = requiredStringArg(ArgumentKeys.deviceName, in: arguments, result: result) else { return }
            guard let proofOfPossession = requiredStringArg(ArgumentKeys.proofOfPossession, in: arguments, result: result) else { return }
            guard let ssid = requiredStringArg(ArgumentKeys.ssid, in: arguments, result: result) else { return }
            guard let passphrase = requiredStringArg(ArgumentKeys.passphrase, in: arguments, result: result) else { return }
            let connectTimeoutMs = optionalConnectTimeoutMs(in: arguments)
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: connectTimeoutMs
            )
            provisionService.provision(
                deviceName: deviceName,
                proofOfPossession: proofOfPossession,
                ssid: ssid,
                passphrase: passphrase
            )
        } else if call.method == MethodNames.fetchCustomData {
            guard let deviceName = requiredStringArg(ArgumentKeys.deviceName, in: arguments, result: result) else { return }
            guard let proofOfPossession = requiredStringArg(ArgumentKeys.proofOfPossession, in: arguments, result: result) else { return }
            guard let endpoint = requiredStringArg(ArgumentKeys.endpoint, in: arguments, result: result) else { return }
            let payload = arguments[ArgumentKeys.payload] as? String ?? ""
            let connectTimeoutMs = optionalConnectTimeoutMs(in: arguments)
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: connectTimeoutMs
            )
            provisionService.fetchCustomData(
                deviceName: deviceName,
                proofOfPossession: proofOfPossession,
                endpoint: endpoint,
                payload: payload
            )
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func requiredStringArg(
        _ key: String,
        in arguments: [String: Any],
        result: @escaping FlutterResult
    ) -> String? {
        guard let value = arguments[key] as? String else {
            result(FlutterError(code: ErrorCodes.missingArgument, message: "Missing argument: \(key)", details: nil))
            return nil
        }
        return value
    }

    private func optionalConnectTimeoutMs(in arguments: [String: Any]) -> Int {
        guard let value = arguments[ArgumentKeys.connectTimeoutMs] as? NSNumber else {
            return TimeoutDefaults.connectTimeoutMs
        }
        let timeoutMs = value.intValue
        return timeoutMs > 0 ? timeoutMs : TimeoutDefaults.connectTimeoutMs
    }
    
}

protocol ProvisionService {
    var result: FlutterResult { get }
    func searchDevices(prefix: String) -> Void
    func scanWifiNetworks(deviceName: String, proofOfPossession: String) -> Void
    func provision(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String) -> Void
    func fetchCustomData(deviceName: String, proofOfPossession: String, endpoint: String, payload: String) -> Void
}

private class BLEProvisionService: ProvisionService {
    fileprivate let result: FlutterResult
    private let coordinator: ProvisionOperationCoordinator
    private let operationToken: Int
    private let connectTimeoutMs: Int
    private var didResolve = false
    
    init(
        result: @escaping FlutterResult,
        coordinator: ProvisionOperationCoordinator,
        operationToken: Int,
        connectTimeoutMs: Int
    ) {
        self.result = result
        self.coordinator = coordinator
        self.operationToken = operationToken
        self.connectTimeoutMs = connectTimeoutMs
    }

    private func resolve(_ value: Any?) {
        if didResolve {
            return
        }
        didResolve = true
        result(value)
    }

    private func resolveCancelledIfInactive() -> Bool {
        if coordinator.isOperationActive(operationToken) {
            return false
        }
        resolve(FlutterError(code: ErrorCodes.cancelled, message: "Operation cancelled", details: nil))
        return true
    }

    private func fail(error: ESPError) {
        if resolveCancelledIfInactive() {
            return
        }
        resolve(FlutterError(code: String(error.code), message: error.description, details: nil))
    }

    private func disconnect(device: ESPDevice?) {
        device?.disconnect()
        coordinator.clearActiveDevice(device)
    }
    
    func searchDevices(prefix: String) {
        if resolveCancelledIfInactive() {
            return
        }
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: prefix, transport:.ble, security:.secure) { deviceList, error in
            if self.resolveCancelledIfInactive() {
                return
            }
            if let error = error {
                self.fail(error: error)
                return
            }
            self.resolve((deviceList ?? []).map({ (device: ESPDevice) -> String in
                return device.name
            }))
        }
    }
    
    func scanWifiNetworks(deviceName: String, proofOfPossession: String) {
        connect(deviceName: deviceName, proofOfPossession: proofOfPossession) {
            device in
            device.scanWifiList { wifiList, error in
                if self.resolveCancelledIfInactive() {
                    self.disconnect(device: device)
                    return
                }
                if let error = error {
                    NSLog("Error scanning Wi-Fi networks")
                    self.fail(error: error)
                    self.disconnect(device: device)
                    return
                }
                self.resolve((wifiList ?? []).map({(networks: ESPWifiNetwork) -> String in return networks.ssid}))
                self.disconnect(device: device)
            }
        }
    }
    
    func provision(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String) {
        connect(deviceName: deviceName, proofOfPossession: proofOfPossession){
            device in
            device.provision(ssid: ssid, passPhrase: passphrase) { status in
                if self.resolveCancelledIfInactive() {
                    self.disconnect(device: device)
                    return
                }
                switch status {
                case .success:
                    NSLog("Device provisioning succeeded")
                    self.resolve(true)
                    self.disconnect(device: device)
                case .configApplied:
                    NSLog("Wi-Fi config applied")
                case .failure:
                    NSLog("Device provisioning failed")
                    self.resolve(false)
                    self.disconnect(device: device)
                }
            }
        }
    }

    func fetchCustomData(
        deviceName: String,
        proofOfPossession: String,
        endpoint: String,
        payload: String
    ) {
        connect(deviceName: deviceName, proofOfPossession: proofOfPossession) {
            device in
            let payloadData = payload.data(using: .utf8) ?? Data()
            device.sendData(path: endpoint, data: payloadData) { returnData, error in
                if self.resolveCancelledIfInactive() {
                    self.disconnect(device: device)
                    return
                }
                if let error = error {
                    self.resolve(
                        FlutterError(
                            code: ErrorCodes.customData,
                            message: "Custom data request failed",
                            details: String(describing: error)
                        )
                    )
                    self.disconnect(device: device)
                    return
                }
                guard let returnData = returnData else {
                    self.resolve("")
                    self.disconnect(device: device)
                    return
                }
                let response = String(data: returnData, encoding: .utf8) ?? ""
                self.resolve(response)
                self.disconnect(device: device)
            }
        }
    }
    
    private func connect(
        deviceName: String,
        proofOfPossession: String,
        completionHandler: @escaping (ESPDevice) -> Void
    ) {
        if resolveCancelledIfInactive() {
            return
        }
        ESPProvisionManager.shared.createESPDevice(deviceName: deviceName, transport: .ble, security: .secure, proofOfPossession: proofOfPossession) { espDevice, error in
            if self.resolveCancelledIfInactive() {
                self.disconnect(device: espDevice)
                return
            }
            if let error = error {
                self.fail(error: error)
                return
            }
            guard let espDevice = espDevice else {
                self.resolve(FlutterError(code: ErrorCodes.iosDeviceCreate, message: "Failed to create ESP device", details: nil))
                return
            }
            self.coordinator.trackActiveDevice(espDevice)
            var connectResolved = false
            var timeoutWorkItem: DispatchWorkItem?

            func resolveConnect(_ block: () -> Void) {
                if connectResolved {
                    return
                }
                connectResolved = true
                timeoutWorkItem?.cancel()
                block()
            }

            timeoutWorkItem = DispatchWorkItem {
                resolveConnect {
                    if self.resolveCancelledIfInactive() {
                        self.disconnect(device: espDevice)
                        return
                    }
                    self.resolve(
                        FlutterError(
                            code: ErrorCodes.connectTimeout,
                            message: "Connection timed out",
                            details: "ESP device did not report a successful BLE connection within \(self.connectTimeoutMs) ms"
                        )
                    )
                    self.disconnect(device: espDevice)
                }
            }
            if let timeoutWorkItem = timeoutWorkItem {
                let timeoutSeconds = Double(self.connectTimeoutMs) / 1000.0
                DispatchQueue.main.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeoutWorkItem)
            }
            espDevice.connect { status in
                resolveConnect {
                    if self.resolveCancelledIfInactive() {
                        self.disconnect(device: espDevice)
                        return
                    }
                    switch status {
                    case .connected:
                        completionHandler(espDevice)
                    case let .failedToConnect(error):
                        self.fail(error: error)
                        self.disconnect(device: espDevice)
                    default:
                        self.resolve(FlutterError(code: ErrorCodes.deviceDisconnected, message: nil, details: nil))
                        self.disconnect(device: espDevice)
                    }
                }
            }
        }
    }
    
}
