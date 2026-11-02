# fleet_saas_driver — Phase 4 (Mobile)

Driver app for the fleet/trips platform (see `../documentation/06-execution-plan.md`
Phase 4). Talks to the real `/api/v1` backend built in Phases 1–3 — there is
no mock/demo mode anywhere in this app.

## Why `android/` and `ios/` aren't in this repo yet

This module was written in a cloud sandbox with no network access to
`storage.googleapis.com` (the Flutter SDK's own distribution host) or
`pub.dev`, so the Flutter toolchain itself could not be installed or run
there — no `flutter create`, `flutter pub get`, `flutter analyze`, or
`flutter test` locally. `.github/workflows/mobile-ci.yml` is the only place
this code has actually been compiled/analyzed/tested so far (via
`subosito/flutter-action`, which runs on a normal GitHub-hosted runner with
full internet access) — check that workflow's latest run before trusting
that `lib/` and `test/` are green.

`flutter analyze` / `flutter test` don't need the `android/`/`ios/` platform
folders at all (they operate at the Dart/Flutter-framework level), which is
why CI can validate this module without them. Actually running the app on a
device does need them. One-time setup, on a machine with the Flutter SDK
installed (this repo's own dev machine already has `.android`/`.gradle`
present, so the Android side of the toolchain is very likely already set
up):

```bash
cd mobile
flutter create . --project-name fleet_saas_driver --org com.fleetsaas
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates core/local_db/app_database.g.dart
```

`flutter create .` in a directory that already has `lib/`, `pubspec.yaml`,
etc. only fills in the platform folders — it does not touch existing
Dart files.

## Running against the real backend

The API base URL is never hard-coded — pass it at run time:

```bash
flutter run --dart-define=API_BASE_URL=http://<backend-host>:8000/api/v1
```

Point this at wherever the Phase 1–3 Laravel backend from `../backend` is
actually reachable from the device/emulator (its own `.env.example` /
deployment docs cover running it). `ApiClient` throws immediately with a
clear message if `API_BASE_URL` was never set, rather than silently talking
to a placeholder host.

## Background location — required native setup

`lib/core/location/location_service.dart` implements the Dart-side adaptive
GPS logic (module 28), but keeping the OS process alive once the app is
fully backgrounded/killed needs native platform configuration that only
exists once `flutter create .` (above) has generated `android/`/`ios/`.
Before relying on background tracking on a real device, add:

**Android** (`android/app/src/main/AndroidManifest.xml`):
- `ACCESS_FINE_LOCATION` and `ACCESS_BACKGROUND_LOCATION` permissions.
- A foreground service declaration with `android:foregroundServiceType="location"`
  (required on Android 10+, enforced more strictly from Android 14) — Android
  requires a persistent, dismiss-proof notification while location tracking
  runs in the background; this is a Play Store policy requirement, not
  optional polish.

**iOS** (`ios/Runner/Info.plist`):
- `NSLocationWhenInUseUsageDescription` and
  `NSLocationAlwaysAndWhenInUseUsageDescription` (both required for the
  "always" upgrade prompt to even appear).
- `UIBackgroundModes` → `location`.
- Request "when in use" first and only upgrade to "always" after the driver
  has used in-app tracking at least once — Apple App Review expects this
  two-step flow, not an upfront "always" prompt on first launch.

## Offline queue

Every mutation (trip status change, cancel, POD upload, SOS) is written to
a local Drift/SQLite queue first (`core/local_db`) and flushed by
`SyncQueueService` — see that class's docblock for the exact idempotency
reasoning (a client-generated UUID per action, no server-side
Idempotency-Key header; `TripStateMachine` rejecting an already-applied
transition is the real safety net). `core/sync/sync_queue_service_test.dart`
covers this in detail.

`/locations/batch` (GPS point sync) is Phase 5 backend scope and does not
exist on the server yet — see `core/location/location_sync_client.dart`'s
docblock. Points stay queued locally with nothing lost until that endpoint
ships.

## Phase 4 Definition of Done — manual verification still pending

Per `../documentation/06-execution-plan.md`: *"تسجيل دخول سائق تجريبي
فعليًا، رؤية رحلة حقيقية من الـ Backend، تغيير حالتها، ورؤية التحديث في
لوحة الإدارة"* (actually log in a test driver, see a real trip from the
backend, change its status, and see the update reflected in the admin
dashboard). This step requires a real device/emulator and cannot be done
from a cloud sandbox — it's the one item this phase leaves for whoever runs
`flutter run` next, after completing the one-time setup above and seeding a
test driver + trip via the backend (e.g. `DemoCompanySeeder` /
`php artisan tinker`, or the Vue admin dashboard once it exists).

## Tests

```bash
flutter test
```

Everything under `test/` is pure Dart/Flutter-framework level — no device,
emulator, or network access required (Drift tests use an in-memory sqlite3
database via `NativeDatabase.memory()`; API-layer tests use a hand-rolled
Dio `HttpClientAdapter` instead of a real HTTP call).
