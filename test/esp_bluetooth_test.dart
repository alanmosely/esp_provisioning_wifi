import 'dart:async';

import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('esp_provisioning_wifi');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final state in EspBluetoothState.values) {
    test('decodes native ${state.name}', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'ensureBluetoothReady');
        expect(call.arguments['requestEnable'], isTrue);
        expect(call.arguments['timeoutMs'], 60000);
        expect(call.arguments['requestId'], isA<int>());
        return state.name;
      });
      expect(await EspBluetooth.ensureReady(), state);
    });
  }

  test('passes explicit enable choice and bounded timeout', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.arguments['requestEnable'], isFalse);
      expect(call.arguments['timeoutMs'], 500);
      return 'off';
    });
    expect(
        await EspBluetooth.ensureReady(
            requestEnable: false, timeout: const Duration(milliseconds: 500)),
        EspBluetoothState.off);
  });

  for (final value in <Object?>[null, 'unexpected']) {
    test('rejects invalid native response $value', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => value);
      await expectLater(
          EspBluetooth.ensureReady(), throwsA(isA<PlatformException>()));
    });
  }

  test('preserves cancellation and native failure codes', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'E_CANCELLED');
    });
    await expectLater(
        EspBluetooth.ensureReady(),
        throwsA(isA<PlatformException>()
            .having((error) => error.code, 'code', 'E_CANCELLED')));
  });

  test('rejects invalid deadlines without invoking native code', () async {
    messenger.setMockMethodCallHandler(
        channel, (_) async => fail('native call'));
    for (final duration in [Duration.zero, const Duration(minutes: 3)]) {
      await expectLater(
          EspBluetooth.ensureReady(timeout: duration), throwsArgumentError);
    }
  });

  test('explicit cancellation targets readiness only', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'cancelBluetoothReadiness');
      expect(call.arguments['requestId'], isNull);
      return null;
    });
    await EspBluetooth.cancel();
  });

  testWidgets('a stalled bridge cancels only the timed-out request',
      (tester) async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'cancelBluetoothReadiness') return null;
      return Completer<String>().future;
    });
    final first =
        EspBluetooth.ensureReady(timeout: const Duration(milliseconds: 10));
    final expectation = expectLater(first, throwsA(isA<TimeoutException>()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await expectation;
    await tester.pump();
    expect(calls.last.method, 'cancelBluetoothReadiness');
    expect(
        calls.last.arguments['requestId'], calls.first.arguments['requestId']);
  });
}
