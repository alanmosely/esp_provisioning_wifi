import 'dart:async';

import 'package:flutter/services.dart';

import 'src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_names.dart';

/// The Bluetooth adapter state observed by the platform.
enum EspBluetoothState { unknown, unavailable, unauthorized, off, on }

/// Bluetooth readiness using Android BluetoothAdapter and iOS Core Bluetooth.
/// Does not scan, connect, or provision an ESP device.
class EspBluetooth {
  EspBluetooth._();

  static const _channel = MethodChannel(FlutterEspBleProvMethodNames.channel);
  static int _nextRequestId = 0;

  /// Requests required permissions and waits for a usable adapter state.
  ///
  /// Android presents the system enable dialog when [requestEnable] is true.
  /// iOS cannot enable the radio; it reports off or denied for caller guidance.
  /// A new call supersedes the previous readiness request with E_CANCELLED.
  /// Timeout includes the user's permission/enable dialogs (maximum 2 minutes).
  static Future<EspBluetoothState> ensureReady({
    bool requestEnable = true,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (timeout.inMilliseconds < 1 || timeout > const Duration(minutes: 2)) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be 1ms to 2 minutes');
    }
    final requestId = ++_nextRequestId;
    final value = await _channel.invokeMethod<String>(
      FlutterEspBleProvMethodNames.ensureBluetoothReady,
      {
        'requestId': requestId,
        'requestEnable': requestEnable,
        'timeoutMs': timeout.inMilliseconds
      },
    ).timeout(timeout + const Duration(seconds: 2), onTimeout: () async {
      // Cancel only this request: a late timeout must not cancel its successor.
      unawaited(_cancel(requestId).catchError((Object _) {}));
      throw TimeoutException('Bluetooth readiness did not complete', timeout);
    });
    return EspBluetoothState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => throw PlatformException(
          code: 'E_BLUETOOTH_STATE',
          message: 'Invalid Bluetooth state: $value'),
    );
  }

  /// Cancels readiness only; existing provisioning operations are unaffected.
  static Future<void> cancel() => _cancel(null);

  static Future<void> _cancel(int? requestId) async {
    await _channel.invokeMethod<void>(
      FlutterEspBleProvMethodNames.cancelBluetoothReadiness,
      {'requestId': requestId},
    );
  }
}
