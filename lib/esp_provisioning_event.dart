import 'package:equatable/equatable.dart';

import 'esp_security_scheme.dart';

/// An abstract class that represents events across the provisioning process
abstract class EspProvisioningEvent extends Equatable {
  const EspProvisioningEvent();

  @override
  List<Object?> get props => [];
}

/// A class that represents the start of the provisioning process
class EspProvisioningEventStart extends EspProvisioningEvent {
  final String bluetoothDevicePrefix;

  const EspProvisioningEventStart(this.bluetoothDevicePrefix);

  @override
  List<Object?> get props => [bluetoothDevicePrefix];
}

/// A class that represents the selection of a ble device within the provisioning process
class EspProvisioningEventBleSelected extends EspProvisioningEvent {
  final String bluetoothDevice;
  final String proofOfPossession;
  final EspSecurityScheme security;
  final String? username;

  const EspProvisioningEventBleSelected(
    this.bluetoothDevice,
    this.proofOfPossession, {
    this.security = EspSecurityScheme.security1,
    this.username,
  });

  @override
  List<Object?> get props =>
      [bluetoothDevice, proofOfPossession, security, username];
}

/// A class that represents the selection of a wifi network within the provisioning process
class EspProvisioningEventWifiSelected extends EspProvisioningEvent {
  final String bluetoothDevice;
  final String proofOfPossession;
  final String wifiNetwork;
  final String password;
  final EspSecurityScheme security;
  final String? username;

  const EspProvisioningEventWifiSelected(
    this.bluetoothDevice,
    this.proofOfPossession,
    this.wifiNetwork,
    this.password, {
    this.security = EspSecurityScheme.security1,
    this.username,
  });

  @override
  List<Object?> get props => [
        bluetoothDevice,
        proofOfPossession,
        wifiNetwork,
        password,
        security,
        username
      ];
}
