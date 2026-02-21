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
  cancelled,
  deviceNotFound,
  invalidResponse,
  platform,
  unknown,
}

/// EspProvisioningState is a class that contains a bunch of properties that are used to store the state
/// of the ESP provisioning
class EspProvisioningState extends Equatable {
  static const Object _unset = Object();

  EspProvisioningState({
    this.status = EspProvisioningStatus.initial,
    List<String> bluetoothDevices = const <String>[],
    this.bluetoothDevice = "",
    List<String> wifiNetworks = const <String>[],
    this.wifiNetwork = "",
    this.wifiProvisioned = false,
    this.errorCode,
    this.errorDetails,
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
  final String? errorCode;
  final String? errorDetails;
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
    Object? errorCode = _unset,
    Object? errorDetails = _unset,
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
      errorCode:
          identical(errorCode, _unset) ? this.errorCode : errorCode as String?,
      errorDetails: identical(errorDetails, _unset)
          ? this.errorDetails
          : errorDetails as String?,
      errorMsg: errorMsg ?? this.errorMsg,
      failure: failure ?? this.failure,
    );
  }

  @override
  String toString() {
    return 'EspProvisioningState { status: $status, bluetoothDevices: ${bluetoothDevices.length}, bluetoothDevice: $bluetoothDevice, wifiNetworks: ${wifiNetworks.length}, wifiNetwork: $wifiNetwork, wifiProvisioned: $wifiProvisioned, errorCode: $errorCode, errorDetails: $errorDetails, errorMsg: $errorMsg, failure: $failure }';
  }

  @override
  List<Object?> get props => [
        status,
        _bluetoothDevices,
        bluetoothDevice,
        _wifiNetworks,
        wifiNetwork,
        wifiProvisioned,
        errorCode,
        errorDetails,
        errorMsg,
        failure
      ];
}
