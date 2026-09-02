import 'package:equatable/equatable.dart';

/// WiFi authentication modes reported by ESP provisioning, mirroring
/// Espressif's `WifiAuthMode` values.
enum EspWifiSecurity {
  open,
  wep,
  wpaPsk,
  wpa2Psk,
  wpaWpa2Psk,
  wpa2Enterprise,
  wpa3Psk,
  wpa2Wpa3Psk,
  unknown;

  /// Maps a raw Espressif `WifiAuthMode` integer to a typed value.
  static EspWifiSecurity fromRaw(int? raw) {
    switch (raw) {
      case 0:
        return EspWifiSecurity.open;
      case 1:
        return EspWifiSecurity.wep;
      case 2:
        return EspWifiSecurity.wpaPsk;
      case 3:
        return EspWifiSecurity.wpa2Psk;
      case 4:
        return EspWifiSecurity.wpaWpa2Psk;
      case 5:
        return EspWifiSecurity.wpa2Enterprise;
      case 6:
        return EspWifiSecurity.wpa3Psk;
      case 7:
        return EspWifiSecurity.wpa2Wpa3Psk;
      default:
        return EspWifiSecurity.unknown;
    }
  }
}

/// A WiFi network reported by an ESP device during provisioning.
///
/// Both platforms populate [rssi] and [security]; they are nullable only for
/// tolerant decoding of unexpected payloads.
class EspWifiNetwork extends Equatable {
  const EspWifiNetwork({
    required this.ssid,
    this.rssi,
    this.security,
  });

  /// Builds a network from the raw platform channel map payload.
  ///
  /// Decoding is tolerant: a missing or mistyped `ssid` degrades to an empty
  /// string and mistyped optional fields become null. The method channel
  /// decoder validates payload shape first and rejects entries without a
  /// string `ssid` as `E_INVALID_RESPONSE`, so inside the plugin the tolerant
  /// branches are a safety net only.
  factory EspWifiNetwork.fromMap(Map<Object?, Object?> map) {
    final ssid = map['ssid'];
    final rssi = map['rssi'];
    final security = map['security'];
    return EspWifiNetwork(
      ssid: ssid is String ? ssid : '',
      rssi: rssi is num ? rssi.toInt() : null,
      security:
          security is num ? EspWifiSecurity.fromRaw(security.toInt()) : null,
    );
  }

  final String ssid;

  /// Signal strength in dBm, when reported by the platform.
  final int? rssi;

  /// Authentication mode, when reported by the platform.
  final EspWifiSecurity? security;

  @override
  List<Object?> get props => [ssid, rssi, security];

  @override
  String toString() =>
      'EspWifiNetwork { ssid: $ssid, rssi: $rssi, security: $security }';
}
