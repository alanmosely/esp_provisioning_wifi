import Flutter
import UIKit
import ESPProvision

private enum ErrorCodes {
    static let missingArgument = "E0"
    static let wifiScanFailed = "E1"
    static let bleScanFailed = "E_BLE_SCAN"
    static let connectFailed = "E_CONNECT"
    static let iosDeviceCreate = "E_DEVICE"
    static let deviceNotFound = "E_DEVICE_NOT_FOUND"
    static let customData = "E_CUSTOM_DATA"
    static let cancelled = "E_CANCELLED"
    static let connectTimeout = "E_CONNECT_TIMEOUT"
    static let provisionFailed = "E_PROV_FAILED"
    static let provisionSessionFailed = "E_PROV_SESSION"
    static let provisionConfigFailed = "E_PROV_CONFIG"
    static let provisionAuthFailed = "E_PROV_AUTH"
    static let provisionNetworkNotFound = "E_PROV_NETWORK_NOT_FOUND"
}

private enum MethodNames {
    static let channel = "esp_provisioning_wifi"
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
    static let security = "security"
    static let username = "username"
}

private enum TimeoutDefaults {
    static let connectTimeoutMs = 15000
}

private final class ProvisionOperationCoordinator {
    private let lock = NSLock()
    private var currentOperationToken = 0
    private var activeDevice: ESPDevice?
    private var activeService: BLEProvisionService?

    func startOperation() -> Int {
        lock.lock()
        currentOperationToken += 1
        let token = currentOperationToken
        disconnectActiveDeviceLocked()
        let superseded = takeActiveServiceLocked()
        lock.unlock()
        // Resolve outside the lock: cancellation resolution re-enters
        // coordinator methods (clearActiveService, isOperationActive).
        superseded?.resolveCancelled()
        return token
    }

    func cancelOperations() -> Bool {
        lock.lock()
        currentOperationToken += 1
        disconnectActiveDeviceLocked()
        let superseded = takeActiveServiceLocked()
        lock.unlock()
        superseded?.resolveCancelled()
        return true
    }

    func trackActiveService(_ service: BLEProvisionService) {
        lock.lock()
        defer { lock.unlock() }
        activeService = service
    }

    func clearActiveService(_ service: BLEProvisionService) {
        lock.lock()
        defer { lock.unlock() }
        if activeService === service {
            activeService = nil
        }
    }

    private func takeActiveServiceLocked() -> BLEProvisionService? {
        let superseded = activeService
        activeService = nil
        return superseded
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
        // Identity match only: a nil device (cancelled create path) must not
        // wipe a newer operation's tracked device.
        if let device = device, activeDevice === device {
            activeDevice = nil
        }
    }

    private func disconnectActiveDeviceLocked() {
        activeDevice?.disconnect()
        activeDevice = nil
    }
}

public class SwiftEspProvisioningWifiPlugin: NSObject, FlutterPlugin {
    private let coordinator = ProvisionOperationCoordinator()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: MethodNames.channel, binaryMessenger: registrar.messenger())
        let instance = SwiftEspProvisioningWifiPlugin()
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
                connectTimeoutMs: TimeoutDefaults.connectTimeoutMs,
                security: 1,
                username: nil
            )
            coordinator.trackActiveService(provisionService)
            provisionService.searchDevices(prefix: prefix)
        } else if call.method == MethodNames.scanWifiNetworks {
            guard let deviceName = requiredStringArg(ArgumentKeys.deviceName, in: arguments, result: result) else { return }
            guard let proofOfPossession = requiredStringArg(ArgumentKeys.proofOfPossession, in: arguments, result: result) else { return }
            guard let securityArgs = securityArgs(in: arguments, result: result) else { return }
            let connectTimeoutMs = optionalConnectTimeoutMs(in: arguments)
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: connectTimeoutMs,
                security: securityArgs.security,
                username: securityArgs.username
            )
            coordinator.trackActiveService(provisionService)
            provisionService.scanWifiNetworks(deviceName: deviceName, proofOfPossession: proofOfPossession)
        } else if call.method == MethodNames.provisionWifi {
            guard let deviceName = requiredStringArg(ArgumentKeys.deviceName, in: arguments, result: result) else { return }
            guard let proofOfPossession = requiredStringArg(ArgumentKeys.proofOfPossession, in: arguments, result: result) else { return }
            guard let ssid = requiredStringArg(ArgumentKeys.ssid, in: arguments, result: result) else { return }
            guard let passphrase = requiredStringArg(ArgumentKeys.passphrase, in: arguments, result: result) else { return }
            guard let securityArgs = securityArgs(in: arguments, result: result) else { return }
            let connectTimeoutMs = optionalConnectTimeoutMs(in: arguments)
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: connectTimeoutMs,
                security: securityArgs.security,
                username: securityArgs.username
            )
            coordinator.trackActiveService(provisionService)
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
            guard let securityArgs = securityArgs(in: arguments, result: result) else { return }
            let payload = arguments[ArgumentKeys.payload] as? String ?? ""
            let connectTimeoutMs = optionalConnectTimeoutMs(in: arguments)
            let provisionService = BLEProvisionService(
                result: result,
                coordinator: coordinator,
                operationToken: coordinator.startOperation(),
                connectTimeoutMs: connectTimeoutMs,
                security: securityArgs.security,
                username: securityArgs.username
            )
            coordinator.trackActiveService(provisionService)
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

    private func securityArgs(
        in arguments: [String: Any],
        result: @escaping FlutterResult
    ) -> (security: Int, username: String?)? {
        let security = (arguments[ArgumentKeys.security] as? NSNumber)?.intValue ?? 1
        let username = arguments[ArgumentKeys.username] as? String
        if security == 2 && (username == nil || username!.isEmpty) {
            result(
                FlutterError(
                    code: ErrorCodes.missingArgument,
                    message: "Missing argument: username",
                    details: "Security 2 requires the SRP6a username configured in the firmware"
                )
            )
            return nil
        }
        return (security, username)
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
    private let security: Int
    private let username: String?
    // Main-thread confined: didResolve is only touched in deliverResolution;
    // deviceSearchStarted is set in searchDevices/connect (called from
    // handle()), cleared via markDeviceSearchFinished (main-thread hop), and
    // read in stopDeviceSearchIfStarted (called from the coordinator's
    // main-thread cancellation).
    private var didResolve = false
    private var deviceSearchStarted = false

    init(
        result: @escaping FlutterResult,
        coordinator: ProvisionOperationCoordinator,
        operationToken: Int,
        connectTimeoutMs: Int,
        security: Int,
        username: String?
    ) {
        self.result = result
        self.coordinator = coordinator
        self.operationToken = operationToken
        self.connectTimeoutMs = connectTimeoutMs
        self.security = security
        self.username = username
    }

    /// Delivers the FlutterResult exactly once, always on the main thread,
    /// mirroring Android's OperationResolver: ESPProvision invokes its
    /// completion handlers on background queues, while platform channel
    /// replies must be delivered on the platform thread.
    private func resolve(_ value: Any?) {
        if Thread.isMainThread {
            deliverResolution(value)
        } else {
            DispatchQueue.main.async {
                self.deliverResolution(value)
            }
        }
    }

    private func deliverResolution(_ value: Any?) {
        if didResolve {
            return
        }
        didResolve = true
        coordinator.clearActiveService(self)
        result(value)
    }

    /// Resolves a superseded/cancelled operation with E_CANCELLED so its Dart
    /// future never dangles. Called by the coordinator on the main thread,
    /// outside the coordinator lock.
    fileprivate func resolveCancelled() {
        stopDeviceSearchIfStarted()
        resolve(FlutterError(code: ErrorCodes.cancelled, message: "Operation cancelled", details: nil))
    }

    private func stopDeviceSearchIfStarted() {
        if !deviceSearchStarted {
            return
        }
        deviceSearchStarted = false
        // Only safe once searchESPDevices/createESPDevice has run:
        // stopESPDevicesSearch force-unwraps the manager's BLE transport.
        ESPProvisionManager.shared.stopESPDevicesSearch()
    }

    private func markDeviceSearchFinished() {
        if Thread.isMainThread {
            deviceSearchStarted = false
        } else {
            DispatchQueue.main.async {
                self.deviceSearchStarted = false
            }
        }
    }

    private func resolveCancelledIfInactive() -> Bool {
        if coordinator.isOperationActive(operationToken) {
            return false
        }
        resolve(FlutterError(code: ErrorCodes.cancelled, message: "Operation cancelled", details: nil))
        return true
    }

    private func fail(error: ESPError, code: String) {
        if resolveCancelledIfInactive() {
            return
        }
        resolve(
            FlutterError(
                code: code,
                message: error.description,
                details: "ESPProvision error code \(error.code)"
            )
        )
    }

    private func disconnect(device: ESPDevice?) {
        device?.disconnect()
        coordinator.clearActiveDevice(device)
    }

    /// Maps provisioning-phase failures to the shared E_PROV_* contract codes.
    private static func provisionErrorCode(for error: ESPError) -> String {
        guard let provisionError = error as? ESPProvisionError else {
            return ErrorCodes.provisionFailed
        }
        switch provisionError {
        case .sessionError:
            return ErrorCodes.provisionSessionFailed
        case .configurationError:
            return ErrorCodes.provisionConfigFailed
        case .wifiStatusAuthenticationError:
            return ErrorCodes.provisionAuthFailed
        case .wifiStatusNetworkNotFound:
            return ErrorCodes.provisionNetworkNotFound
        default:
            return ErrorCodes.provisionFailed
        }
    }

    /// Maps createESPDevice failures: device-not-found gets the shared
    /// E_DEVICE_NOT_FOUND contract code (matching Android's scan-cache miss);
    /// every other creation failure stays E_DEVICE.
    private static func deviceCreateErrorCode(for error: ESPError) -> String {
        if let cssError = error as? ESPDeviceCSSError, case .espDeviceNotFound = cssError {
            return ErrorCodes.deviceNotFound
        }
        return ErrorCodes.iosDeviceCreate
    }
    
    func searchDevices(prefix: String) {
        if resolveCancelledIfInactive() {
            return
        }
        deviceSearchStarted = true
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: prefix, transport:.ble, security:.secure) { deviceList, error in
            self.markDeviceSearchFinished()
            if self.resolveCancelledIfInactive() {
                return
            }
            if let error = error {
                self.fail(error: error, code: ErrorCodes.bleScanFailed)
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
                    self.fail(error: error, code: ErrorCodes.wifiScanFailed)
                    self.disconnect(device: device)
                    return
                }
                self.resolve((wifiList ?? []).map({ (network: ESPWifiNetwork) -> [String: Any] in
                    return [
                        "ssid": network.ssid,
                        "rssi": Int(network.rssi),
                        "security": network.auth.rawValue,
                    ]
                }))
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
                case .failure(let error):
                    NSLog("Device provisioning failed")
                    self.fail(error: error, code: Self.provisionErrorCode(for: error))
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
                // Lossy decode (invalid sequences become U+FFFD) to match
                // Android's String(data, UTF_8) behavior instead of returning
                // an empty string for non-UTF-8 payloads.
                let response = String(decoding: returnData, as: UTF8.self)
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
        let espSecurity: ESPSecurity = security == 2 ? .secure2 : .secure
        // createESPDevice runs its own internal BLE scan for the named device;
        // flag it so a supersession stops that scan too.
        deviceSearchStarted = true
        ESPProvisionManager.shared.createESPDevice(deviceName: deviceName, transport: .ble, security: espSecurity, proofOfPossession: proofOfPossession, username: username) { espDevice, error in
            self.markDeviceSearchFinished()
            if self.resolveCancelledIfInactive() {
                self.disconnect(device: espDevice)
                return
            }
            if let error = error {
                self.fail(error: error, code: Self.deviceCreateErrorCode(for: error))
                return
            }
            guard let espDevice = espDevice else {
                self.resolve(FlutterError(code: ErrorCodes.iosDeviceCreate, message: "Failed to create ESP device", details: nil))
                return
            }
            self.coordinator.trackActiveDevice(espDevice)
            var connectResolved = false
            var timeoutWorkItem: DispatchWorkItem?

            // The timeout fires on the main queue while ESPProvision delivers
            // the connect callback on a background queue; serialize both onto
            // the main thread so the exactly-once guard is race-free.
            func resolveConnect(_ block: @escaping () -> Void) {
                let deliver = {
                    if connectResolved {
                        return
                    }
                    connectResolved = true
                    timeoutWorkItem?.cancel()
                    block()
                }
                if Thread.isMainThread {
                    deliver()
                } else {
                    DispatchQueue.main.async(execute: deliver)
                }
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
                        self.fail(error: error, code: ErrorCodes.connectFailed)
                        self.disconnect(device: espDevice)
                    default:
                        // Parity with Android's connect-phase DISCONNECTED
                        // handling (Boss.kt): same code, message, and details.
                        self.resolve(
                            FlutterError(
                                code: ErrorCodes.connectFailed,
                                message: "BLE device disconnected during connect",
                                details: "ESP device disconnected before the session was established"
                            )
                        )
                        self.disconnect(device: espDevice)
                    }
                }
            }
        }
    }
    
}
