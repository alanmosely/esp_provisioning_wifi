import 'dart:async';

import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'esp_provisioning_constants.dart';
import 'esp_provisioning_event.dart';
import 'esp_provisioning_service.dart';
import 'esp_provisioning_state.dart';

class EspProvisioningBloc
    extends Bloc<EspProvisioningEvent, EspProvisioningState> {
  EspProvisioningBloc() : super(const EspProvisioningState()) {
    on<EspProvisioningEventStart>(_onStart);
    on<EspProvisioningEventBleSelected>(_onBleSelected);
    on<EspProvisioningEventWifiSelected>(_onWifiSelected);
  }

  late final FlutterEspBleProv? espProvisioningService =
      EspProvisioningService.getInstance();

  Future<void> _onStart(
    EspProvisioningEventStart event,
    Emitter<EspProvisioningState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: EspProvisioningStatus.initial,
          bluetoothDevices: List.empty(),
        ),
      );
      final scannedDevices = await espProvisioningService!
          .scanBleDevices(event.bluetoothDevicePrefix)
          .timeout(const Duration(seconds: TIMEOUT),
              onTimeout: () => throw Exception("Timed out"));
      emit(
        state.copyWith(
            status: EspProvisioningStatus.bleScanned,
            bluetoothDevices: scannedDevices),
      );
    } catch (e) {
      emit(state.copyWith(
          status: EspProvisioningStatus.error, errorMsg: e.toString()));
    }
  }

  Future<void> _onBleSelected(
    EspProvisioningEventBleSelected event,
    Emitter<EspProvisioningState> emit,
  ) async {
    try {
      if (event.bluetoothDevice == '') {
        return emit(
          state.copyWith(
            status: EspProvisioningStatus.initial,
            bluetoothDevices: List.empty(),
          ),
        );
      }
      emit(
        state.copyWith(
          status: EspProvisioningStatus.deviceChosen,
          bluetoothDevice: event.bluetoothDevice,
        ),
      );
      var scannedNetworks = <String>[];
      scannedNetworks = await espProvisioningService!
          .scanWifiNetworks(event.bluetoothDevice, event.proofOfPossession)
          .timeout(const Duration(seconds: TIMEOUT),
              onTimeout: () => throw Exception("Timed out"));
      emit(
        state.copyWith(
            status: EspProvisioningStatus.wifiScanned,
            bluetoothDevice: event.bluetoothDevice,
            wifiNetworks: scannedNetworks),
      );
    } catch (e) {
      emit(state.copyWith(
          status: EspProvisioningStatus.error, errorMsg: e.toString()));
    }
  }

  Future<void> _onWifiSelected(
    EspProvisioningEventWifiSelected event,
    Emitter<EspProvisioningState> emit,
  ) async {
    try {
      emit(
        state.copyWith(
          status: EspProvisioningStatus.networkChosen,
          wifiNetwork: event.wifiNetwork,
        ),
      );
      final bool? wifiProvisioned = await espProvisioningService!
          .provisionWifi(event.bluetoothDevice, event.proofOfPossession,
              event.wifiNetwork, event.password)
          .timeout(const Duration(seconds: TIMEOUT), onTimeout: () => false);
      emit(state.copyWith(
        status: EspProvisioningStatus.wifiProvisioned,
        wifiProvisioned: wifiProvisioned,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: EspProvisioningStatus.error, errorMsg: e.toString()));
    }
  }
}
