import 'package:esp_provisioning_wifi/src/flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

/// The EspProvisioningService class is a singleton that returns an instance of the FlutterEspBleProv
/// class
class EspProvisioningService extends FlutterEspBleProv {
  /// A static variable that is used to store the instance of the class
  static EspProvisioningService? _instance;

  EspProvisioningService._internal() {
    _instance = this;
  }

  factory EspProvisioningService() =>
      _instance ?? EspProvisioningService._internal();
}
