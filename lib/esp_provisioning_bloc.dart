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
import 'esp_wifi_network.dart';
import 'src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

/// The EspProvisioningBloc class is a BLoC that handles EspProvisioningEvents and emits
/// EspProvisioningStates
class EspProvisioningBloc
    extends Bloc<EspProvisioningEvent, EspProvisioningState> {
  EspProvisioningBloc({
    FlutterEspBleProv? provisioningService,
    Future<bool> Function()? bluetoothPermissionRequest,
    Duration? connectTimeout,
    Duration? requestTimeout,
  })  : espProvisioningService =
            provisioningService ?? EspProvisioningService(),
        _bluetoothPermissionRequest = bluetoothPermissionRequest,
        _connectTimeout = connectTimeout ?? kEspDefaultConnectTimeout,
        _requestTimeout = requestTimeout ??
            (connectTimeout ?? kEspDefaultConnectTimeout) +
                kEspDefaultOperationBudget,
        super(EspProvisioningState()) {
    if (_requestTimeout <= _connectTimeout) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'must be strictly greater than connectTimeout ($_connectTimeout), '
            'otherwise typed native error codes (e.g. E_CONNECT_TIMEOUT) can '
            'never surface',
      );
    }
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

  /// Timeout for the native BLE connect phase of an operation.
  final Duration _connectTimeout;

  /// Overall timeout for a scan/provision call (connect + operation phases).
  final Duration _requestTimeout;

  /// Monotonic counter identifying the latest operation; a stale handler's
  /// timeout must not cancel a newer operation's native work.
  int _operationEpoch = 0;

  /// _onStart() is a function that is called when the EspProvisioningEventStart event is emitted
  ///
  /// Args:
  ///   event (EspProvisioningEventStart): This is the event that was emitted by the UI
  ///   emit (`Emitter<EspProvisioningState>`): This is the function that you use to emit a new state
  Future<void> _onStart(
    EspProvisioningEventStart event,
    Emitter<EspProvisioningState> emit,
  ) async {
    // Handlers of different event types run concurrently (the transformers
    // only serialize within one type), so a handler must not touch state once
    // a later operation has superseded it: its caught E_CANCELLED (triggered
    // by the successor's native cancel) or late result would clobber the new
    // flow's state. The epoch is bumped-and-captured synchronously BEFORE the
    // fallible native-cancel await: a post-await re-read could adopt a
    // successor's epoch, and a cancel failure must still surface as this
    // handler's error.
    var epoch = _operationEpoch;
    try {
      final bool bluetoothIsGranted;
      if (_bluetoothPermissionRequest != null) {
        bluetoothIsGranted = await _bluetoothPermissionRequest();
      } else {
        bluetoothIsGranted = await requestBluetoothPermission();
      }
      if (bluetoothIsGranted) {
        epoch = ++_operationEpoch;
        await espProvisioningService.cancelOperations();
        if (epoch != _operationEpoch) {
          return;
        }
        _emitStateWithClearedError(
          emit,
          status: EspProvisioningStatus.initial,
          bluetoothDevices: const <String>[],
          bluetoothDevice: '',
          wifiNetworks: const <EspWifiNetwork>[],
          wifiNetwork: '',
          wifiProvisioned: false,
        );

        final timedScan = await _runWithTimeout<List<String>>(
          () => espProvisioningService.scanBleDevices(
            event.bluetoothDevicePrefix,
          ),
          const <String>[],
        );

        if (epoch != _operationEpoch) {
          return;
        }
        _emitStateWithTimeoutResult(
          emit,
          status: EspProvisioningStatus.bleScanned,
          bluetoothDevices: timedScan.value,
          timedOut: timedScan.timedOut,
          timeoutOperation: 'scanBleDevices',
          timeoutMessage: 'BLE scan timed out',
        );
      } else if (epoch == _operationEpoch) {
        emit(state.copyWith(
          status: EspProvisioningStatus.error,
          errorCode: EspProvisioningErrorCodes.permission,
          errorDetails: null,
          errorMsg: 'Bluetooth permission not granted',
          failure: EspProvisioningFailure.permissionDenied,
        ));
      }
    } on Object catch (e) {
      if (epoch == _operationEpoch) {
        _emitUnexpectedError(emit, e);
      }
    }
  }

  /// _onBleSelected() is a function that is called when the user selects a bluetooth device from the
  /// list of available bluetooth devices
  ///
  /// Args:
  ///   event (EspProvisioningEventBleSelected): This is the event that was emitted by the UI
  ///   emit (`Emitter<EspProvisioningState>`): This is the function that you use to emit a new state
  Future<void> _onBleSelected(
    EspProvisioningEventBleSelected event,
    Emitter<EspProvisioningState> emit,
  ) async {
    var epoch = _operationEpoch;
    try {
      epoch = ++_operationEpoch;
      await espProvisioningService.cancelOperations();
      if (epoch != _operationEpoch) {
        return;
      }
      if (event.bluetoothDevice == '') {
        _emitStateWithClearedError(
          emit,
          status: EspProvisioningStatus.initial,
          bluetoothDevices: const <String>[],
          bluetoothDevice: '',
          wifiNetworks: const <EspWifiNetwork>[],
          wifiNetwork: '',
          wifiProvisioned: false,
        );
        return;
      }
      _emitStateWithClearedError(
        emit,
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: event.bluetoothDevice,
        wifiNetworks: const <EspWifiNetwork>[],
        wifiNetwork: '',
        wifiProvisioned: false,
      );
      final timedScan = await _runWithTimeout<List<EspWifiNetwork>>(
        () => espProvisioningService.scanWifiNetworks(
          event.bluetoothDevice,
          event.proofOfPossession,
          security: event.security,
          username: event.username,
          connectTimeout: _connectTimeout,
        ),
        const <EspWifiNetwork>[],
      );
      if (epoch != _operationEpoch) {
        return;
      }
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
      if (epoch == _operationEpoch) {
        _emitUnexpectedError(emit, e);
      }
    }
  }

  /// _onWifiSelected() is called when the user selects a wifi network from the list of available
  /// networks. It then calls the provisionWifi() function in the EspProvisioningService class
  ///
  /// Args:
  ///   event (EspProvisioningEventWifiSelected): This is the event that was emitted by the UI
  ///   emit (`Emitter<EspProvisioningState>`): This is the function that you use to emit a new state
  Future<void> _onWifiSelected(
    EspProvisioningEventWifiSelected event,
    Emitter<EspProvisioningState> emit,
  ) async {
    var epoch = _operationEpoch;
    try {
      epoch = ++_operationEpoch;
      await espProvisioningService.cancelOperations();
      if (epoch != _operationEpoch) {
        return;
      }
      _emitStateWithClearedError(
        emit,
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: event.wifiNetwork,
        wifiProvisioned: false,
      );
      final timedProvision = await _runWithTimeout<bool>(
        () => espProvisioningService.provisionWifi(
          event.bluetoothDevice,
          event.proofOfPossession,
          event.wifiNetwork,
          event.password,
          security: event.security,
          username: event.username,
          connectTimeout: _connectTimeout,
        ),
        false,
      );
      if (epoch != _operationEpoch) {
        return;
      }
      _emitStateWithTimeoutResult(
        emit,
        status: EspProvisioningStatus.wifiProvisioned,
        wifiProvisioned: timedProvision.value,
        timedOut: timedProvision.timedOut,
        timeoutOperation: 'provisionWifi',
        timeoutMessage: 'WiFi provisioning timed out',
      );
    } on Object catch (e) {
      if (epoch == _operationEpoch) {
        _emitUnexpectedError(emit, e);
      }
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
        case EspProvisioningErrorCodes.provisioningSessionFailed:
          return EspProvisioningFailure.sessionFailed;
        case EspProvisioningErrorCodes.provisioningAuthFailed:
          return EspProvisioningFailure.authenticationFailed;
        case EspProvisioningErrorCodes.provisioningNetworkNotFound:
          return EspProvisioningFailure.networkNotFound;
        case EspProvisioningErrorCodes.provisioningConfigFailed:
        case EspProvisioningErrorCodes.provisioningFailed:
          return EspProvisioningFailure.provisioningFailed;
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

  @override
  Future<void> close() async {
    // Bumping the epoch marks every in-flight handler stale (so it cannot
    // emit into a closed bloc) before cancelling the native work it started.
    _operationEpoch++;
    try {
      await espProvisioningService.cancelOperations();
    } on Object catch (_) {
      // Best-effort: native operations self-clean on their own timeouts.
    }
    return super.close();
  }

  void _emitStateWithClearedError(
    Emitter<EspProvisioningState> emit, {
    required EspProvisioningStatus status,
    List<String>? bluetoothDevices,
    String? bluetoothDevice,
    List<EspWifiNetwork>? wifiNetworks,
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
    List<EspWifiNetwork>? wifiNetworks,
    String? wifiNetwork,
    bool? wifiProvisioned,
    required bool timedOut,
    required String timeoutOperation,
    required String timeoutMessage,
  }) {
    emit(
      state.copyWith(
        status: timedOut ? EspProvisioningStatus.error : status,
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
    final epoch = _operationEpoch;
    var timedOut = false;
    final value = await action().timeout(
      _requestTimeout,
      onTimeout: () {
        timedOut = true;
        return timeoutValue;
      },
    );
    if (timedOut && epoch == _operationEpoch) {
      try {
        await espProvisioningService.cancelOperations();
      } on Object catch (_) {
        // Best-effort cleanup; the timeout outcome is already being reported.
      }
    }
    return _TimedResult<T>(value: value, timedOut: timedOut);
  }
}

class _TimedResult<T> {
  const _TimedResult({required this.value, required this.timedOut});

  final T value;
  final bool timedOut;
}
