# BLE provisioning example

This manual integration app demonstrates the public
`package:esp_provisioning_wifi/esp_provisioning_wifi.dart` BLoC API. Use a physical
Android/iOS phone and an ESP32 running compatible Espressif BLE provisioning
firmware; emulators/simulators cannot qualify the BLE flow.

## Run and provision

From this `example/` directory:

```sh
flutter pub get
flutter devices
flutter run -d PHONE_ID
```

Grant the required Bluetooth/location permissions for your platform. Enter the
firmware's advertised device prefix (the demo starts with `PROV_`) and matching
proof-of-possession (demo default `abcd1234`). These are Espressif demo defaults,
not universal credentials for every ESP32. Scan/select a BLE device, scan/select
its Wi-Fi network, enter the Wi-Fi password and provision. The status/failure
panel shows typed outcomes; success requires the actual device to join Wi-Fi.

The checked-in UI uses the API's Security 1 default. Security 2 additionally
needs the firmware-configured SRP6a username and the API's explicit `security`
and `username` arguments; changing only the PoP text does not enable it.
See the [package README](../README.md) for API, platform permissions, cancellation,
timeout semantics, failure codes and Security 2 setup. This example is not the
SleepaSloth product onboarding app.

## Validation limits

```sh
flutter test
flutter test integration_test -d PHONE_ID
```

Widget tests exercise the example with mocked platform behavior. The integration
channel smoke test needs an explicitly selected physical phone; CI does not run
it. Package root analysis/tests do not compile native code; package CI separately
builds the Android and iOS examples. Native builds and tests alone do not prove
successful provisioning against your physical firmware.
