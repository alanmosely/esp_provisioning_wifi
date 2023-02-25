import 'dart:developer';

import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

class EspProvisioningService {
  static FlutterEspBleProv? _instance;

  static FlutterEspBleProv? getInstance() {
    _instance ??= FlutterEspBleProv();
    log('EspProvisioningService started');
    return _instance;
  }
}
