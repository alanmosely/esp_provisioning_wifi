import 'dart:async';

import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';
import 'package:esp_provisioning_wifi_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('esp_provisioning_wifi');
  late Completer<String> readiness;
  late List<String> calls;
  Completer<void>? cancellation;

  setUp(() {
    calls = [];
    final recordedCalls = calls;
    cancellation = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recordedCalls.add(call.method);
      switch (call.method) {
        case 'ensureBluetoothReady':
          return readiness.future;
        case 'cancelBluetoothReadiness':
          await cancellation?.future;
          return null;
        case 'cancelOperations':
          return true;
        case 'scanBleDevices':
          return <String>[];
      }
      throw MissingPluginException(call.method);
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> start(WidgetTester tester) async {
    readiness = Completer<String>();
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => EspProvisioningBloc(
          bluetoothPermissionRequest: () async => true,
        ),
        child: const MyAppView(),
      ),
    ));
    await tester.tap(find.byTooltip('Scan BLE devices'));
    await tester.pump();
  }

  testWidgets('waits for readiness and starts exactly one scan when on',
      (tester) async {
    await start(tester);
    await tester.tap(find.byTooltip('Scan BLE devices'));
    await tester.pump();
    expect(calls, ['ensureBluetoothReady']);
    readiness.complete('on');
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'scanBleDevices'), hasLength(1));
    expect(find.textContaining('Scanning BLE devices...'), findsOneWidget);
  });

  for (final state in ['off', 'unauthorized', 'unavailable', 'unknown']) {
    testWidgets('$state provides guidance without scanning and permits retry',
        (tester) async {
      await start(tester);
      readiness.complete(state);
      await tester.pumpAndSettle();
      expect(calls, ['ensureBluetoothReady']);
      expect(find.byTooltip('Cancel Bluetooth check'), findsNothing);
      readiness = Completer<String>();
      await tester.tap(find.byTooltip('Scan BLE devices'));
      await tester.pump();
      readiness.complete('on');
      await tester.pumpAndSettle();
      expect(calls.where((call) => call == 'scanBleDevices'), hasLength(1));
    });
  }

  testWidgets(
      'cancel drops late success and blocks retry until native acknowledgement',
      (tester) async {
    await start(tester);
    cancellation = Completer<void>();
    await tester.tap(find.byTooltip('Cancel Bluetooth check'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cancel Bluetooth check'));
    readiness.complete('on');
    await tester.pump();
    await tester.tap(find.byTooltip('Scan BLE devices'));
    await tester.pump();
    expect(calls, ['ensureBluetoothReady', 'cancelBluetoothReadiness']);
    cancellation!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Bluetooth check cancelled.'), findsOneWidget);
    readiness = Completer<String>();
    await tester.tap(find.byTooltip('Scan BLE devices'));
    await tester.pump();
    readiness.complete('on');
    await tester.pumpAndSettle();
    expect(calls.where((call) => call == 'scanBleDevices'), hasLength(1));
  });

  testWidgets('dispose cancels pending work and ignores late completion',
      (tester) async {
    await start(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    readiness.complete('on');
    await tester.pumpAndSettle();
    expect(calls, contains('cancelBluetoothReadiness'));
    expect(calls, isNot(contains('scanBleDevices')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('native timeout leaves a retryable UI', (tester) async {
    await start(tester);
    readiness.completeError(PlatformException(code: 'E_BLUETOOTH_TIMEOUT'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bluetooth check did not complete.'),
        findsOneWidget);
    expect(find.byTooltip('Cancel Bluetooth check'), findsNothing);
    expect(calls, isNot(contains('scanBleDevices')));
  });
}
