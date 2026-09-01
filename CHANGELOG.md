## 0.2.0

Breaking release, see the migration section in `README.md`.

* Alpha: Rename the method channel to `esp_provisioning_wifi` and the native plugin package/classes (`io.github.alanmosely.esp_provisioning_wifi`, `EspProvisioningWifiPlugin`) so the plugin no longer collides with the upstream `flutter_esp_ble_prov` package
* Alpha: `scanWifiNetworks` now returns `List<EspWifiNetwork>` (`ssid`, `rssi`, `security`) instead of `List<String>`; `rssi`/`security` are populated on Android and pending on iOS
* Alpha: Provisioning failures now reject with typed error codes (`E_PROV_SESSION`, `E_PROV_CONFIG`, `E_PROV_AUTH`, `E_PROV_NETWORK_NOT_FOUND`, `E_PROV_FAILED`) mapped to new `EspProvisioningFailure` values, instead of resolving `false`
* Alpha: Split BLoC timeouts into `connectTimeout` (BLE connect phase, default 15s) and `requestTimeout` (overall, default connect + 20s), replacing the single `TIMEOUT` constant
* Alpha: Timeouts now emit `status: EspProvisioningStatus.error` alongside `failure: timeout`
* Alpha: Deduplicate Android WiFi scan results by SSID, keeping the strongest signal per network
* Alpha: Pin the iOS `ESPProvision` dependency to `~> 3.0` and raise Android Java/Kotlin targets to 11
* Alpha: Upgrade to flutter_bloc 9, bloc_concurrency 0.3, permission_handler 12, flutter_lints 6; require Dart `^3.5.0` and Flutter `>=3.24.0` (permission_handler 13 is deferred until its AGP 9 / compileSdk 37 toolchain requirements are mainstream)
* Alpha: Add GitHub Actions CI (format, analyze, test, publish dry-run, Android example build)

## 0.1.2

* Alpha: Resolve cancelled/superseded Android method calls with `E_CANCELLED` instead of leaving their futures pending forever, matching iOS cancellation semantics
* Alpha: Deliver all Android method channel results on the main thread via a shared `OperationResolver` (Espressif callbacks arrive on background threads)
* Alpha: Fail fast on Android when the BLE connect phase reports connection-failed/disconnected instead of waiting out the connect timeout
* Alpha: Disconnect in-progress Android BLE connect attempts when a connect timeout or connect error fires
* Alpha: Fix Android `fetchCustomData` double-resolving the method call when the optional `payload` argument is omitted
* Alpha: Map iOS ESPProvision failures to contract error codes (`E_BLE_SCAN`, `E1`, `E_CONNECT`, `E_DEVICE`), preserving raw ESP error codes in error details
* Alpha: Cancel in-flight native work when the Dart-side request timeout fires in `EspProvisioningBloc`
* Alpha: Remove the Android manifest `package` attribute and raise `compileSdk` to 34 for AGP 8 compatibility
* Alpha: Align iOS podspec version with the package version
* Alpha: Refresh stale package/README descriptions (native implementations live in this package; the Espressif Android library is resolved via JitPack)

## 0.1.1

* Alpha: Add `fetchCustomData(...)` API across Dart/Android/iOS for provisioning custom endpoint reads

## 0.1.0

* Alpha: Add typed BLoC failure reasons via `EspProvisioningFailure`
* Alpha: Make `provisionWifi` return non-null `bool`
* Alpha: Replace `EspProvisioningState.timedOut` with typed failure checks
* Alpha: Consolidate native/platform error code contracts into shared constants
* Alpha: Add `cancelOperations()` to Dart/platform APIs and native implementations
* Alpha: Add structured bloc diagnostics (`errorCode`, `errorDetails`) to state
* Alpha: Add typed `cancelled` failure mapping for `E_CANCELLED`
* Alpha: Unify configurable connect timeout propagation across Dart/Android/iOS layers
* Alpha: Add iOS operation-token cancellation guards and active-device cleanup
* Alpha: Add public barrel export (`esp_provisioning_wifi.dart`) to avoid `src` imports
* Alpha: Split Android plugin internals into focused Kotlin files
* Alpha: Add transformer behavior tests (`droppable` and `restartable`)
* Alpha: Improve example app to render status/failure transitions via Bloc state
* Alpha: Separate state-only tests from bloc behavior smoke tests
* Alpha: Add example integration test for baseline platform channel contract

## 0.0.7

* Alpha: Harden Android/iOS plugin error handling and permission flow
* Alpha: Expand method channel and bloc flow test coverage
* Alpha: Align iOS podspec metadata with package information

## 0.0.1

* Alpha: First release

## 0.0.2

* Alpha: Improvements to pub.dev score

## 0.0.3

* Alpha: Improvements to pub.dev score (again)

## 0.0.4

* Alpha: Correctly report on provisioning success

## 0.0.5

* Alpha: Add permission-handler and update to latest flutter_esp_ble_prov

## 0.0.6

* Alpha: Fix iOS compilation errors
