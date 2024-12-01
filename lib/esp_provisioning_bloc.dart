import 'dart:async';
import 'dart:io';

import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'esp_provisioning_constants.dart';
import 'esp_provisioning_event.dart';
import 'esp_provisioning_service.dart';
import 'esp_provisioning_state.dart';

/// The EspProvisioningBloc class is a BLoC that handles EspProvisioningEvents and emits
/// EspProvisioningStates
class EspProvisioningBloc
    extends Bloc<EspProvisioningEvent, EspProvisioningState> {
  EspProvisioningBloc() : super(const EspProvisioningState()) {
    on<EspProvisioningEventStart>(_onStart);
    on<EspProvisioningEventBleSelected>(_onBleSelected);
    on<EspProvisioningEventWifiSelected>(_onWifiSelected);
  }

  /// A late final variable that is assigned to the instance of the EspProvisioningService class.
  late final FlutterEspBleProv espProvisioningService =
      EspProvisioningService();

  /// A boolean variable that is used to check if bluetooth permission has been granted
  bool bluetoothIsGranted = false;

  /// _onStart() is a function that is called when the EspProvisioningEventStart event is emitted
  ///
  /// Args:
  ///   event (EspProvisioningEventStart): This is the event that was emitted by the UI
  ///   emit (Emitter<EspProvisioningState>): This is the function that you use to emit a new state
  Future<void> _onStart(
    EspProvisioningEventStart event,
    Emitter<EspProvisioningState> emit,
  ) async {
    try {
      await requestBluetoothPermission();
      if (bluetoothIsGranted) {
        emit(state.copyWith(status: EspProvisioningStatus.initial));

        final scannedDevices = await espProvisioningService
            .scanBleDevices(event.bluetoothDevicePrefix)
            .timeout(const Duration(seconds: TIMEOUT),
                onTimeout: () => List.empty());

        emit(state.copyWith(
          status: EspProvisioningStatus.bleScanned,
          bluetoothDevices: scannedDevices,
        ));
      } else {
        emit(state.copyWith(
          status: EspProvisioningStatus.error,
          errorMsg: 'Bluetooth permission not granted',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: EspProvisioningStatus.error,
        errorMsg: e.toString(),
      ));
    }
  }

  /// _onBleSelected() is a function that is called when the user selects a bluetooth device from the
  /// list of available bluetooth devices
  ///
  /// Args:
  ///   event (EspProvisioningEventBleSelected): This is the event that was emitted by the UI
  ///   emit (Emitter<EspProvisioningState>): This is the function that you use to emit a new state
  Future<void> _onBleSelected(
    EspProvisioningEventBleSelected event,
    Emitter<EspProvisioningState> emit,
  ) async {
    bool timedOut = false;
    try {
      if (event.bluetoothDevice == '') {
        return emit(
          state.copyWith(
            status: EspProvisioningStatus.initial,
            bluetoothDevices: List.empty(),
            timedOut: timedOut,
          ),
        );
      }
      emit(
        state.copyWith(
          status: EspProvisioningStatus.deviceChosen,
          bluetoothDevice: event.bluetoothDevice,
          timedOut: timedOut,
        ),
      );
      var scannedNetworks = <WiFiNetwork>[];
      scannedNetworks = await espProvisioningService
          .scanWifiNetworks(event.bluetoothDevice, event.proofOfPossession)
          .timeout(const Duration(seconds: TIMEOUT), onTimeout: () {
        timedOut = true;
        return List.empty();
      });
      emit(
        state.copyWith(
          status: EspProvisioningStatus.wifiScanned,
          bluetoothDevice: event.bluetoothDevice,
          wifiNetworks: scannedNetworks,
          timedOut: timedOut,
        ),
      );
    } catch (e) {
      emit(state.copyWith(
          status: EspProvisioningStatus.error, errorMsg: e.toString()));
    }
  }

  /// _onWifiSelected() is called when the user selects a wifi network from the list of available
  /// networks. It then calls the provisionWifi() function in the EspProvisioningService class
  ///
  /// Args:
  ///   event (EspProvisioningEventWifiSelected): This is the event that was emitted by the UI
  ///   emit (Emitter<EspProvisioningState>): This is the function that you use to emit a new state
  Future<void> _onWifiSelected(
    EspProvisioningEventWifiSelected event,
    Emitter<EspProvisioningState> emit,
  ) async {
    bool wifiProvisioned = false;
    bool timedOut = false;
    try {
      emit(
        state.copyWith(
          status: EspProvisioningStatus.networkChosen,
          wifiNetwork: event.wifiNetwork,
          timedOut: timedOut,
        ),
      );
      wifiProvisioned = (await espProvisioningService
          .provisionWifi(event.bluetoothDevice, event.proofOfPossession,
              event.wifiNetwork, event.password)
          .timeout(const Duration(seconds: TIMEOUT), onTimeout: () {
        timedOut = true;
        return false;
      }))!;
      emit(state.copyWith(
        status: EspProvisioningStatus.wifiProvisioned,
        wifiProvisioned: wifiProvisioned,
        timedOut: timedOut,
      ));
    } catch (e) {
      emit(state.copyWith(
          status: EspProvisioningStatus.error, errorMsg: e.toString()));
    }
  }

  /// requestBluetoothPermission() is a function that requests bluetooth permission from the user
  /// using the permission_handler package
  Future<void> requestBluetoothPermission() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> status = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect
      ].request();
      bluetoothIsGranted =
          status[Permission.bluetoothScan] == PermissionStatus.granted &&
              status[Permission.bluetoothConnect] == PermissionStatus.granted;
    } else if (Platform.isIOS) {
      Map<Permission, PermissionStatus> status =
          await [Permission.bluetooth].request();
      bluetoothIsGranted =
          status[Permission.bluetooth] == PermissionStatus.granted;
    }
  }
}
