import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProvisioningService extends FlutterEspBleProv {
  FakeProvisioningService({
    Future<List<String>> Function(String prefix)? scanBleDevicesHandler,
    Future<List<String>> Function(String deviceName, String pop)?
        scanWifiNetworksHandler,
    Future<bool> Function(
      String deviceName,
      String pop,
      String ssid,
      String passphrase,
    )? provisionWifiHandler,
  })  : _scanBleDevicesHandler = scanBleDevicesHandler,
        _scanWifiNetworksHandler = scanWifiNetworksHandler,
        _provisionWifiHandler = provisionWifiHandler;

  final Future<List<String>> Function(String prefix)? _scanBleDevicesHandler;
  final Future<List<String>> Function(String deviceName, String pop)?
      _scanWifiNetworksHandler;
  final Future<bool> Function(
    String deviceName,
    String pop,
    String ssid,
    String passphrase,
  )? _provisionWifiHandler;

  int scanBleDevicesCalls = 0;
  int scanWifiNetworksCalls = 0;
  int provisionWifiCalls = 0;

  @override
  Future<List<String>> scanBleDevices(String prefix) {
    scanBleDevicesCalls++;
    if (_scanBleDevicesHandler == null) {
      return Future<List<String>>.value(const <String>[]);
    }
    return _scanBleDevicesHandler!(prefix);
  }

  @override
  Future<List<String>> scanWifiNetworks(
      String deviceName, String proofOfPossession) {
    scanWifiNetworksCalls++;
    if (_scanWifiNetworksHandler == null) {
      return Future<List<String>>.value(const <String>[]);
    }
    return _scanWifiNetworksHandler!(deviceName, proofOfPossession);
  }

  @override
  Future<bool> provisionWifi(String deviceName, String proofOfPossession,
      String ssid, String passphrase) {
    provisionWifiCalls++;
    if (_provisionWifiHandler == null) {
      return Future<bool>.value(false);
    }
    return _provisionWifiHandler!(
      deviceName,
      proofOfPossession,
      ssid,
      passphrase,
    );
  }
}

void main() {
  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits typed permission error when bluetooth permission is denied',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(),
      bluetoothPermissionRequest: () async => false,
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) => bloc.add(const EspProvisioningEventStart('PROV_')),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.error,
        errorMsg: 'Bluetooth permission not granted',
        failure: EspProvisioningFailure.permissionDenied,
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits scanned BLE devices when permission granted',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanBleDevicesHandler: (_) async => const <String>['PROV_1', 'PROV_2'],
      ),
      bluetoothPermissionRequest: () async => true,
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) => bloc.add(const EspProvisioningEventStart('PROV_')),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.initial,
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.bleScanned,
        bluetoothDevices: const <String>['PROV_1', 'PROV_2'],
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits timeout state and failure type when WiFi scan exceeds timeout',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (_, __) => Completer<List<String>>().future,
      ),
      bluetoothPermissionRequest: () async => true,
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) =>
        bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'abcd1234')),
    wait: const Duration(milliseconds: 30),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'PROV_1',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: 'PROV_1',
        wifiNetworks: const <String>[],
        timedOut: true,
        errorMsg: 'WiFi scan timed out',
        failure: EspProvisioningFailure.timeout,
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'handles provision result as bool without throwing',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        provisionWifiHandler: (_, __, ___, ____) => Future<bool>.value(false),
      ),
      bluetoothPermissionRequest: () async => true,
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) => bloc.add(const EspProvisioningEventWifiSelected(
      'PROV_1',
      'abcd1234',
      'home-wifi',
      'secret',
    )),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: 'home-wifi',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiProvisioned,
        wifiNetwork: 'home-wifi',
        wifiProvisioned: false,
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits typed unknown failure when WiFi scan throws',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (_, __) => Future<List<String>>.error(
          Exception('scan failed'),
        ),
      ),
      bluetoothPermissionRequest: () async => true,
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) =>
        bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'abcd1234')),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'PROV_1',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.error,
        bluetoothDevice: 'PROV_1',
        errorMsg: 'Exception: scan failed',
        failure: EspProvisioningFailure.unknown,
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'drops overlapping start events (droppable)',
    build: () {
      final service = FakeProvisioningService(
        scanBleDevicesHandler: (prefix) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return <String>['$prefix-device'];
        },
      );
      return EspProvisioningBloc(
        provisioningService: service,
        bluetoothPermissionRequest: () async => true,
        requestTimeout: const Duration(milliseconds: 250),
      );
    },
    act: (bloc) {
      bloc.add(const EspProvisioningEventStart('FIRST'));
      bloc.add(const EspProvisioningEventStart('SECOND'));
    },
    wait: const Duration(milliseconds: 120),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(status: EspProvisioningStatus.initial),
      EspProvisioningState(
        status: EspProvisioningStatus.bleScanned,
        bluetoothDevices: const <String>['FIRST-device'],
      ),
    ],
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      expect(service.scanBleDevicesCalls, 1);
    },
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'keeps only latest WiFi scan completion (restartable ble selection)',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (deviceName, _) async {
          if (deviceName == 'first') {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            return const <String>['old-network'];
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const <String>['new-network'];
        },
      ),
      bluetoothPermissionRequest: () async => true,
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventBleSelected('first', 'pop'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(const EspProvisioningEventBleSelected('second', 'pop'));
    },
    wait: const Duration(milliseconds: 140),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'first',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'second',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: 'second',
        wifiNetworks: const <String>['new-network'],
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'keeps only latest provisioning completion (restartable wifi selection)',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        provisionWifiHandler: (_, __, ssid, ___) async {
          if (ssid == 'slow') {
            await Future<void>.delayed(const Duration(milliseconds: 80));
            return false;
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return true;
        },
      ),
      bluetoothPermissionRequest: () async => true,
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventWifiSelected(
        'PROV_1',
        'abcd1234',
        'slow',
        'secret',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      bloc.add(const EspProvisioningEventWifiSelected(
        'PROV_1',
        'abcd1234',
        'fast',
        'secret',
      ));
    },
    wait: const Duration(milliseconds: 140),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: 'slow',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: 'fast',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiProvisioned,
        wifiNetwork: 'fast',
        wifiProvisioned: true,
      ),
    ],
  );
}
