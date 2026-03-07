# DaktarPai - Architecture Overview

## 1. High-Level Summary

DaktarPai is a feature-first Flutter healthcare app backed by Supabase.

Primary capabilities:
- Auth with MFA and security step-up.
- Doctor discovery and detail exploration.
- Multi-step appointment booking and appointment lifecycle handling.
- Medical record management with attachments.
- Profile and account/security settings.

## 2. Project Structure

```text
lib/
  main.dart
  app.dart
  core/
    constants/
    errors/
    localization/
    main_wrapper/
    network/
    router/
    security/
    services/
    theme/
    utils/
    widgets/
  features/
    appointments/
    auth/
    common/
    doctors/
    home/
    legal/
    medical_records/
    menu/
    profile/
    settings/
    splash/
    support/
  presentation/
    widgets/
```

## 3. Architectural Pattern

Feature-first layered architecture:
- Presentation: screens/widgets and local UI state.
- State: singleton `ChangeNotifier` instances for shared app state.
- Data: repositories wrapping Supabase and external APIs.
- Core: routing, guards, security services, telemetry, themes, and shell layout.

## 4. Runtime Composition

### Startup (`main.dart`)
1. Initialize Flutter bindings and environment.
2. Initialize Supabase.
3. Load persisted settings and initialize notifications.
4. Run device integrity enforcement.
5. Wire global error telemetry handlers.
6. Launch `MyApp` (or compromised-device fallback app) in `runZonedGuarded`.

### App Shell (`app.dart`, `MainWrapper`)
- `MaterialApp.router` with centralized `GoRouter` config.
- Global wrappers: `OfflineModeGuard` and `InactivityLockGuard`.
- Global tap-to-unfocus for keyboard dismissal.
- `MainWrapper` owns shell tabs, drawer choreography, app-resume refresh, and bootstraps appointment realtime/profile refresh.

## 5. Key Ownership Decisions

- Routing and redirects: `core/router/app_router.dart`.
- Shared settings: `SettingsNotifier` singleton.
- Shared profile state: `ProfileNotifier` singleton.
- Shared appointments + realtime: `AppointmentNotifier` singleton.
- Data access and mutation: feature repositories.

## 6. Input Architecture (Current)

Input entry points are centralized around `AppTextField` (`lib/presentation/widgets/app_text_field.dart`).

Current state in source:
- Active text-entry screens/dialogs now use `AppTextField`.
- `CustomTextField` and `AuthTextField` are now wrappers that delegate to `AppTextField`.
- Keyboard-sensitive dialogs/sheets use scroll/inset-safe patterns (`SingleChildScrollView` and/or bottom inset padding) where input is present.

## 7. Backend Integration Snapshot

Supabase-backed areas in active use:
- Auth + MFA: `supabase.auth`, `supabase.auth.mfa`.
- Doctors and clinic data: `doctors`, `specialties`, `clinics`, `doctor_clinics`, schedules.
- Appointments/history: `appointments`, `appointment_history`.
- Reviews/complaints: `reviews`, `complaints`.
- Profiles/saved patients: `profiles`, `saved_patients`.
- Medical records + storage buckets.
- Trusted devices: `trusted_devices`.

Additional integration:
- Route geometry: OSRM direct call with edge-function fallback (`route-proxy`).
- Realtime appointments channel managed by `AppointmentNotifier`.

## 8. Platform/Plugin Integration

- Calendar export: `add_2_calendar`.
- Local notifications: `flutter_local_notifications`.
- Biometric step-up: `local_auth`.
- Secure storage and preferences: `flutter_secure_storage`, `shared_preferences`.
- Maps and geolocation stack: `flutter_map`, `latlong2`, `geolocator`, `map_launcher`.
