# AGENTS.md

## Purpose
This file is guidance for coding agents working in `esp_provisioning_wifi`.
Use it to make safe, consistent changes quickly.

## Project Summary
- Flutter plugin package for provisioning ESP32 WiFi over BLE.
- Includes:
  - Dart API + BLoC wrapper.
  - Native Android plugin (Kotlin).
  - Native iOS plugin (Swift).
  - Unit tests for platform channel and BLoC flows.

## Repo Layout
- `lib/`
  - Public BLoC API: `esp_provisioning_bloc.dart`, events/states/constants.
  - Platform channel wrapper: `src/flutter_esp_ble_prov/*`.
- `android/`
  - Native plugin implementation and gradle config.
- `ios/`
  - Native plugin implementation and podspec.
- `test/`
  - Method channel tests and BLoC flow/state tests.
- `example/`
  - Manual integration app.

## Packaging Note
- `AGENTS.md` is included in the published package tarball on pub.dev.
- Do not include machine-local paths, credentials, secrets, or internal-only operational details.

## Environment / Setup
- Flutter 3.24+ stable (Dart 3.5+). CI pins the validated Flutter version in
  `.github/workflows/ci.yml` (`FLUTTER_VERSION`); bump it deliberately and
  re-run the full local validation.
- JDK 17 (matches CI; the example's AGP 8.7.3 requires it, and the plugin
  module's standalone Gradle 7.5 wrapper fails on JDK 21+).
- Android SDK with the `compileSdk` declared in `android/build.gradle`.
- `gradlew`/`gradlew.bat`, `gradle-wrapper.jar`, and `local.properties` are
  gitignored; a fresh clone has none of them until a Flutter build regenerates
  them (e.g. `flutter build apk --debug` in `example/`).

## Verifying Changes
- `flutter analyze` and `flutter test` do NOT compile any native code.
- Kotlin compile check (pick one):
  - `flutter build apk --debug` in `example/` — the CI path, builds the plugin
    with the app toolchain (AGP 8.7.3 / Gradle 8.12 / Kotlin 2.1.0).
  - Standalone: run the Gradle wrapper in `android/` (e.g.
    `gradlew compileDebugKotlin`). This needs the Flutter embedding jar,
    resolved from `local.properties` `flutter.sdk`, then
    `FLUTTER_ROOT`/`FLUTTER_HOME`; the `where flutter` fallback in
    `android/build.gradle` is Windows-only.
- Swift is NOT compiled by CI (Linux-only jobs) or on non-Mac dev machines.
  Treat Swift edits as unverified: keep them minimal, mirror existing
  patterns, and get a Mac run of `flutter build ios --no-codesign` in
  `example/` (or `pod lib lint ios/esp_provisioning_wifi.podspec`) before a
  release that touches iOS.
- End-to-end verification uses `example/` on a PHYSICAL device (`flutter run`
  from `example/`; emulators/simulators lack usable BLE) against an ESP32
  running Espressif BLE provisioning firmware with Security 1. The example
  pre-fills the Espressif demo defaults (`PROV_` prefix, `abcd1234` PoP).
  The on-device channel smoke test is `flutter test integration_test` from
  `example/`; CI does not run it.

## CI
- `.github/workflows/ci.yml` gates every push to master and every PR:
  `dart format --set-exit-if-changed lib test`, `flutter analyze`,
  `flutter test` (root AND `example/`), `flutter pub publish --dry-run`, and
  `flutter build apk --debug` in `example/` on JDK 17 (the only native
  compile check). Replicate these locally before pushing.

## Preferred Tooling (Use Dart MCP First)
When available, prefer Dart MCP tools over raw shell commands.

Path placeholder convention:
- `<REPO_ROOT>` = absolute path to this repository on the current machine.
- `<REPO_URI>` = `file:///` URI form of `<REPO_ROOT>`.

1. Add root:
   - `mcp__dart__add_roots` with `<REPO_URI>`
2. Analyze:
   - `mcp__dart__analyze_files`
3. Test:
   - `mcp__dart__run_tests`
4. Format:
   - `mcp__dart__dart_format`
5. Dependencies:
   - `mcp__dart__pub` with `get`, `outdated`, `upgrade` as needed

Fallback CLI commands:
- `flutter analyze`
- `flutter test`
- `dart format lib test`
- `flutter pub get`
- `flutter pub outdated`

## Expected Quality Bar
- No analyzer issues.
- All tests passing.
- New behavior covered by tests when practical.
- No crash-on-error paths in platform code.
- Method channel calls must resolve exactly once.

## Critical Platform Rules

### Method Channel Contracts
- Keep method names and argument keys aligned across:
  - Dart channel wrapper: `lib/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_channel.dart`
  - Dart method/key constants: `lib/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_names.dart`
  - Android plugin entry: `android/src/main/kotlin/.../EspProvisioningWifiPlugin.kt`
  - Android method/key constants: `android/src/main/kotlin/.../MethodNames.kt`
  - Android error constants: `android/src/main/kotlin/.../ErrorCodes.kt`
  - iOS plugin: `ios/Classes/SwiftEspProvisioningWifiPlugin.swift`
- On missing/invalid args, return a proper `FlutterError`/`result.error`, do not crash.

### Android Plugin Rules
- Never leave `TODO("Not yet implemented")` in callback paths.
- Permission result must be checked from `grantResults`; do not assume granted.
- Always return a method result in all branches.
- Resolve operation results through `OperationResolver` (main-thread,
  exactly-once, cancellation-aware); never call `Result` methods directly from
  Espressif listener callbacks, which arrive on background threads.
- Cancelled/superseded operations must resolve with `E_CANCELLED`, never be
  left unresolved.
- One native operation at a time: `Boss.startOperation()` supersedes the
  previous operation (bumps the token, disconnects the active device, cancels
  the tracked resolver). New managers must obtain their resolver via
  `startResolver(ctx)` and check `resolver.cancelledIfInactive()` at every
  async callback boundary, disconnecting the device when it returns true.
- `DeviceConnectionEvent` (EventBus) carries NO device identity. Never call
  `ESPDevice.disconnectDevice()` directly — use `ActionManager.disconnect`
  (or precede the call with `boss.noteSelfInitiatedDisconnect()`) so the
  connect subscriber can ignore stale DISCONNECTED events from self-initiated
  teardowns; an unannounced disconnect makes the next connect attempt fail
  spuriously with `E_CONNECT`.
- Avoid stale data leaks: clear device/network scan caches before new scans.

### iOS Plugin Rules
- Nothing compiles the Swift plugin automatically (no macOS CI job, and
  non-Mac dev machines cannot build it) — see "Verifying Changes". Keep Swift
  edits minimal and mirror existing patterns.
- Avoid force-casts (`as!`) on method arguments.
- Guard `result(...)` so it is invoked only once per method call.
- Return early after error resolution to prevent duplicate responses.
- Mirror Android's single-active-operation model via
  `ProvisionOperationCoordinator` tokens and `resolveCancelledIfInactive()`.

## BLoC / Dart Rules
- Public package users should import only:
  - `package:esp_provisioning_wifi/esp_provisioning_wifi.dart`
- Avoid adding new consumer-facing guidance that imports from `lib/src/*`.
- Prefer constructor injection for services/timeouts/permission hooks in BLoC to keep tests deterministic.
- Keep timeout behavior explicit and tested.
- Handle nullable platform return values safely.
- Timeout layering: `connectTimeout` bounds only the native BLE-connect phase
  (sent as the `connectTimeoutMs` argument; native falls back to its own
  default when absent or non-positive). The Dart `requestTimeout` (default
  `connectTimeout` + `kEspDefaultOperationBudget`) wraps the whole call,
  cancels native work on expiry, and must stay strictly greater than
  `connectTimeout`, otherwise typed native codes like `E_CONNECT_TIMEOUT`
  can never surface.
- The 15s connect-timeout default exists in three synced places — change all
  together: `kEspDefaultConnectTimeout` (Dart constants),
  `Boss.DEFAULT_CONNECT_TIMEOUT_MS` (Android), `TimeoutDefaults.connectTimeoutMs` (iOS).
- `EspProvisioningBloc._operationEpoch` guards stale timed-out handlers from
  cancelling a newer operation's native work; new bloc operations must follow
  the `_runWithTimeout`/`_cancelOperations` pattern.
- Cancellation semantics:
  - Native cancellation should map to `E_CANCELLED`.
  - BLoC should map `E_CANCELLED` to `EspProvisioningFailure.cancelled`.
  - Add/maintain tests for cancelled flows.

## Compatibility / SemVer Rules
- Treat these as potentially breaking changes that require explicit migration notes:
  - Adding enum values in public enums (e.g., `EspProvisioningFailure`)
  - Changing `FlutterEspBleProvPlatform` method signatures
  - Changing public imports or API surface
- If such a change is accepted, document migration in `README.md` and `CHANGELOG.md`.

## Dependency and Metadata Hygiene
When changing releases/dependencies, keep these in sync:
- `pubspec.yaml` version and constraints.
- `CHANGELOG.md` top entry (bullets use the `* Alpha:` prefix convention,
  newest release section at the top).
- `ios/esp_provisioning_wifi.podspec` version + metadata.
- Refresh the local `pubspec.lock` via `flutter pub get` to validate
  constraints (it is gitignored per Dart library guidance — never committed).

Pinned dependencies (do not upgrade casually):
- `permission_handler: ^12.x` — 13.x hard-requires `permission_handler_android`
  14, which needs AGP 9 / Kotlin 2.3 / compileSdk 37, beyond mainstream Flutter
  toolchains. Revisit when those are standard.
- `ESPProvision '~> 3.0'` (podspec) and
  `esp-idf-provisioning-android lib-2.1.2` (JitPack) — API changes upstream
  need Swift/Kotlin review before bumping.
- The example's `minSdkVersion Math.max(23, flutter.minSdkVersion)` is written
  as an expression deliberately: the Flutter tool auto-migrates bare numeric
  `minSdkVersion NN` values back to `flutter.minSdkVersion` on build, which
  can drop below the plugin's required 23 on older toolchains.

## Security and Build Hygiene
- Do not add insecure repositories (no HTTP Maven URLs).
- Keep Android/iOS minimums and docs aligned with code:
  - Android `minSdkVersion 23`
  - iOS platform `13.0+`

## Test Targets To Update When Changing Behavior
- Method channel behavior:
  - `test/flutter_esp_ble_prov_method_channel_test.dart`
  - `test/flutter_esp_ble_prov_method_channel_operations_test.dart`
- BLoC behavior:
  - `test/esp_provisioning_state_test.dart`
  - `test/esp_provisioning_bloc_flow_test.dart`
  - `test/esp_provisioning_bloc_basic_test.dart`
- Network model decoding:
  - `test/esp_wifi_network_test.dart`
- Facade / platform interface default:
  - `test/flutter_esp_ble_prov_test.dart`
- Example app widget smoke test (run from `example/`):
  - `example/test/widget_test.dart`

## Safe Git Workflow
- Do not revert unrelated working tree changes.
- If `git` warns about dubious ownership in this environment, use:
  - `git -c safe.directory=<REPO_ROOT> <command>`

## Suggested Change Checklist
1. Implement change.
2. Format touched Dart files.
3. Run analysis.
4. Run tests.
5. Update tests/docs/changelog/metadata as needed.
6. Summarize what changed and why.

## Release Workflow
1. Ensure clean working tree and all checks green locally.
2. Run `flutter pub publish --dry-run`.
3. Verify `pubspec.yaml`, `CHANGELOG.md`, and `ios/esp_provisioning_wifi.podspec` versions match.
4. Commit release changes and push.
5. Wait for the GitHub Actions CI run on the release commit to be green
   (it performs the only automated native compile check).
6. Create and push the annotated git tag (`vX.Y.Z`).
7. Run `flutter pub publish -f` (publishing is irrevocable — only after CI).
