import 'dart:developer';

import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

/// The EspProvisioningService class is a singleton that returns an instance of the FlutterEspBleProv
/// class
class EspProvisioningService {
  /// A static variable that is used to store the instance of the class
  static FlutterEspBleProv? _instance;

/// If the instance is null, create a new instance and return it. Otherwise, return the existing
/// instance
/// 
/// Returns:
///   The instance of the class
  static FlutterEspBleProv? getInstance() {
    _instance ??= FlutterEspBleProv();
    log('EspProvisioningService started');
    return _instance;
  }
}
