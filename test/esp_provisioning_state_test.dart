// ignore_for_file: inference_failure_on_function_invocation

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspProvisioningBloc', () {
    late EspProvisioningBloc espProvisioningBloc;

    WidgetsFlutterBinding.ensureInitialized();

    setUp(() {
      espProvisioningBloc = EspProvisioningBloc();
    });

    test('check initial state', () {
      expect(
          espProvisioningBloc.state,
          EspProvisioningState(
            status: EspProvisioningStatus.initial,
            bluetoothDevices: const <String>[],
            bluetoothDevice: "",
            wifiNetworks: const <String>[],
            wifiNetwork: "",
            wifiProvisioned: false,
            errorMsg: "",
          ));
    });

    test('defensively copies list inputs', () {
      final bluetoothDevices = <String>['device-1'];
      final wifiNetworks = <String>['ssid-1'];
      final state = EspProvisioningState(
        bluetoothDevices: bluetoothDevices,
        wifiNetworks: wifiNetworks,
      );

      bluetoothDevices.add('device-2');
      wifiNetworks.add('ssid-2');

      expect(state.bluetoothDevices, <String>['device-1']);
      expect(state.wifiNetworks, <String>['ssid-1']);
      expect(
          () => state.bluetoothDevices.add('device-3'), throwsUnsupportedError);
      expect(() => state.wifiNetworks.add('ssid-3'), throwsUnsupportedError);
    });

    blocTest(
      'emits EspProvisioningStatus.deviceChosen and error when EspProvisioningEventBleSelected is added',
      build: () => espProvisioningBloc,
      act: (bloc) =>
          bloc.add(const EspProvisioningEventBleSelected("device", "prefix")),
      expect: () => [
        EspProvisioningState(
            status: EspProvisioningStatus.deviceChosen,
            bluetoothDevice: "device")
      ],
    );
    blocTest(
      'emits EspProvisioningStatus.networkChosen and error when EspProvisioningEventWifiSelected is added',
      build: () => espProvisioningBloc,
      act: (bloc) => bloc.add(const EspProvisioningEventWifiSelected(
          "device", "pop", "ssid", "password")),
      expect: () => [
        EspProvisioningState(
            status: EspProvisioningStatus.networkChosen, wifiNetwork: "ssid")
      ],
    );
  });
}
