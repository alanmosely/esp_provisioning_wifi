
![logo]

[![pub package][pub_badge]][pub_link]
[![License: MIT][license_badge]][license_link]

# esp_provisioning_wifi

Library to provision WiFi on ESP32 devices over Bluetooth, using Bloc.

## API Notes

- Import the package via the public barrel:
  - `import 'package:esp_provisioning_wifi/esp_provisioning_wifi.dart';`
- `scanWifiNetworks(...)` returns `Future<List<EspWifiNetwork>>`.
  - Each network exposes `ssid`, plus `rssi` (dBm) and `security` where the
    platform reports them (currently Android only; null on iOS).
- `provisionWifi(...)` returns `Future<bool>`.
  - It resolves `true` on success and throws a `PlatformException` with a typed
    `E_PROV_*` code on failure.
- `cancelOperations()` returns `Future<bool>` and cancels active native work.
  - In-flight scan/provision calls fail with `E_CANCELLED` (`EspProvisioningFailure.cancelled`) on both platforms.
- `EspProvisioningState.failure` exposes typed failures using `EspProvisioningFailure`.
  - `none`, `permissionDenied`, `timeout`, `cancelled`, `deviceNotFound`, `invalidResponse`,
    `sessionFailed`, `authenticationFailed`, `networkNotFound`, `provisioningFailed`,
    `platform`, `unknown`.
- `EspProvisioningState.errorCode` and `errorDetails` expose raw platform diagnostics.
- `scanWifiNetworks(...)` and `provisionWifi(...)` accept optional `connectTimeout`.
  - This timeout is propagated through Dart and native layers for BLE connection timing.
- `EspProvisioningBloc` accepts `connectTimeout` (BLE connect phase, default 15s)
  and `requestTimeout` (overall operation budget, default `connectTimeout` + 20s).
- Dart-side request timeouts cancel the in-flight native operation and emit
  `status: EspProvisioningStatus.error` with `failure == EspProvisioningFailure.timeout`.
- `fetchCustomData(...)` reads provisioning custom endpoint payloads (defaults to endpoint `custom-data`).
  - Useful for firmware-driven provisioning metadata such as lock state or SoftAP password hints.

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
- `E_CUSTOM_DATA`
- `E_DEVICE`
- `E_PROV_SESSION`
- `E_PROV_CONFIG`
- `E_PROV_AUTH`
- `E_PROV_NETWORK_NOT_FOUND`
- `E_PROV_FAILED`
- `DEVICE_DISCONNECTED`
- `E_CANCELLED`
- `E_TIMEOUT`
- `E_UNKNOWN`

Import: `package:esp_provisioning_wifi/esp_provisioning_error_codes.dart`.

## Migration (0.1.x -> 0.2.0)

1. The method channel and native plugin package/classes were renamed, so this
   plugin no longer conflicts with apps that also depend on
   `flutter_esp_ble_prov`. No Dart-side changes are needed for this.
2. `scanWifiNetworks(...)` and `EspProvisioningState.wifiNetworks` now use
   `EspWifiNetwork` instead of `String`. Use `network.ssid` where you previously
   used the string; `rssi` and `security` are available on Android.
3. Provisioning failures now throw typed `PlatformException`s (`E_PROV_SESSION`,
   `E_PROV_CONFIG`, `E_PROV_AUTH`, `E_PROV_NETWORK_NOT_FOUND`, `E_PROV_FAILED`)
   instead of resolving `false`. The bloc maps them to new
   `EspProvisioningFailure` values (`sessionFailed`, `authenticationFailed`,
   `networkNotFound`, `provisioningFailed`); exhaustive switches over
   `EspProvisioningFailure` must handle them.
4. Timeouts now emit `status: EspProvisioningStatus.error` (previously the step
   status was kept with `failure: timeout`).
5. The `TIMEOUT` constant was replaced by `kEspDefaultConnectTimeout` and
   `kEspDefaultOperationBudget`; `EspProvisioningBloc` now takes `connectTimeout`
   and `requestTimeout` parameters.
6. Minimums raised: Dart `^3.5.0`, Flutter `3.24+`, flutter_bloc 9,
   permission_handler 12 (13.x is deferred until its AGP 9 / compileSdk 37
   toolchain requirements are mainstream; pinning `permission_handler: ^13.0.0`
   in your app will conflict with this plugin's `^12.0.3` constraint).

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
      if (state.failure != EspProvisioningFailure.none) {
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

### Origins

This library started as a [Bloc](https://pub.dev/packages/flutter_bloc) wrapper over [flutter_esp_ble_prov](https://pub.dev/packages/flutter_esp_ble_prov). The native Android and iOS provisioning implementations are now maintained inside this package.

### Espressif provisioning libraries

- Android uses [esp-idf-provisioning-android](https://github.com/espressif/esp-idf-provisioning-android), resolved via JitPack.
- iOS uses the [ESPProvision](https://github.com/espressif/esp-idf-provisioning-ios) CocoaPod.

[logo]: https://raw.githubusercontent.com/alanmosely/esp_provisioning_wifi/master/logo.png
[pub_badge]: https://img.shields.io/pub/v/esp_provisioning_wifi.svg
[pub_link]: https://pub.dev/packages/esp_provisioning_wifi
[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
