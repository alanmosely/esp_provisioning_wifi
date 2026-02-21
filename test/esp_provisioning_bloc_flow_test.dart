import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_bloc.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_event.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

class FakeProvisioningService extends FlutterEspBleProv {
  FakeProvisioningService({
    Future<List<String>> Function(String prefix)? scanBleDevicesHandler,
    Future<List<String>> Function(String deviceName, String pop)?
        scanWifiNetworksHandler,
    Future<bool?> Function(
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
  final Future<bool?> Function(
    String deviceName,
    String pop,
    String ssid,
    String passphrase,
  )? _provisionWifiHandler;

  @override
  Future<List<String>> scanBleDevices(String prefix) {
    if (_scanBleDevicesHandler == null) {
      return Future<List<String>>.value(const <String>[]);
    }
    return _scanBleDevicesHandler!(prefix);
  }

  @override
  Future<List<String>> scanWifiNetworks(
      String deviceName, String proofOfPossession) {
    if (_scanWifiNetworksHandler == null) {
      return Future<List<String>>.value(const <String>[]);
    }
    return _scanWifiNetworksHandler!(deviceName, proofOfPossession);
  }

  @override
  Future<bool?> provisionWifi(String deviceName, String proofOfPossession,
      String ssid, String passphrase) {
    if (_provisionWifiHandler == null) {
      return Future<bool?>.value(false);
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
    'emits error when bluetooth permission is denied',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(),
      bluetoothPermissionRequest: () async => false,
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) => bloc.add(const EspProvisioningEventStart('PROV_')),
    expect: () => const <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.error,
        errorMsg: 'Bluetooth permission not granted',
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
    expect: () => const <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.initial,
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.bleScanned,
        bluetoothDevices: <String>['PROV_1', 'PROV_2'],
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits timeout state when WiFi scan exceeds timeout',
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
    expect: () => const <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'PROV_1',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: 'PROV_1',
        wifiNetworks: <String>[],
        timedOut: true,
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'handles null provision result as false without throwing',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        provisionWifiHandler: (_, __, ___, ____) => Future<bool?>.value(null),
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
    expect: () => const <EspProvisioningState>[
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
    'emits error when WiFi scan throws',
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
    expect: () => const <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'PROV_1',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.error,
        bluetoothDevice: 'PROV_1',
        errorMsg: 'Exception: scan failed',
      ),
    ],
  );
}
