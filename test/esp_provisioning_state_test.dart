// ignore_for_file: inference_failure_on_function_invocation

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
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
          const EspProvisioningState(
            status: EspProvisioningStatus.initial,
            bluetoothDevices: <String>[],
            bluetoothDevice: "",
            wifiNetworks: <WiFiNetwork>[],
            wifiNetwork: "",
            wifiProvisioned: false,
            errorMsg: "",
          ));
    });

    blocTest(
      'emits EspProvisioningStatus.deviceChosen and error when EspProvisioningEventBleSelected is added',
      build: () => espProvisioningBloc,
      act: (bloc) =>
          bloc.add(const EspProvisioningEventBleSelected("device", "prefix")),
      expect: () => [
        const EspProvisioningState(
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
        const EspProvisioningState(
            status: EspProvisioningStatus.networkChosen, wifiNetwork: "ssid")
      ],
    );
  });
}
