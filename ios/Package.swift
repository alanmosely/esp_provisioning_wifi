// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BluetoothReadinessCore",
    platforms: [.macOS(.v12)],
    targets: [
        .target(name: "BluetoothReadinessCore", path: "Classes",
            exclude: ["BluetoothReadiness.swift", "SwiftEspProvisioningWifiPlugin.swift",
                      "EspProvisioningWifiPlugin.h", "EspProvisioningWifiPlugin.m"],
            sources: ["BluetoothReadinessSession.swift", "BluetoothChannelRequest.swift"]),
        .testTarget(name: "BluetoothReadinessCoreTests", dependencies: ["BluetoothReadinessCore"], path: "Tests")
    ]
)
