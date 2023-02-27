import 'package:equatable/equatable.dart';

/// A list of all the possible states that the ESP provisioning can be in
enum EspProvisioningStatus {
  initial,
  bleScanned,
  deviceChosen,
  wifiScanned,
  networkChosen,
  wifiProvisioned,
  error,
}

/// EspProvisioningState is a class that contains a bunch of properties that are used to store the state
/// of the ESP provisioning
class EspProvisioningState extends Equatable {
  const EspProvisioningState({
    this.status = EspProvisioningStatus.initial,
    this.bluetoothDevices = const <String>[],
    this.bluetoothDevice = "",
    this.wifiNetworks = const <String>[],
    this.wifiNetwork = "",
    this.wifiProvisioned = false,
    this.timedOut = false,
    this.errorMsg = "",
  });

  final EspProvisioningStatus status;
  final List<String> bluetoothDevices;
  final String bluetoothDevice;
  final List<String> wifiNetworks;
  final String wifiNetwork;
  final bool wifiProvisioned;
  final bool timedOut;
  final String errorMsg;

  EspProvisioningState copyWith({
    EspProvisioningStatus? status,
    List<String>? bluetoothDevices,
    String? bluetoothDevice,
    List<String>? wifiNetworks,
    String? wifiNetwork,
    bool? wifiProvisioned,
    bool? timedOut,
    String? errorMsg,
  }) {
    return EspProvisioningState(
      status: status ?? this.status,
      bluetoothDevices: bluetoothDevices ?? this.bluetoothDevices,
      bluetoothDevice: bluetoothDevice ?? this.bluetoothDevice,
      wifiNetworks: wifiNetworks ?? this.wifiNetworks,
      wifiNetwork: wifiNetwork ?? this.wifiNetwork,
      wifiProvisioned: wifiProvisioned ?? this.wifiProvisioned,
      timedOut: timedOut ?? this.timedOut,
      errorMsg: errorMsg ?? this.errorMsg,
    );
  }

  @override
  String toString() {
    return '''EspProvisioningState { status: $status, bluetoothDevices: ${bluetoothDevices.length}, bluetoothDevice: $bluetoothDevice, wifiNetworks: ${wifiNetworks.length}, wifiNetwork: $wifiNetwork, wifiProvisioned: $wifiProvisioned, timedOut: $timedOut, errorMsg: $errorMsg''';
  }

  @override
  List<Object> get props => [
        status,
        bluetoothDevices,
        bluetoothDevice,
        wifiNetworks,
        wifiNetwork,
        wifiProvisioned,
        timedOut,
        errorMsg
      ];
}
