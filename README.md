
![logo]

[![pub package][pub_badge]][pub_link]
[![License: MIT][license_badge]][license_link]

# esp_provisioning_wifi

Library to provision WiFi on ESP32 devices over Bluetooth, using Bloc.

## Requirements

### Android 6 (API level 23)+

Make sure your `android/build.gradle` has 23+ here:

```
defaultConfig {
    minSdkVersion 23
}
```

Add this in your `android/app/build.gradle` at the end of repositories:

```
allprojects {
    repositories {
   	 ...
   	 maven { url 'https://jitpack.io' }
    }
}
```

Bluetooth permissions are automatically requested by the library.

### iOS 13.0+


Add this in your `ios/Runner/Info.plist`:
```
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Our app uses bluetooth to find, connect and transfer data between different devices</string>
```

## Notes

### flutter_esp_ble_prov

This library is a [Bloc](https://pub.dev/packages/flutter_bloc) wrapper over [flutter_esp_ble_prov](https://pub.dev/packages/flutter_esp_ble_prov).

### esp-idf-provisioning-android

The [Espressif Android Provisioning library](https://github.com/espressif/esp-idf-provisioning-android) is currently embedded in libs.

[logo]: https://raw.githubusercontent.com/alanmosely/esp_provisioning_wifi/master/logo.png
[pub_badge]: https://img.shields.io/pub/v/esp_provisioning_wifi.svg
[pub_link]: https://pub.dartlang.org/packages/esp_provisioning_wifi
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT