import Flutter
import UIKit
import ESPProvision

public class SwiftFlutterEspBleProvPlugin: NSObject, FlutterPlugin {
    private let PLATFORM_VERSION = "getPlatformVersion"
    private let SCAN_BLE_DEVICES = "scanBleDevices"
    private let SCAN_WIFI_NETWORKS = "scanWifiNetworks"
    private let PROVISION_WIFI = "provisionWifi"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_esp_ble_prov", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterEspBleProvPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let provisionService = BLEProvisionService(result: result)

        if(call.method == PLATFORM_VERSION) {
            result("iOS " + UIDevice.current.systemVersion)
            return
        }

        guard let arguments = call.arguments as? [String: Any] else {
            result(FlutterError(code: "E0", message: "Invalid arguments", details: "Expected arguments map for method \(call.method)"))
            return
        }

        if(call.method == SCAN_BLE_DEVICES) {
            guard let prefix = arguments["prefix"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: prefix", details: nil))
                return
            }
            provisionService.searchDevices(prefix: prefix)
        } else if(call.method == SCAN_WIFI_NETWORKS) {
            guard let deviceName = arguments["deviceName"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: deviceName", details: nil))
                return
            }
            guard let proofOfPossession = arguments["proofOfPossession"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: proofOfPossession", details: nil))
                return
            }
            provisionService.scanWifiNetworks(deviceName: deviceName, proofOfPossession: proofOfPossession)
        } else if (call.method == PROVISION_WIFI) {
            guard let deviceName = arguments["deviceName"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: deviceName", details: nil))
                return
            }
            guard let proofOfPossession = arguments["proofOfPossession"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: proofOfPossession", details: nil))
                return
            }
            guard let ssid = arguments["ssid"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: ssid", details: nil))
                return
            }
            guard let passphrase = arguments["passphrase"] as? String else {
                result(FlutterError(code: "E0", message: "Missing argument: passphrase", details: nil))
                return
            }
            provisionService.provision(
                deviceName: deviceName,
                proofOfPossession: proofOfPossession,
                ssid: ssid,
                passphrase: passphrase
            )
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
}

protocol ProvisionService {
    var result: FlutterResult { get }
    func searchDevices(prefix: String) -> Void
    func scanWifiNetworks(deviceName: String, proofOfPossession: String) -> Void
    func provision(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String) -> Void
}

private class BLEProvisionService: ProvisionService {
    fileprivate var result: FlutterResult
    private var didResolve = false
    
    init(result: @escaping FlutterResult) {
        self.result = result
    }

    private func resolve(_ value: Any?) {
        if(didResolve) {
            return
        }
        didResolve = true
        result(value)
    }

    private func fail(error: ESPError) {
        resolve(FlutterError(code: String(error.code), message: error.description, details: nil))
    }
    
    func searchDevices(prefix: String) {
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: prefix, transport:.ble, security:.secure) { deviceList, error in
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
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession) {
            device in
            device?.scanWifiList { wifiList, error in
                if let error = error {
                    NSLog("Error scanning wifi networks, deviceName: \(deviceName) ")
                    self.fail(error: error)
                    return
                }
                self.resolve((wifiList ?? []).map({(networks: ESPWifiNetwork) -> String in return networks.ssid}))
                device?.disconnect()
            }
        }
    }
    
    func provision(deviceName: String, proofOfPossession: String, ssid: String, passphrase: String) {
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession){
            device in
            device?.provision(ssid: ssid, passPhrase: passphrase) { status in
                switch status {
                case .success:
                    NSLog("Success provisioning device. ssid: \(ssid), deviceName: \(deviceName) ")
                    self.resolve(true)
                case .configApplied:
                    NSLog("Wifi config applied device. ssid: \(ssid), deviceName: \(deviceName) ")
                case .failure:
                    NSLog("Failed to provision device. ssid: \(ssid), deviceName: \(deviceName) ")
                    self.resolve(false)
                }
            }
        }
    }
    
    private func connect(deviceName: String, proofOfPossession: String, completionHandler: @escaping (ESPDevice?) -> Void) {
        ESPProvisionManager.shared.createESPDevice(deviceName: deviceName, transport: .ble, security: .secure, proofOfPossession: proofOfPossession) { espDevice, error in
            
            if let error = error {
                self.fail(error: error)
                return
            }
            guard let espDevice = espDevice else {
                self.resolve(FlutterError(code: "E_DEVICE", message: "Failed to create ESP device", details: nil))
                return
            }
            espDevice.connect { status in
                switch status {
                case .connected:
                    completionHandler(espDevice)
                case let .failedToConnect(error):
                    self.fail(error: error)
                default:
                    self.resolve(FlutterError(code: "DEVICE_DISCONNECTED", message: nil, details: nil))
                }
            }
        }
    }
    
}
