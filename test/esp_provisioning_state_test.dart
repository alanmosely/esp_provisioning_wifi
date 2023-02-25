// ignore_for_file: inference_failure_on_function_invocation

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspProvisioningBloc', () {
    late EspProvisioningBloc espProvisioningBloc;

    setUp(() {
      espProvisioningBloc = EspProvisioningBloc();
    });

    test('check initial state', () {
      expect(
          espProvisioningBloc.state,
          const EspProvisioningState(
            status: EspProvisioningStatus.initial,
            bluetoothDevices: <String>[],
            bluetoothDevice: "",
            wifiNetworks: <String>[],
            wifiNetwork: "",
            wifiProvisioned: false,
          ));
    });

    blocTest(
      'emits EspProvisioningStatus.deviceChosen and error when EspProvisioningEventBleSelected is added',
      build: () => espProvisioningBloc,
      act: (bloc) =>
          bloc.add(const EspProvisioningEventBleSelected("device", "prefix")),
      expect: () => [
        const EspProvisioningState(status: EspProvisioningStatus.deviceChosen),
        const EspProvisioningState(status: EspProvisioningStatus.error),
      ],
    );
    blocTest(
      'emits EspProvisioningStatus.networkChosen and error when EspProvisioningEventWifiSelected is added',
      build: () => espProvisioningBloc,
      act: (bloc) => bloc.add(const EspProvisioningEventWifiSelected(
          "device", "pop", "ssid", "password")),
      expect: () => [
        const EspProvisioningState(status: EspProvisioningStatus.networkChosen),
        const EspProvisioningState(status: EspProvisioningStatus.error),
      ],
    );
  });
}
