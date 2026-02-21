import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'esp_provisioning_constants.dart';
import 'esp_provisioning_event.dart';
import 'esp_provisioning_service.dart';
import 'esp_provisioning_state.dart';

/// The EspProvisioningBloc class is a BLoC that handles EspProvisioningEvents and emits
/// EspProvisioningStates
class EspProvisioningBloc
    extends Bloc<EspProvisioningEvent, EspProvisioningState> {
  EspProvisioningBloc({
    FlutterEspBleProv? provisioningService,
    Future<bool> Function()? bluetoothPermissionRequest,
    Duration? requestTimeout,
  })  : espProvisioningService =
            provisioningService ?? EspProvisioningService(),
        _bluetoothPermissionRequest = bluetoothPermissionRequest,
        _requestTimeout = requestTimeout ?? const Duration(seconds: TIMEOUT),
        super(EspProvisioningState()) {
    on<EspProvisioningEventStart>(
      _onStart,
      transformer: droppable(),
    );
    on<EspProvisioningEventBleSelected>(
      _onBleSelected,
      transformer: restartable(),
    );
    on<EspProvisioningEventWifiSelected>(
      _onWifiSelected,
      transformer: restartable(),
    );
  }

  /// A provisioner service used to communicate with the platform plugin.
  final FlutterEspBleProv espProvisioningService;

  /// Override for tests where permission_handler is unavailable.
  final Future<bool> Function()? _bluetoothPermissionRequest;

  /// Timeout to apply to scan/provision calls.
  final Duration _requestTimeout;

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
      final bool bluetoothIsGranted;
      if (_bluetoothPermissionRequest != null) {
        bluetoothIsGranted = await _bluetoothPermissionRequest!();
      } else {
        bluetoothIsGranted = await requestBluetoothPermission();
      }
      if (bluetoothIsGranted) {
        bool timedOut = false;
        emit(state.copyWith(
          status: EspProvisioningStatus.initial,
          timedOut: false,
          errorMsg: '',
          failure: EspProvisioningFailure.none,
        ));

        final scannedDevices = await espProvisioningService
            .scanBleDevices(event.bluetoothDevicePrefix)
            .timeout(_requestTimeout, onTimeout: () {
          timedOut = true;
          return List.empty();
        });

        emit(state.copyWith(
          status: EspProvisioningStatus.bleScanned,
          bluetoothDevices: scannedDevices,
          timedOut: timedOut,
          errorMsg: timedOut ? 'BLE scan timed out' : '',
          failure: timedOut
              ? EspProvisioningFailure.timeout
              : EspProvisioningFailure.none,
        ));
      } else {
        emit(state.copyWith(
          status: EspProvisioningStatus.error,
          errorMsg: 'Bluetooth permission not granted',
          failure: EspProvisioningFailure.permissionDenied,
        ));
      }
    } on Object catch (e) {
      final failure = _mapFailure(e);
      emit(state.copyWith(
        status: EspProvisioningStatus.error,
        errorMsg: _mapErrorMessage(e),
        failure: failure,
        timedOut: failure == EspProvisioningFailure.timeout,
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
            errorMsg: '',
            failure: EspProvisioningFailure.none,
          ),
        );
      }
      emit(
        state.copyWith(
          status: EspProvisioningStatus.deviceChosen,
          bluetoothDevice: event.bluetoothDevice,
          timedOut: timedOut,
          errorMsg: '',
          failure: EspProvisioningFailure.none,
        ),
      );
      var scannedNetworks = <String>[];
      scannedNetworks = await espProvisioningService
          .scanWifiNetworks(event.bluetoothDevice, event.proofOfPossession)
          .timeout(_requestTimeout, onTimeout: () {
        timedOut = true;
        return List.empty();
      });
      emit(
        state.copyWith(
          status: EspProvisioningStatus.wifiScanned,
          bluetoothDevice: event.bluetoothDevice,
          wifiNetworks: scannedNetworks,
          timedOut: timedOut,
          errorMsg: timedOut ? 'WiFi scan timed out' : '',
          failure: timedOut
              ? EspProvisioningFailure.timeout
              : EspProvisioningFailure.none,
        ),
      );
    } on Object catch (e) {
      final failure = _mapFailure(e);
      emit(state.copyWith(
        status: EspProvisioningStatus.error,
        errorMsg: _mapErrorMessage(e),
        failure: failure,
        timedOut: failure == EspProvisioningFailure.timeout,
      ));
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
    bool timedOut = false;
    try {
      emit(
        state.copyWith(
          status: EspProvisioningStatus.networkChosen,
          wifiNetwork: event.wifiNetwork,
          timedOut: timedOut,
          errorMsg: '',
          failure: EspProvisioningFailure.none,
        ),
      );
      final wifiProvisioned = await espProvisioningService
          .provisionWifi(event.bluetoothDevice, event.proofOfPossession,
              event.wifiNetwork, event.password)
          .timeout(
        _requestTimeout,
        onTimeout: () {
          timedOut = true;
          return false;
        },
      );
      emit(state.copyWith(
        status: EspProvisioningStatus.wifiProvisioned,
        wifiProvisioned: wifiProvisioned,
        timedOut: timedOut,
        errorMsg: timedOut ? 'WiFi provisioning timed out' : '',
        failure: timedOut
            ? EspProvisioningFailure.timeout
            : EspProvisioningFailure.none,
      ));
    } on Object catch (e) {
      final failure = _mapFailure(e);
      emit(state.copyWith(
        status: EspProvisioningStatus.error,
        errorMsg: _mapErrorMessage(e),
        failure: failure,
        timedOut: failure == EspProvisioningFailure.timeout,
      ));
    }
  }

  /// requestBluetoothPermission() is a function that requests bluetooth permission from the user
  /// using the permission_handler package
  Future<bool> requestBluetoothPermission() async {
    bool bluetoothIsGranted = false;
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
    return bluetoothIsGranted;
  }

  EspProvisioningFailure _mapFailure(Object error) {
    if (error is TimeoutException) {
      return EspProvisioningFailure.timeout;
    }
    if (error is PlatformException) {
      switch (error.code) {
        case 'E_DEVICE_NOT_FOUND':
          return EspProvisioningFailure.deviceNotFound;
        case 'E_INVALID_RESPONSE':
          return EspProvisioningFailure.invalidResponse;
        default:
          return EspProvisioningFailure.platform;
      }
    }
    return EspProvisioningFailure.unknown;
  }

  String _mapErrorMessage(Object error) {
    if (error is PlatformException) {
      return error.message ?? 'Platform error: ${error.code}';
    }
    return error.toString();
  }
}
