import Foundation
import CoreFoundation

/// Parse the complete request before dispatch can cancel any active operation.
enum BluetoothChannelRequest: Equatable {
    case ensureReady(id: Int, timeoutMs: Int)
    case cancelReadiness(id: Int?)
    case platformVersion, cancelOperations, provisioning, unsupported, invalid

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              ["c", "s", "i", "l", "q"].contains(String(cString: number.objCType)) else { return nil }
        return Int(exactly: number.int64Value)
    }

    static func parse(_ method: String, _ arguments: Any?) -> BluetoothChannelRequest {
        if method == "getPlatformVersion" { return .platformVersion }
        if method == "cancelOperations" { return .cancelOperations }
        let required: [String]
        switch method {
        case "scanBleDevices": required = ["prefix"]
        case "scanWifiNetworks": required = ["deviceName", "proofOfPossession"]
        case "provisionWifi": required = ["deviceName", "proofOfPossession", "ssid", "passphrase"]
        case "fetchCustomData": required = ["deviceName", "proofOfPossession", "endpoint"]
        case "ensureBluetoothReady", "cancelBluetoothReadiness": required = []
        default: return .unsupported
        }
        guard let args = arguments as? [String: Any] else { return .invalid }
        if method == "cancelBluetoothReadiness" {
            guard let value = args["requestId"] else { return .invalid }
            if value is NSNull { return .cancelReadiness(id: nil) }
            guard let id = integer(value), id > 0 else { return .invalid }
            return .cancelReadiness(id: id)
        }
        if method == "ensureBluetoothReady" {
            guard let id = integer(args["requestId"]), id > 0,
                  let timeout = integer(args["timeoutMs"]), (1...120000).contains(timeout),
                  let enable = args["requestEnable"] as? NSNumber,
                  CFGetTypeID(enable) == CFBooleanGetTypeID() else { return .invalid }
            return .ensureReady(id: id, timeoutMs: timeout)
        }
        guard required.allSatisfy({ args[$0] is String }) else { return .invalid }
        for key in ["payload", "username"] {
            if let value = args[key], !(value is NSNull), !(value is String) { return .invalid }
        }
        for key in ["security", "connectTimeoutMs"] {
            if let value = args[key], !(value is NSNull) {
                guard let number = integer(value), Int32(exactly: number) != nil else { return .invalid }
            }
        }
        if integer(args["security"]) == 2 && (args["username"] as? String ?? "").isEmpty { return .invalid }
        return .provisioning
    }
}
