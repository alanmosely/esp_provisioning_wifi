import Flutter
import UIKit
import ESPProvision

public class SwiftFlutterEspBleProvPlugin: NSObject, FlutterPlugin {
    private let SCAN_BLE_DEVICES = "scanBleDevices"
    private let SCAN_WIFI_NETWORKS = "scanWifiNetworks"
    private let PROVISION_WIFI = "provisionWifi"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_esp_ble_prov", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterEspBleProvPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let provisionService = BLEProvisionService(result: result);
        let arguments = call.arguments as! [String: Any]
        
        if(call.method == SCAN_BLE_DEVICES) {
            let prefix = arguments["prefix"] as! String
            provisionService.searchDevices(prefix: prefix)
        } else if(call.method == SCAN_WIFI_NETWORKS) {
            let deviceName = arguments["deviceName"] as! String
            let proofOfPossession = arguments["proofOfPossession"] as! String
            provisionService.scanWifiNetworks(deviceName: deviceName, proofOfPossession: proofOfPossession)
        } else if (call.method == PROVISION_WIFI) {
            let deviceName = arguments["deviceName"] as! String
            let proofOfPossession = arguments["proofOfPossession"] as! String
            let ssid = arguments["ssid"] as! String
            let passphrase = arguments["passphrase"] as! String
            provisionService.provision(
                deviceName: deviceName,
                proofOfPossession: proofOfPossession,
                ssid: ssid,
                passphrase: passphrase
            )
        } else {
            result("iOS " + UIDevice.current.systemVersion)
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
    
    init(result: @escaping FlutterResult) {
        self.result = result
    }
    
    func searchDevices(prefix: String) {
        ESPProvisionManager.shared.searchESPDevices(devicePrefix: prefix, transport:.ble, security:.secure) { deviceList, error in
            if(error != nil) {
                ESPErrorHandler.handle(error: error!, result: self.result)
            }
            self.result(deviceList?.map({ (device: ESPDevice) -> String in
                return device.name
            }))
        }
    }
    
    func scanWifiNetworks(deviceName: String, proofOfPossession: String) {
        self.connect(deviceName: deviceName, proofOfPossession: proofOfPossession) {
            device in
            device?.scanWifiList { wifiList, error in
                if(error != nil) {
                    NSLog("Error scanning wifi networks, deviceName: \(deviceName) ")
                    ESPErrorHandler.handle(error: error!, result: self.result)
                }
                self.result(wifiList?.map({(networks: ESPWifiNetwork) -> String in return networks.ssid}))
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
                    self.result(true)
                case .configApplied:
                    NSLog("Wifi config applied device. ssid: \(ssid), deviceName: \(deviceName) ")
                case .failure:
                    NSLog("Failed to provision device. ssid: \(ssid), deviceName: \(deviceName) ")
                    self.result(false)
                }
            }
        }
    }
    
    private func connect(deviceName: String, proofOfPossession: String, completionHandler: @escaping (ESPDevice?) -> Void) {
        ESPProvisionManager.shared.createESPDevice(deviceName: deviceName, transport: .ble, security: .secure, proofOfPossession: proofOfPossession) { espDevice, error in
            
            if(error != nil) {
                ESPErrorHandler.handle(error: error!, result: self.result)
            }
            espDevice?.connect { status in
                switch status {
                case .connected:
                    completionHandler(espDevice!)
                case let .failedToConnect(error):
                    ESPErrorHandler.handle(error: error, result: self.result)
                default:
                    self.result(FlutterError(code: "DEVICE_DISCONNECTED", message: nil, details: nil))
                }
            }
        }
    }
    
}

private class ESPErrorHandler {
    static func handle(error: ESPError, result: FlutterResult) {
        result(FlutterError(code: String(error.code), message: error.description, details: nil))
    }
}
