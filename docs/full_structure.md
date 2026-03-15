# DaktarPai - Full Source Structure Map

This document is the repo-level companion to `01_architecture.md`, `05_features_reference.md`, and `06_state_management_and_data_flow.md`. It maps the current source tree as it exists today. Generated `*.g.dart` and `*.freezed.dart` files are omitted from the trees below unless they matter structurally.

## 1. Repository Layout

```text
assets/             Static app assets
docs/               Architecture, flow, security, design, features, state, and SQL docs
integration_test/   End-to-end and stress scenarios
lib/                Production Flutter application code
supabase/           Edge functions, migrations, and local Supabase config
test/               Unit and widget tests
web/                Flutter web shell assets

android/
ios/
macos/
linux/
windows/            Standard Flutter platform runners

pubspec.yaml        Flutter dependencies and asset declarations
firebase.json       Firebase project config
supabase_add_country_iso.sql
                    Standalone SQL helper script kept at repo root
```

## 2. Startup and Runtime Spine

The main runtime path is:

1. `lib/main.dart`
   Initializes Firebase, Hive, Supabase, settings hydration, notification inbox hydration, local reminder service, connectivity sync, device-integrity enforcement, and telemetry hooks.
2. `lib/app.dart`
   Builds `MaterialApp.router`, applies theme and localization, and wraps routed content in `OfflineModeGuard` and `InactivityLockGuard`.
3. `lib/core/router/app_router.dart`
   Owns the route table, auth-driven redirects, and the `StatefulShellRoute` tab shell.
4. `lib/core/main_wrapper/main_wrapper.dart`
   Hosts the 4-tab shell, custom drawer animation, appointment realtime startup, and resume-time refreshes for appointments and profile data.

The app does not use Provider, Riverpod, BLoC, or a DI container. Shared state is held in singleton `ChangeNotifier`s and imported directly where needed.

## 3. Shared State and Persistence Map

| State owner | Main responsibility | Backing persistence |
|---|---|---|
| `SettingsNotifier` | Theme mode, drawer hint, inactivity timeout, notification preferences, medical-record lock, cached biometric and 2FA flags | `SharedPreferences` |
| `ProfileNotifier` | Signed-in profile, avatar, display name, currency/location-derived convenience values | `ProfileSecureCacheRepository` plus `ProfileRepository` |
| `AppointmentNotifier` | Appointments, pending reviews, pending complaints, activity log, realtime subscription | `AppointmentSecureCacheRepository` plus `AppointmentRepository` |
| `FavoritesNotifier` | Favorite doctor IDs plus hydrated favorite doctor maps | RAM-first, persisted through `DoctorRepository` |
| `DoctorsNotifier` | Shared doctor lists, hospitals, clinics, popular doctors, featured doctors, and specialties | RAM-first, backed by `DoctorRepository` Hive caches |
| `NotificationNotifier` | Local inbox list and unread-count rules | Hive via `NotificationRepository` |
| `NetworkNotifier` | Connectivity state, reconnect sync barrier, offline queue replay | Runtime only |

Offline queue replay currently exists in:

- `AppointmentRepository`
- `ProfileRepository`
- `MedicalRecordRepository`
- `DoctorRepository`

Realtime is currently limited to appointments.

## 4. `lib/` Structure

### Root Files

```text
lib/
|-- app.dart
|-- main.dart
|-- firebase_options.dart
|-- test_auth_check.dart
|-- core/
|-- data/
|-- features/
|-- presentation/
`-- services/
```

- `main.dart`
  App bootstrap, FCM background handler, startup hydration, telemetry wiring, and compromised-device fallback shell.
- `app.dart`
  `MaterialApp.router` wrapper.
- `firebase_options.dart`
  FlutterFire-generated platform config.
- `test_auth_check.dart`
  Standalone auth diagnostic entry point kept under `lib/`.
- `services/`
  Currently an empty placeholder directory; shared runtime services are still implemented under `lib/core/services/`.

### Core Layer

```text
lib/core/
|-- constants/
|   |-- app_routes.dart
|   `-- legal_text.dart
|-- errors/
|   `-- app_failure.dart
|-- localization/
|   `-- app_localizations.dart
|-- main_wrapper/
|   `-- main_wrapper.dart
|-- network/
|   |-- network_notifier.dart
|   `-- offline_mode_guard.dart
|-- router/
|   |-- app_router.dart
|   `-- auth_refresh_stream.dart
|-- security/
|   |-- biometric_auth_service.dart
|   |-- biometric_helper_service.dart
|   |-- biometric_security_service.dart
|   |-- device_integrity_service.dart
|   |-- inactivity_lock_guard.dart
|   `-- sensitive_action_step_up_service.dart
|-- services/
|   |-- appointment_notification_service.dart
|   |-- error_telemetry_service.dart
|   `-- fcm_service.dart
|-- theme/
|   |-- app_colors.dart
|   |-- app_dimens.dart
|   |-- app_motion.dart
|   |-- app_shapes.dart
|   |-- app_styles.dart
|   |-- app_text_styles.dart
|   `-- app_theme.dart
|-- utils/
|   |-- backup_code_formatter.dart
|   |-- navigation_helper.dart
|   `-- security_formatters.dart
`-- widgets/
    |-- app_loader.dart
    |-- app_error_fallback.dart
    |-- custom_app_bar.dart
    |-- custom_card.dart
    |-- empty_state_widget.dart
    `-- route_error_screen.dart
```

Current ownership inside `lib/core/`:

- `constants/`
  Route constants and in-app legal copy.
- `errors/`
  Typed failure model used across repositories and security flows.
- `network/`
  Connectivity banner plus reconnect-sync coordinator.
- `router/`
  GoRouter graph and auth refresh bridge.
- `security/`
  Device integrity, biometrics, inactivity locking, and step-up authentication helpers.
- `services/`
  Local notification scheduling, FCM integration, and client error telemetry.
- `theme/`
  Shared design tokens and theme construction.
- `widgets/`
  Global reusable widgets such as the shared loader, app bars, cards, empty states, and fallback UI for build or route failures.

### Shared Data and Cross-Feature Widgets

```text
lib/data/
`-- services/
    `-- user_service.dart

lib/presentation/widgets/
|-- app_network_image.dart
|-- app_text_field.dart
|-- appointment_card.dart
|-- auth_text_field.dart
|-- complaint_dialog.dart
|-- custom_search_bar.dart
|-- custom_snackbar.dart
|-- custom_text_field.dart
|-- doctor_list_card.dart
|-- featured_doctor_card.dart
|-- home_featured_doctor_card.dart
|-- home_popular_doctor_card.dart
|-- pessimistic_switch.dart
|-- primary_button.dart
`-- social_button.dart
```

- `lib/data/services/user_service.dart`
  Older generic user helper outside the newer feature-first repository layout.
- `lib/presentation/widgets/`
  Cross-feature UI primitives shared by auth, booking, doctors, home, and settings flows.

## 5. Feature Modules

### `lib/features/appointments/`

```text
appointments/
|-- data/
|   |-- appointment.dart
|   |-- appointment_repository.dart
|   |-- appointment_secure_cache_repository.dart
|   `-- booking_draft_repository.dart
`-- presentation/
    |-- appointment_notifier.dart
    |-- models/
    |   `-- booking_route_args.dart
    |-- screens/
    |   |-- appointment_confirmation_screen.dart
    |   |-- dummy_payment_screen.dart
    |   |-- my_appointments_screen.dart
    |   `-- patient_details_screen.dart
    `-- widgets/
        `-- live_countdown_badge.dart
```

- Owns booking, appointment history surfaces, secure appointment cache, complaint/review submission, and appointment realtime refresh.

### `lib/features/auth/`

```text
auth/
|-- data/
|   |-- auth_entry_route_service.dart
|   |-- auth_repository.dart
|   |-- auth_route_resolver.dart
|   |-- security_gate_service.dart
|   |-- trusted_device_repository.dart
|   `-- trusted_device_service.dart
`-- presentation/
    |-- models/
    |   `-- verify_2fa_route_args.dart
    `-- screens/
        |-- login_screen.dart
        |-- signup_screen.dart
        `-- verify_2fa_screen.dart
```

- Encapsulates Supabase auth, post-auth route resolution, TOTP and recovery-code verification, and trusted-device flows.

### `lib/features/common/`

```text
common/
`-- presentation/
    `-- screens/
        `-- enable_location_screen.dart
```

- Holds shared non-domain screens that do not justify a larger feature module.

### `lib/features/doctors/`

```text
doctors/
|-- data/
|   |-- clinic.dart
|   |-- doctor.dart
|   |-- doctor_repository.dart
|   |-- route_repository.dart
|   `-- specialty.dart
`-- presentation/
    |-- doctors_notifier.dart
    |-- favorites_notifier.dart
    |-- models/
    |   `-- doctors_route_args.dart
    |-- screens/
    |   |-- clinic_doctors_screen.dart
    |   |-- doctor_details_screen.dart
    |   |-- doctors_screen.dart
    |   |-- featured_doctors_screen.dart
    |   |-- global_search_screen.dart
    |   |-- my_doctors_screen.dart
    |   |-- popular_doctors_screen.dart
    |   `-- specialty_doctors_screen.dart
    `-- widgets/
        |-- clinic_location_map_section.dart
        |-- doctor_appointment_card.dart
        |-- doctor_details_header.dart
        |-- doctor_stats_row.dart
        `-- doctor_timing_list.dart
```

- Owns doctor discovery, favorites, clinic maps, route drawing, specialty navigation, and shared doctor list state.
- `DoctorRepository` also owns Hive caching and the offline queue for favorite toggles.

### `lib/features/home/`

```text
home/
|-- data/
|   `-- home_repository.dart
`-- presentation/
    |-- screens/
    |   `-- home_screen.dart
    `-- widgets/
        |-- home_banner.dart
        |-- home_header.dart
        |-- home_section_header.dart
        `-- home_specialties_row.dart
```

- The dashboard entry point. Pulls banners, specialties, and curated doctor lists for the signed-in region.

### `lib/features/legal/`

```text
legal/
`-- presentation/
    `-- screens/
        `-- terms_of_service_screen.dart
```

### `lib/features/medical_records/`

```text
medical_records/
|-- data/
|   |-- medical_record.dart
|   `-- medical_record_repository.dart
`-- presentation/
    |-- models/
    |   `-- medical_record_route_args.dart
    |-- screens/
    |   |-- add_record_screen.dart
    |   `-- medical_records_screen.dart
    `-- widgets/
        `-- record_card.dart
```

- Owns medical record list, add/edit/delete metadata, attachment upload, signed URL access, local file caching after download, and offline metadata queueing.

### `lib/features/menu/`

```text
menu/
|-- data/
|   `-- settings_repository.dart
`-- presentation/
    |-- screens/
    |   |-- account_activity_screen.dart
    |   |-- linked_accounts_screen.dart
    |   |-- privacy_policy_screen.dart
    |   `-- settings_screen.dart
    `-- widgets/
        |-- custom_drawer.dart
        |-- review_dialog.dart
        |-- settings_account_security_section.dart
        |-- settings_preferences_section.dart
        |-- settings_section_header.dart
        |-- settings_support_legal_section.dart
        `-- settings_tile.dart
```

- Groups account-management UI, settings UI sections, the app drawer, and sensitive account actions such as MFA management, provider linking, password changes, and account deletion.

### `lib/features/notifications/`

```text
notifications/
|-- data/
|   `-- notification_repository.dart
`-- presentation/
    |-- notification_notifier.dart
    `-- screens/
        `-- notifications_screen.dart
```

- The notification inbox is local-first and device-scoped.
- Sources include booking confirmation writes, scheduled reminder entries, foreground FCM handling, and the top-level Firebase background handler in `main.dart`.

### `lib/features/profile/`

```text
profile/
|-- data/
|   |-- profile_repository.dart
|   |-- profile_secure_cache_repository.dart
|   `-- user_profile.dart
`-- presentation/
    |-- profile_notifier.dart
    `-- screens/
        |-- profile_screen.dart
        `-- profileview_screen.dart
```

- Owns signed-in user profile data, picture upload, saved-patient management, and secure profile hydration.

### `lib/features/settings/`

```text
settings/
`-- presentation/
    `-- settings_notifier.dart
```

- This module only contains the global settings state owner. The visible settings screens and widgets live under `lib/features/menu/`.

### `lib/features/splash/`

```text
splash/
`-- presentation/
    `-- screens/
        `-- splash_screen.dart
```

### `lib/features/support/`

```text
support/
|-- data/
|   `-- faq_data.dart
`-- presentation/
    `-- screens/
        `-- help_center_screen.dart
```

- Holds FAQ content and the help-center screen.

## 6. Backend, Tests, and Support Files

### Supabase

```text
supabase/
|-- config.toml
|-- functions/
|   |-- client-error-log/
|   |   `-- index.ts
|   |-- route-proxy/
|   |   `-- index.ts
|   `-- send-reminders/
|       |-- deno.json
|       `-- index.ts
`-- migrations/
    `-- 20260221183000_add_trusted_devices.sql
```

- `client-error-log`
  Receives client telemetry from `ErrorTelemetryService`.
- `route-proxy`
  Server-side route helper used by doctor map navigation.
- `send-reminders`
  Scheduled reminder function.

### Tests

```text
test/
|-- core/
|   |-- errors/
|   |   `-- app_failure_test.dart
|   `-- utils/
|       `-- security_formatters_test.dart
|-- features/
|   |-- appointments/
|   |   `-- presentation/
|   |       `-- models/
|   |           `-- booking_route_args_test.dart
|   |-- auth/
|   |   `-- data/
|   |       |-- auth_route_resolver_test.dart
|   |       `-- security_gate_service_test.dart
|   `-- medical_records/
|       `-- presentation/
|           `-- models/
|               `-- medical_record_route_args_test.dart
|-- test_db_diagnostic_test.dart
`-- widget_test.dart

integration_test/
|-- auth_2fa_records_flow_test.dart
|-- booking_flow_test.dart
|-- heavy_load_scroll_test.dart
|-- inactivity_lock_booking_resume_test.dart
|-- medical_record_network_chaos_test.dart
`-- stress_test.dart
```

- `test/`
  Unit coverage for route resolution, security-gate behavior, failure handling, formatters, route-argument models, and database diagnostics.
- `integration_test/`
  Cross-feature flows and resilience scenarios.

### Documentation and Assets

```text
docs/
|-- 01_architecture.md
|-- 02_app_flow_and_navigation.md
|-- 03_security.md
|-- 04_design_system_and_animations.md
|-- 05_features_reference.md
|-- 06_state_management_and_data_flow.md
|-- 07_sql.md
`-- full_structure.md

assets/
`-- images/
    `-- logo.png
```

## 7. Practical Reading Order

For a new developer, the fastest accurate reading order is:

1. `docs/01_architecture.md`
2. `docs/02_app_flow_and_navigation.md`
3. `docs/06_state_management_and_data_flow.md`
4. `lib/main.dart`
5. `lib/app.dart`
6. `lib/core/router/app_router.dart`
7. `lib/core/main_wrapper/main_wrapper.dart`
8. The feature folder you intend to modify

That path gives the current architecture, runtime flow, shared state model, and then the specific feature implementation.
