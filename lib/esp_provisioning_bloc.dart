import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'esp_provisioning_constants.dart';
import 'esp_provisioning_error_codes.dart';
import 'esp_provisioning_event.dart';
import 'esp_provisioning_service.dart';
import 'esp_provisioning_state.dart';
import 'src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

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
        await _cancelOperations();
        _emitStateWithClearedError(
          emit,
          status: EspProvisioningStatus.initial,
        );

        final timedScan = await _runWithTimeout<List<String>>(
          () => espProvisioningService.scanBleDevices(
            event.bluetoothDevicePrefix,
          ),
          const <String>[],
        );

        _emitStateWithTimeoutResult(
          emit,
          status: EspProvisioningStatus.bleScanned,
          bluetoothDevices: timedScan.value,
          timedOut: timedScan.timedOut,
          timeoutOperation: 'scanBleDevices',
          timeoutMessage: 'BLE scan timed out',
        );
      } else {
        emit(state.copyWith(
          status: EspProvisioningStatus.error,
          errorCode: EspProvisioningErrorCodes.permission,
          errorDetails: null,
          errorMsg: 'Bluetooth permission not granted',
          failure: EspProvisioningFailure.permissionDenied,
        ));
      }
    } on Object catch (e) {
      _emitUnexpectedError(emit, e);
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
    try {
      await _cancelOperations();
      if (event.bluetoothDevice == '') {
        _emitStateWithClearedError(
          emit,
          status: EspProvisioningStatus.initial,
          bluetoothDevices: const <String>[],
        );
        return;
      }
      _emitStateWithClearedError(
        emit,
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: event.bluetoothDevice,
      );
      final timedScan = await _runWithTimeout<List<String>>(
        () => espProvisioningService.scanWifiNetworks(
          event.bluetoothDevice,
          event.proofOfPossession,
          connectTimeout: _requestTimeout,
        ),
        const <String>[],
      );
      _emitStateWithTimeoutResult(
        emit,
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: event.bluetoothDevice,
        wifiNetworks: timedScan.value,
        timedOut: timedScan.timedOut,
        timeoutOperation: 'scanWifiNetworks',
        timeoutMessage: 'WiFi scan timed out',
      );
    } on Object catch (e) {
      _emitUnexpectedError(emit, e);
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
    try {
      await _cancelOperations();
      _emitStateWithClearedError(
        emit,
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: event.wifiNetwork,
      );
      final timedProvision = await _runWithTimeout<bool>(
        () => espProvisioningService.provisionWifi(
          event.bluetoothDevice,
          event.proofOfPossession,
          event.wifiNetwork,
          event.password,
          connectTimeout: _requestTimeout,
        ),
        false,
      );
      _emitStateWithTimeoutResult(
        emit,
        status: EspProvisioningStatus.wifiProvisioned,
        wifiProvisioned: timedProvision.value,
        timedOut: timedProvision.timedOut,
        timeoutOperation: 'provisionWifi',
        timeoutMessage: 'WiFi provisioning timed out',
      );
    } on Object catch (e) {
      _emitUnexpectedError(emit, e);
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
        case EspProvisioningErrorCodes.permission:
          return EspProvisioningFailure.permissionDenied;
        case EspProvisioningErrorCodes.connectTimeout:
        case EspProvisioningErrorCodes.timeout:
          return EspProvisioningFailure.timeout;
        case EspProvisioningErrorCodes.cancelled:
          return EspProvisioningFailure.cancelled;
        case EspProvisioningErrorCodes.deviceNotFound:
          return EspProvisioningFailure.deviceNotFound;
        case EspProvisioningErrorCodes.invalidResponse:
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

  String _mapErrorCode(Object error) {
    if (error is TimeoutException) {
      return EspProvisioningErrorCodes.timeout;
    }
    if (error is PlatformException) {
      return error.code;
    }
    return EspProvisioningErrorCodes.unknown;
  }

  String? _mapErrorDetails(Object error) {
    if (error is PlatformException && error.details != null) {
      return error.details.toString();
    }
    if (error is TimeoutException) {
      return error.message;
    }
    return null;
  }

  Future<void> _cancelOperations() async {
    await espProvisioningService.cancelOperations();
  }

  void _emitStateWithClearedError(
    Emitter<EspProvisioningState> emit, {
    required EspProvisioningStatus status,
    List<String>? bluetoothDevices,
    String? bluetoothDevice,
    List<String>? wifiNetworks,
    String? wifiNetwork,
    bool? wifiProvisioned,
  }) {
    emit(
      state.copyWith(
        status: status,
        bluetoothDevices: bluetoothDevices,
        bluetoothDevice: bluetoothDevice,
        wifiNetworks: wifiNetworks,
        wifiNetwork: wifiNetwork,
        wifiProvisioned: wifiProvisioned,
        errorCode: null,
        errorDetails: null,
        errorMsg: '',
        failure: EspProvisioningFailure.none,
      ),
    );
  }

  void _emitStateWithTimeoutResult(
    Emitter<EspProvisioningState> emit, {
    required EspProvisioningStatus status,
    List<String>? bluetoothDevices,
    String? bluetoothDevice,
    List<String>? wifiNetworks,
    String? wifiNetwork,
    bool? wifiProvisioned,
    required bool timedOut,
    required String timeoutOperation,
    required String timeoutMessage,
  }) {
    emit(
      state.copyWith(
        status: status,
        bluetoothDevices: bluetoothDevices,
        bluetoothDevice: bluetoothDevice,
        wifiNetworks: wifiNetworks,
        wifiNetwork: wifiNetwork,
        wifiProvisioned: wifiProvisioned,
        errorCode: timedOut ? EspProvisioningErrorCodes.timeout : null,
        errorDetails: timedOut
            ? '$timeoutOperation timeout after $_requestTimeout'
            : null,
        errorMsg: timedOut ? timeoutMessage : '',
        failure: timedOut
            ? EspProvisioningFailure.timeout
            : EspProvisioningFailure.none,
      ),
    );
  }

  void _emitUnexpectedError(
    Emitter<EspProvisioningState> emit,
    Object error,
  ) {
    emit(
      state.copyWith(
        status: EspProvisioningStatus.error,
        errorCode: _mapErrorCode(error),
        errorDetails: _mapErrorDetails(error),
        errorMsg: _mapErrorMessage(error),
        failure: _mapFailure(error),
      ),
    );
  }

  Future<_TimedResult<T>> _runWithTimeout<T>(
    Future<T> Function() action,
    T timeoutValue,
  ) async {
    var timedOut = false;
    final value = await action().timeout(
      _requestTimeout,
      onTimeout: () {
        timedOut = true;
        return timeoutValue;
      },
    );
    return _TimedResult<T>(value: value, timedOut: timedOut);
  }
}

class _TimedResult<T> {
  const _TimedResult({required this.value, required this.timedOut});

  final T value;
  final bool timedOut;
}
