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

/// A typed reason for a failed provisioning action.
enum EspProvisioningFailure {
  none,
  permissionDenied,
  timeout,
  deviceNotFound,
  invalidResponse,
  platform,
  unknown,
}

/// EspProvisioningState is a class that contains a bunch of properties that are used to store the state
/// of the ESP provisioning
class EspProvisioningState extends Equatable {
  EspProvisioningState({
    this.status = EspProvisioningStatus.initial,
    List<String> bluetoothDevices = const <String>[],
    this.bluetoothDevice = "",
    List<String> wifiNetworks = const <String>[],
    this.wifiNetwork = "",
    this.wifiProvisioned = false,
    this.timedOut = false,
    this.errorMsg = "",
    this.failure = EspProvisioningFailure.none,
  })  : _bluetoothDevices =
            List.unmodifiable(List<String>.of(bluetoothDevices)),
        _wifiNetworks = List.unmodifiable(List<String>.of(wifiNetworks));

  final EspProvisioningStatus status;
  final List<String> _bluetoothDevices;
  final String bluetoothDevice;
  final List<String> _wifiNetworks;
  final String wifiNetwork;
  final bool wifiProvisioned;
  final bool timedOut;
  final String errorMsg;
  final EspProvisioningFailure failure;

  List<String> get bluetoothDevices => _bluetoothDevices;
  List<String> get wifiNetworks => _wifiNetworks;

  EspProvisioningState copyWith({
    EspProvisioningStatus? status,
    List<String>? bluetoothDevices,
    String? bluetoothDevice,
    List<String>? wifiNetworks,
    String? wifiNetwork,
    bool? wifiProvisioned,
    bool? timedOut,
    String? errorMsg,
    EspProvisioningFailure? failure,
  }) {
    return EspProvisioningState(
      status: status ?? this.status,
      bluetoothDevices: bluetoothDevices ?? _bluetoothDevices,
      bluetoothDevice: bluetoothDevice ?? this.bluetoothDevice,
      wifiNetworks: wifiNetworks ?? _wifiNetworks,
      wifiNetwork: wifiNetwork ?? this.wifiNetwork,
      wifiProvisioned: wifiProvisioned ?? this.wifiProvisioned,
      timedOut: timedOut ?? this.timedOut,
      errorMsg: errorMsg ?? this.errorMsg,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() {
    return 'EspProvisioningState { status: $status, bluetoothDevices: ${bluetoothDevices.length}, bluetoothDevice: $bluetoothDevice, wifiNetworks: ${wifiNetworks.length}, wifiNetwork: $wifiNetwork, wifiProvisioned: $wifiProvisioned, timedOut: $timedOut, errorMsg: $errorMsg, failure: $failure }';
  }

  @override
  List<Object> get props => [
        status,
        _bluetoothDevices,
        bluetoothDevice,
        _wifiNetworks,
        wifiNetwork,
        wifiProvisioned,
        timedOut,
        errorMsg,
        failure
      ];
}
