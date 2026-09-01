import 'package:esp_provisioning_wifi/esp_wifi_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EspWifiSecurity.fromRaw', () {
    test('maps all documented WifiAuthMode values', () {
      expect(EspWifiSecurity.fromRaw(0), EspWifiSecurity.open);
      expect(EspWifiSecurity.fromRaw(1), EspWifiSecurity.wep);
      expect(EspWifiSecurity.fromRaw(2), EspWifiSecurity.wpaPsk);
      expect(EspWifiSecurity.fromRaw(3), EspWifiSecurity.wpa2Psk);
      expect(EspWifiSecurity.fromRaw(4), EspWifiSecurity.wpaWpa2Psk);
      expect(EspWifiSecurity.fromRaw(5), EspWifiSecurity.wpa2Enterprise);
      expect(EspWifiSecurity.fromRaw(6), EspWifiSecurity.wpa3Psk);
      expect(EspWifiSecurity.fromRaw(7), EspWifiSecurity.wpa2Wpa3Psk);
    });

    test('maps out-of-range and null values to unknown', () {
      expect(EspWifiSecurity.fromRaw(8), EspWifiSecurity.unknown);
      expect(EspWifiSecurity.fromRaw(-1), EspWifiSecurity.unknown);
      expect(EspWifiSecurity.fromRaw(null), EspWifiSecurity.unknown);
    });
  });

  group('EspWifiNetwork.fromMap', () {
    test('decodes a full Android payload', () {
      final network = EspWifiNetwork.fromMap(const <Object?, Object?>{
        'ssid': 'home-wifi',
        'rssi': -45,
        'security': 3,
      });
      expect(
        network,
        const EspWifiNetwork(
          ssid: 'home-wifi',
          rssi: -45,
          security: EspWifiSecurity.wpa2Psk,
        ),
      );
    });

    test('tolerates an ssid-only payload (iOS)', () {
      final network = EspWifiNetwork.fromMap(const <Object?, Object?>{
        'ssid': 'office-wifi',
      });
      expect(network, const EspWifiNetwork(ssid: 'office-wifi'));
      expect(network.rssi, isNull);
      expect(network.security, isNull);
    });

    test('tolerates mistyped optional fields', () {
      final network = EspWifiNetwork.fromMap(const <Object?, Object?>{
        'ssid': 'x',
        'rssi': 'strong',
        'security': 'wpa2',
      });
      expect(network.ssid, 'x');
      expect(network.rssi, isNull);
      expect(network.security, isNull);
    });

    test('truncates a double rssi to an int', () {
      final network = EspWifiNetwork.fromMap(const <Object?, Object?>{
        'ssid': 'x',
        'rssi': -45.6,
      });
      expect(network.rssi, -45);
    });

    test('degrades a missing ssid to an empty string', () {
      // The method channel decoder rejects such payloads before this factory
      // runs; direct callers get the tolerant fallback.
      final network =
          EspWifiNetwork.fromMap(const <Object?, Object?>{'rssi': -45});
      expect(network.ssid, '');
    });
  });
}
