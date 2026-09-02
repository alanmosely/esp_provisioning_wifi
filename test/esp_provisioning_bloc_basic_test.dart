import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';

class _FakeProvisioningService extends FlutterEspBleProv {
  _FakeProvisioningService({
    Future<List<EspWifiNetwork>> Function(String deviceName, String pop)?
        scanWifiNetworksHandler,
    Future<bool> Function(
      String deviceName,
      String pop,
      String ssid,
      String passphrase,
    )? provisionWifiHandler,
  })  : _scanWifiNetworksHandler = scanWifiNetworksHandler,
        _provisionWifiHandler = provisionWifiHandler;

  final Future<List<EspWifiNetwork>> Function(String deviceName, String pop)?
      _scanWifiNetworksHandler;
  final Future<bool> Function(
    String deviceName,
    String pop,
    String ssid,
    String passphrase,
  )? _provisionWifiHandler;

  @override
  Future<bool> cancelOperations() => Future<bool>.value(true);

  @override
  Future<List<EspWifiNetwork>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) {
    if (_scanWifiNetworksHandler == null) {
      return Future<List<EspWifiNetwork>>.value(const <EspWifiNetwork>[]);
    }
    return _scanWifiNetworksHandler(deviceName, proofOfPossession);
  }

  @override
  Future<bool> provisionWifi(
    String deviceName,
    String proofOfPossession,
    String ssid,
    String passphrase, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) {
    if (_provisionWifiHandler == null) {
      return Future<bool>.value(false);
    }
    return _provisionWifiHandler(
      deviceName,
      proofOfPossession,
      ssid,
      passphrase,
    );
  }
}

void main() {
  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits deviceChosen when ble selection starts',
    build: () => EspProvisioningBloc(
      provisioningService: _FakeProvisioningService(
        scanWifiNetworksHandler: (_, __) =>
            Completer<List<EspWifiNetwork>>().future,
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) =>
        bloc.add(const EspProvisioningEventBleSelected('device', 'prefix')),
    wait: const Duration(milliseconds: 20),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'device',
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits networkChosen when wifi selection starts',
    build: () => EspProvisioningBloc(
      provisioningService: _FakeProvisioningService(
        provisionWifiHandler: (_, __, ___, ____) => Completer<bool>().future,
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) => bloc.add(const EspProvisioningEventWifiSelected(
      'device',
      'pop',
      'ssid',
      'password',
    )),
    wait: const Duration(milliseconds: 20),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: 'ssid',
      ),
    ],
  );
}
