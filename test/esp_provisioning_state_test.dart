import 'package:esp_provisioning_wifi/esp_provisioning_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspProvisioningState', () {
    test('has expected default values', () {
      final state = EspProvisioningState();

      expect(state.status, EspProvisioningStatus.initial);
      expect(state.bluetoothDevices, isEmpty);
      expect(state.bluetoothDevice, '');
      expect(state.wifiNetworks, isEmpty);
      expect(state.wifiNetwork, '');
      expect(state.wifiProvisioned, isFalse);
      expect(state.errorCode, isNull);
      expect(state.errorDetails, isNull);
      expect(state.errorMsg, '');
      expect(state.failure, EspProvisioningFailure.none);
    });

    test('defensively copies list inputs', () {
      final bluetoothDevices = <String>['device-1'];
      final wifiNetworks = <String>['ssid-1'];
      final state = EspProvisioningState(
        bluetoothDevices: bluetoothDevices,
        wifiNetworks: wifiNetworks,
      );

      bluetoothDevices.add('device-2');
      wifiNetworks.add('ssid-2');

      expect(state.bluetoothDevices, <String>['device-1']);
      expect(state.wifiNetworks, <String>['ssid-1']);
      expect(
          () => state.bluetoothDevices.add('device-3'), throwsUnsupportedError);
      expect(() => state.wifiNetworks.add('ssid-3'), throwsUnsupportedError);
    });

    test('copyWith updates selected fields while preserving others', () {
      final original = EspProvisioningState(
        status: EspProvisioningStatus.deviceChosen,
        bluetoothDevices: const <String>['PROV_1'],
        bluetoothDevice: 'PROV_1',
      );

      final next = original.copyWith(
        status: EspProvisioningStatus.error,
        errorMsg: 'Something failed',
        failure: EspProvisioningFailure.platform,
      );

      expect(next.status, EspProvisioningStatus.error);
      expect(next.errorMsg, 'Something failed');
      expect(next.failure, EspProvisioningFailure.platform);
      expect(next.bluetoothDevices, const <String>['PROV_1']);
      expect(next.bluetoothDevice, 'PROV_1');
    });

    test('copyWith can explicitly clear nullable error fields', () {
      final original = EspProvisioningState(
        errorCode: 'E1',
        errorDetails: 'details',
        errorMsg: 'failed',
      );

      final next = original.copyWith(
        errorCode: null,
        errorDetails: null,
      );

      expect(next.errorCode, isNull);
      expect(next.errorDetails, isNull);
      expect(next.errorMsg, 'failed');
    });
  });
}
