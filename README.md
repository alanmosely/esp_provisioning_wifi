
![logo]

[![pub package][pub_badge]][pub_link]
[![License: MIT][license_badge]][license_link]

# esp_provisioning_wifi

Library to provision WiFi on ESP32 devices over Bluetooth, using Bloc.

## API Notes

- Import the package via the public barrel:
  - `import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';`
- `provisionWifi(...)` returns `Future<bool>` (non-null).
  - `true` means provisioning completed successfully.
  - `false` means provisioning completed but was not successful.
- `cancelOperations()` returns `Future<bool>` and cancels active native work.
- `EspProvisioningState.failure` exposes typed failures using `EspProvisioningFailure`.
  - `none`, `permissionDenied`, `timeout`, `cancelled`, `deviceNotFound`, `invalidResponse`, `platform`, `unknown`.
- `EspProvisioningState.errorCode` and `errorDetails` expose raw platform diagnostics.
- `EspProvisioningState.timedOut` is removed and replaced by typed failure checks:
  - use `state.failure == EspProvisioningFailure.timeout`.
- `scanWifiNetworks(...)` and `provisionWifi(...)` accept optional `connectTimeout`.
  - This timeout is propagated through Dart and native layers for BLE connection timing.

### Error Code Contract

Native layers report stable error codes that the bloc maps into `EspProvisioningFailure`:

- `E0` (`EspProvisioningErrorCodes.missingArgument`)
- `E1` (`EspProvisioningErrorCodes.wifiScanFailed`)
- `E_PERMISSION`
- `E_BLE_SCAN_START`
- `E_BLE_SCAN`
- `E_DEVICE_NOT_FOUND`
- `E_INVALID_RESPONSE`
- `E_CONNECT_TIMEOUT`
- `E_CONNECT`
- `E_DEVICE`
- `DEVICE_DISCONNECTED`
- `E_CANCELLED`
- `E_TIMEOUT`
- `E_UNKNOWN`

Import: `package:esp_provisioning_wifi/esp_provisioning_error_codes.dart`.

## Migration (0.0.x -> 0.1.0)

1. Replace `state.timedOut` checks with `state.failure == EspProvisioningFailure.timeout`.
2. For error UX and telemetry, use both:
   - `state.failure` for typed handling
   - `state.errorCode` and `state.errorDetails` for diagnostics
3. If you call service methods directly, invoke `cancelOperations()` before starting a new scan/provision flow to cancel stale native operations.
4. Replace direct `src` imports with:
   - `import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';`

## Usage

```dart
BlocProvider(
  create: (_) => EspProvisioningBloc(),
  child: BlocConsumer<EspProvisioningBloc, EspProvisioningState>(
    listener: (_, state) {
      if (state.status == EspProvisioningStatus.error) {
        // Use typed failure for user-facing behavior.
        debugPrint('Failure: ${state.failure} | ${state.errorMsg}');
      }
    },
    builder: (_, state) {
      return Text('Status: ${state.status}');
    },
  ),
)
```

## Requirements

### Android 6 (API level 23)+

Make sure your `android/build.gradle` has 23+ here:

```
defaultConfig {
    minSdkVersion 23
}
```

If your app enforces repositories via `settings.gradle` (`dependencyResolutionManagement`),
ensure `jitpack.io` is present:

```
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
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
[pub_link]: https://pub.dev/packages/esp_provisioning_wifi
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
