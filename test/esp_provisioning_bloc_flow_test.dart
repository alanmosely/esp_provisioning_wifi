import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeProvisioningService extends FlutterEspBleProv {
  FakeProvisioningService({
    Future<List<String>> Function(String prefix)? scanBleDevicesHandler,
    Future<List<EspWifiNetwork>> Function(String deviceName, String pop)?
        scanWifiNetworksHandler,
    Future<bool> Function(
      String deviceName,
      String pop,
      String ssid,
      String passphrase,
    )? provisionWifiHandler,
    Future<bool> Function()? cancelOperationsHandler,
  })  : _scanBleDevicesHandler = scanBleDevicesHandler,
        _scanWifiNetworksHandler = scanWifiNetworksHandler,
        _provisionWifiHandler = provisionWifiHandler,
        _cancelOperationsHandler = cancelOperationsHandler;

  final Future<List<String>> Function(String prefix)? _scanBleDevicesHandler;
  final Future<List<EspWifiNetwork>> Function(String deviceName, String pop)?
      _scanWifiNetworksHandler;
  final Future<bool> Function(
    String deviceName,
    String pop,
    String ssid,
    String passphrase,
  )? _provisionWifiHandler;
  final Future<bool> Function()? _cancelOperationsHandler;

  int scanBleDevicesCalls = 0;
  int scanWifiNetworksCalls = 0;
  int provisionWifiCalls = 0;
  int cancelOperationsCalls = 0;
  Duration? lastScanConnectTimeout;
  Duration? lastProvisionConnectTimeout;
  EspSecurityScheme? lastScanSecurity;
  String? lastScanUsername;
  EspSecurityScheme? lastProvisionSecurity;
  String? lastProvisionUsername;

  @override
  Future<List<String>> scanBleDevices(String prefix) {
    scanBleDevicesCalls++;
    if (_scanBleDevicesHandler == null) {
      return Future<List<String>>.value(const <String>[]);
    }
    return _scanBleDevicesHandler(prefix);
  }

  @override
  Future<List<EspWifiNetwork>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession, {
    EspSecurityScheme security = EspSecurityScheme.security1,
    String? username,
    Duration? connectTimeout,
  }) {
    scanWifiNetworksCalls++;
    lastScanConnectTimeout = connectTimeout;
    lastScanSecurity = security;
    lastScanUsername = username;
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
    provisionWifiCalls++;
    lastProvisionConnectTimeout = connectTimeout;
    lastProvisionSecurity = security;
    lastProvisionUsername = username;
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

  @override
  Future<bool> cancelOperations() {
    cancelOperationsCalls++;
    if (_cancelOperationsHandler == null) {
      return Future<bool>.value(true);
    }
    return _cancelOperationsHandler();
  }
}

void main() {
  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits typed permission error when bluetooth permission is denied',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(),
      bluetoothPermissionRequest: () async => false,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 10),
    ),
    act: (bloc) => bloc.add(const EspProvisioningEventStart('PROV_')),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.error,
        errorCode: EspProvisioningErrorCodes.permission,
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
      connectTimeout: const Duration(milliseconds: 5),
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
    'emits error status and timeout failure when WiFi scan exceeds timeout',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (_, __) =>
            Completer<List<EspWifiNetwork>>().future,
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
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
        status: EspProvisioningStatus.error,
        bluetoothDevice: 'PROV_1',
        wifiNetworks: const <EspWifiNetwork>[],
        errorCode: EspProvisioningErrorCodes.timeout,
        errorDetails: 'scanWifiNetworks timeout after 0:00:00.010000',
        errorMsg: 'WiFi scan timed out',
        failure: EspProvisioningFailure.timeout,
      ),
    ],
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      // Once when the handler starts, once to cancel the timed-out native
      // operation, and once more when the bloc closes.
      expect(service.cancelOperationsCalls, 3);
    },
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'handles provision result as bool without throwing',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        provisionWifiHandler: (_, __, ___, ____) => Future<bool>.value(false),
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
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
        scanWifiNetworksHandler: (_, __) => Future<List<EspWifiNetwork>>.error(
          Exception('scan failed'),
        ),
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
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
        errorCode: EspProvisioningErrorCodes.unknown,
        errorMsg: 'Exception: scan failed',
        failure: EspProvisioningFailure.unknown,
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits cancelled failure for cancelled platform operations',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (_, __) => Future<List<EspWifiNetwork>>.error(
          PlatformException(
            code: EspProvisioningErrorCodes.cancelled,
            message: 'Operation cancelled',
          ),
        ),
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
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
        errorCode: EspProvisioningErrorCodes.cancelled,
        errorMsg: 'Operation cancelled',
        failure: EspProvisioningFailure.cancelled,
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
        connectTimeout: const Duration(milliseconds: 5),
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
            return const <EspWifiNetwork>[EspWifiNetwork(ssid: 'old-network')];
          }
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return const <EspWifiNetwork>[EspWifiNetwork(ssid: 'new-network')];
        },
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
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
        wifiNetworks: const <EspWifiNetwork>[
          EspWifiNetwork(ssid: 'new-network'),
        ],
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'stale timed-out handler does not cancel a newer operation',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (deviceName, _) {
          if (deviceName == 'stale') {
            // Simulates a cancelled native call that never resolves.
            return Completer<List<EspWifiNetwork>>().future;
          }
          return Future<List<EspWifiNetwork>>.delayed(
            const Duration(milliseconds: 20),
            () => const <EspWifiNetwork>[EspWifiNetwork(ssid: 'fresh-net')],
          );
        },
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 40),
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventBleSelected('stale', 'pop'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const EspProvisioningEventBleSelected('fresh', 'pop'));
    },
    wait: const Duration(milliseconds: 120),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'stale',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'fresh',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: 'fresh',
        wifiNetworks: const <EspWifiNetwork>[EspWifiNetwork(ssid: 'fresh-net')],
      ),
    ],
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      // One cancel per handler start plus one on close; the stale handler's
      // late timeout must not add another cancel against the newer operation.
      expect(service.cancelOperationsCalls, 3);
    },
  );

  for (final entry in <String, EspProvisioningFailure>{
    EspProvisioningErrorCodes.provisioningSessionFailed:
        EspProvisioningFailure.sessionFailed,
    EspProvisioningErrorCodes.provisioningAuthFailed:
        EspProvisioningFailure.authenticationFailed,
    EspProvisioningErrorCodes.provisioningNetworkNotFound:
        EspProvisioningFailure.networkNotFound,
    EspProvisioningErrorCodes.provisioningConfigFailed:
        EspProvisioningFailure.provisioningFailed,
    EspProvisioningErrorCodes.provisioningFailed:
        EspProvisioningFailure.provisioningFailed,
    EspProvisioningErrorCodes.connectTimeout: EspProvisioningFailure.timeout,
  }.entries) {
    blocTest<EspProvisioningBloc, EspProvisioningState>(
      'maps native ${entry.key} to ${entry.value}',
      build: () => EspProvisioningBloc(
        provisioningService: FakeProvisioningService(
          provisionWifiHandler: (_, __, ___, ____) => Future<bool>.error(
            PlatformException(code: entry.key, message: 'native failure'),
          ),
        ),
        bluetoothPermissionRequest: () async => true,
        connectTimeout: const Duration(milliseconds: 5),
        requestTimeout: const Duration(milliseconds: 250),
      ),
      act: (bloc) => bloc.add(const EspProvisioningEventWifiSelected(
        'PROV_1',
        'abcd1234',
        'home-wifi',
        'wrong-password',
      )),
      expect: () => <EspProvisioningState>[
        EspProvisioningState(
          status: EspProvisioningStatus.networkChosen,
          wifiNetwork: 'home-wifi',
        ),
        EspProvisioningState(
          status: EspProvisioningStatus.error,
          wifiNetwork: 'home-wifi',
          errorCode: entry.key,
          errorMsg: 'native failure',
          failure: entry.value,
        ),
      ],
    );
  }

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'forwards the configured connectTimeout to native scan and provision',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(seconds: 5),
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'pop'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const EspProvisioningEventWifiSelected(
        'PROV_1',
        'pop',
        'home-wifi',
        'secret',
      ));
    },
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      expect(service.lastScanConnectTimeout, const Duration(seconds: 5));
      expect(service.lastProvisionConnectTimeout, const Duration(seconds: 5));
    },
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'passes the event security scheme and username through to the service',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(),
      bluetoothPermissionRequest: () async => true,
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventBleSelected(
        'PROV_1',
        'abcd1234',
        security: EspSecurityScheme.security2,
        username: 'wifiprov',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const EspProvisioningEventWifiSelected(
        'PROV_1',
        'abcd1234',
        'home-wifi',
        'secret',
        security: EspSecurityScheme.security2,
        username: 'wifiprov',
      ));
    },
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      expect(service.lastScanSecurity, EspSecurityScheme.security2);
      expect(service.lastScanUsername, 'wifiprov');
      expect(service.lastProvisionSecurity, EspSecurityScheme.security2);
      expect(service.lastProvisionUsername, 'wifiprov');
    },
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'defaults the native connectTimeout to kEspDefaultConnectTimeout',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(),
      bluetoothPermissionRequest: () async => true,
    ),
    act: (bloc) =>
        bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'pop')),
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      expect(service.lastScanConnectTimeout, kEspDefaultConnectTimeout);
    },
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
      connectTimeout: const Duration(milliseconds: 5),
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

  late Completer<List<String>> pendingBleScan;
  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'superseded start handler does not clobber the newer flow with its '
    'cancellation error',
    build: () {
      pendingBleScan = Completer<List<String>>();
      return EspProvisioningBloc(
        provisioningService: FakeProvisioningService(
          scanBleDevicesHandler: (_) => pendingBleScan.future,
        ),
        bluetoothPermissionRequest: () async => true,
        connectTimeout: const Duration(milliseconds: 5),
        requestTimeout: const Duration(milliseconds: 250),
      );
    },
    act: (bloc) async {
      bloc.add(const EspProvisioningEventStart('PROV_'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'pop'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      // The BleSelected handler's cancelOperations makes native reject the
      // superseded BLE scan; the stale start handler must swallow it instead
      // of emitting an error over the new flow's state.
      pendingBleScan.completeError(PlatformException(
        code: EspProvisioningErrorCodes.cancelled,
        message: 'Operation cancelled',
      ));
    },
    wait: const Duration(milliseconds: 60),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(status: EspProvisioningStatus.initial),
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'PROV_1',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: 'PROV_1',
      ),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'deselecting the device resets the previous selection state',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanWifiNetworksHandler: (_, __) async =>
            const <EspWifiNetwork>[EspWifiNetwork(ssid: 'home-wifi')],
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'pop'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const EspProvisioningEventBleSelected('', 'pop'));
    },
    wait: const Duration(milliseconds: 60),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevice: 'PROV_1',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiScanned,
        bluetoothDevice: 'PROV_1',
        wifiNetworks: const <EspWifiNetwork>[EspWifiNetwork(ssid: 'home-wifi')],
      ),
      // Fully reset: no stale device name, network list, or selection.
      EspProvisioningState(status: EspProvisioningStatus.initial),
    ],
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'restarting the flow clears previous provisioning results',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        scanBleDevicesHandler: (_) async => const <String>['PROV_1'],
        provisionWifiHandler: (_, __, ___, ____) async => true,
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) async {
      bloc.add(const EspProvisioningEventWifiSelected(
        'PROV_1',
        'pop',
        'home-wifi',
        'secret',
      ));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const EspProvisioningEventStart('PROV_'));
    },
    wait: const Duration(milliseconds: 60),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.networkChosen,
        wifiNetwork: 'home-wifi',
      ),
      EspProvisioningState(
        status: EspProvisioningStatus.wifiProvisioned,
        wifiNetwork: 'home-wifi',
        wifiProvisioned: true,
      ),
      // The restarted flow must not carry the previous provisioning result.
      EspProvisioningState(status: EspProvisioningStatus.initial),
      EspProvisioningState(
        status: EspProvisioningStatus.bleScanned,
        bluetoothDevices: const <String>['PROV_1'],
      ),
    ],
  );

  late Completer<bool> victimCancel;
  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'handler superseded while awaiting its native cancel stays stale',
    build: () {
      victimCancel = Completer<bool>();
      var cancelCalls = 0;
      return EspProvisioningBloc(
        provisioningService: FakeProvisioningService(
          scanBleDevicesHandler: (_) async => const <String>['fresh-device'],
          cancelOperationsHandler: () {
            cancelCalls++;
            // Park the first handler inside its native-cancel await so a
            // concurrent start event can supersede it mid-cancel.
            if (cancelCalls == 1) {
              return victimCancel.future;
            }
            return Future<bool>.value(true);
          },
        ),
        bluetoothPermissionRequest: () async => true,
        connectTimeout: const Duration(milliseconds: 5),
        requestTimeout: const Duration(milliseconds: 250),
      );
    },
    act: (bloc) async {
      bloc.add(const EspProvisioningEventBleSelected('victim', 'pop'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const EspProvisioningEventStart('PROV_'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      victimCancel.complete(true);
    },
    wait: const Duration(milliseconds: 60),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(status: EspProvisioningStatus.initial),
      EspProvisioningState(
        status: EspProvisioningStatus.bleScanned,
        bluetoothDevices: const <String>['fresh-device'],
      ),
    ],
    verify: (bloc) {
      final service = bloc.espProvisioningService as FakeProvisioningService;
      // The superseded handler must not start native work after resuming.
      expect(service.scanWifiNetworksCalls, 0);
    },
  );

  blocTest<EspProvisioningBloc, EspProvisioningState>(
    'emits error when the native cancelOperations fails',
    build: () => EspProvisioningBloc(
      provisioningService: FakeProvisioningService(
        cancelOperationsHandler: () => Future<bool>.error(
          PlatformException(code: 'E_NATIVE', message: 'channel broken'),
        ),
      ),
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 250),
    ),
    act: (bloc) =>
        bloc.add(const EspProvisioningEventBleSelected('PROV_1', 'pop')),
    expect: () => <EspProvisioningState>[
      EspProvisioningState(
        status: EspProvisioningStatus.error,
        errorCode: 'E_NATIVE',
        errorMsg: 'channel broken',
        failure: EspProvisioningFailure.platform,
      ),
    ],
  );

  test('constructor rejects requestTimeout <= connectTimeout', () {
    expect(
      () => EspProvisioningBloc(
        provisioningService: FakeProvisioningService(),
        bluetoothPermissionRequest: () async => true,
        connectTimeout: const Duration(seconds: 15),
        requestTimeout: const Duration(seconds: 10),
      ),
      throwsArgumentError,
    );
    expect(
      () => EspProvisioningBloc(
        provisioningService: FakeProvisioningService(),
        bluetoothPermissionRequest: () async => true,
        requestTimeout: const Duration(seconds: 15),
      ),
      throwsArgumentError,
    );
  });

  test('close cancels in-flight native operations', () async {
    final service = FakeProvisioningService(
      scanBleDevicesHandler: (_) => Completer<List<String>>().future,
    );
    final bloc = EspProvisioningBloc(
      provisioningService: service,
      bluetoothPermissionRequest: () async => true,
      connectTimeout: const Duration(milliseconds: 5),
      requestTimeout: const Duration(milliseconds: 50),
    );
    bloc.add(const EspProvisioningEventStart('PROV_'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final callsBeforeClose = service.cancelOperationsCalls;
    await bloc.close();
    expect(service.cancelOperationsCalls, callsBeforeClose + 1);
  });
}
