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
