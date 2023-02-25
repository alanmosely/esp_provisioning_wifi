import 'package:equatable/equatable.dart';

/// An abstract class that represents events across the provisioning process
abstract class EspProvisioningEvent extends Equatable {
  const EspProvisioningEvent();

  @override
  List<Object> get props => [];
}

/// A class that represents the start of the provisioning process
class EspProvisioningEventStart extends EspProvisioningEvent {
  final String bluetoothDevicePrefix;

  const EspProvisioningEventStart(this.bluetoothDevicePrefix);

  @override
  List<Object> get props => [bluetoothDevicePrefix];
}

/// A class that represents the selection of a ble device within the provisioning process
class EspProvisioningEventBleSelected extends EspProvisioningEvent {
  final String bluetoothDevice;
  final String proofOfPossession;

  const EspProvisioningEventBleSelected(
      this.bluetoothDevice, this.proofOfPossession);

  @override
  List<Object> get props => [bluetoothDevice, proofOfPossession];
}

/// A class that represents the selection of a wifi network within the provisioning process
class EspProvisioningEventWifiSelected extends EspProvisioningEvent {
  final String bluetoothDevice;
  final String proofOfPossession;
  final String wifiNetwork;
  final String password;

  const EspProvisioningEventWifiSelected(this.bluetoothDevice,
      this.proofOfPossession, this.wifiNetwork, this.password);

  @override
  List<Object> get props =>
      [bluetoothDevice, proofOfPossession, wifiNetwork, password];
}
