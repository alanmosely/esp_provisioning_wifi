import 'package:equatable/equatable.dart';

abstract class EspProvisioningEvent extends Equatable {
  const EspProvisioningEvent();

  @override
  List<Object> get props => [];
}

class EspProvisioningEventStart extends EspProvisioningEvent {
  final String bluetoothDevicePrefix;

  const EspProvisioningEventStart(this.bluetoothDevicePrefix);

  @override
  List<Object> get props => [bluetoothDevicePrefix];
}

class EspProvisioningEventBleSelected extends EspProvisioningEvent {
  final String bluetoothDevice;
  final String proofOfPossession;

  const EspProvisioningEventBleSelected(
      this.bluetoothDevice, this.proofOfPossession);

  @override
  List<Object> get props => [bluetoothDevice, proofOfPossession];
}

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
