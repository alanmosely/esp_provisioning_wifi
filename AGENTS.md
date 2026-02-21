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
  - Dart: `lib/src/flutter_esp_ble_prov/flutter_esp_ble_prov_method_channel.dart`
  - Android: `android/src/main/kotlin/.../FlutterEspBleProvPlugin.kt`
  - iOS: `ios/Classes/SwiftFlutterEspBleProvPlugin.swift`
- On missing/invalid args, return a proper `FlutterError`/`result.error`, do not crash.

### Android Plugin Rules
- Never leave `TODO("Not yet implemented")` in callback paths.
- Permission result must be checked from `grantResults`; do not assume granted.
- Always return a method result in all branches.
- Avoid stale data leaks: clear device/network scan caches before new scans.

### iOS Plugin Rules
- Avoid force-casts (`as!`) on method arguments.
- Guard `result(...)` so it is invoked only once per method call.
- Return early after error resolution to prevent duplicate responses.

## BLoC / Dart Rules
- Prefer constructor injection for services/timeouts/permission hooks in BLoC to keep tests deterministic.
- Keep timeout behavior explicit and tested.
- Handle nullable platform return values safely.

## Dependency and Metadata Hygiene
When changing releases/dependencies, keep these in sync:
- `pubspec.yaml` version and constraints.
- `CHANGELOG.md` top entry.
- `ios/esp_provisioning_wifi.podspec` version + metadata.
- `pubspec.lock` via `flutter pub get`.

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
