# DaktarPai - Architecture Overview

This document describes the current source tree in `lib/` and `supabase/functions/`, not planned architecture.

## 1. Stack Summary

DaktarPai is a feature-first Flutter application with three backend-facing layers:

- Flutter UI with `GoRouter`, Material 3, and shared theme tokens under `lib/core/theme/`
- Supabase for auth, Postgres data, storage, realtime, RPCs, and edge functions
- Firebase Core + Firebase Messaging for push delivery

Shared runtime state is held in singleton `ChangeNotifier`s. Data access is encapsulated in repositories. Local persistence is split intentionally across Hive, `FlutterSecureStorage`, and `SharedPreferences`.

## 2. Startup Pipeline

`lib/main.dart` currently performs startup in this order:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. Best-effort Firebase initialization and registration of the top-level FCM background handler
3. `.env` loading, Hive initialization, and `Supabase.initialize(...)`
4. Registration of an auth-state listener that bootstraps `FcmService` after sign-in
5. Hydration of `SettingsNotifier` and `NotificationNotifier`
6. Initialization of `AppointmentNotificationService`
7. Startup of `NetworkNotifier`
8. Device integrity enforcement through `DeviceIntegrityService.enforceOnStartup()`
9. Global error wiring through `ErrorTelemetryService`, `FlutterError`, `PlatformDispatcher`, `ErrorWidget`, and `runZonedGuarded`
10. Launch of either `MyApp` or a blocked compromised-device shell

`lib/app.dart` then builds `MaterialApp.router` and wraps routed content with:

- `OfflineModeGuard`
- `InactivityLockGuard`

## 3. Runtime Composition

The runtime is organized into four practical layers.

- Presentation
  Screens, dialogs, and widgets live under `lib/features/**/presentation` and `lib/presentation/widgets`.
- Shared state
  `SettingsNotifier`, `ProfileNotifier`, `FavoritesNotifier`, `AppointmentNotifier`, `NotificationNotifier`, and `NetworkNotifier` own cross-screen app state.
- Repositories
  Feature repositories such as `AuthRepository`, `DoctorRepository`, `AppointmentRepository`, `ProfileRepository`, `MedicalRecordRepository`, `HomeRepository`, `RouteRepository`, and `SettingsRepository` encapsulate backend and cache access.
- Cross-cutting services
  Notifications, biometrics, inactivity locking, device integrity, telemetry, and security step-up services live under `lib/core/services/` and `lib/core/security/`.

`MainWrapper` is the main shell surface. It hosts the tabbed `StatefulShellRoute`, the custom 3D drawer, appointment realtime initialization, and app-resume refreshes for appointments and profile data.

## 4. Code Organization

- `lib/core/`
  Router, theme, localization, network guards, security services, error handling, and app-wide utilities
- `lib/features/<feature>/data`
  Repositories, models, secure caches, and feature-specific backend helpers
- `lib/features/<feature>/presentation`
  Screens, notifiers, route-argument models, and feature widgets
- `lib/presentation/widgets`
  Cross-feature UI primitives such as buttons, text fields, cards, snackbars, and dialogs

The app does not use a DI container, Provider, Riverpod, or BLoC. Singletons and repositories are imported directly where needed.

## 5. Local Persistence Map

| Storage | Current responsibilities |
|---|---|
| Hive | Repository caches, offline action queues, home banners, local notification inbox |
| `FlutterSecureStorage` | Secure appointment cache, secure profile cache, booking draft, trusted-device token |
| `SharedPreferences` | Theme mode, notification preferences, inactivity timeout, drawer hint, recent searches, medical-record lock flag |
| App documents directory | Downloaded medical record attachments cached after first open |
| Supabase | Auth session, relational data, storage buckets, realtime, RPCs, edge functions |

Many repository caches use a 60-minute freshness window, but that rule is repository-specific rather than global.

## 6. Backend Touchpoints

The current app depends on these backend surfaces:

- Supabase tables and views
  `profiles`, `appointments`, `appointment_history`, `doctors`, `specialties`, `clinics`, `doctor_clinics`, `doctor_schedules`, `favorite_doctors`, `medical_records`, `saved_patients`, `reviews`, `complaints`, `trusted_devices`, `banners`
- Supabase storage buckets
  `profile_pictures`, `medical_docs`
- Supabase realtime
  `public:appointments`
- Supabase RPCs
  `increment_doctor_views_smart`, `user_has_recovery_codes`, `save_recovery_codes`, `use_recovery_code`, `delete_user_account`
- Supabase edge functions
  `client-error-log`, `route-proxy`, and the scheduled `send-reminders`
- Firebase Messaging
  Push token registration and foreground/background push handling

## 7. Resilience Model

The codebase is explicitly offline-aware but not uniformly offline-capable.

- `AppointmentRepository`, `ProfileRepository`, `MedicalRecordRepository`, and `DoctorRepository` maintain Hive-backed offline action queues.
- `NetworkNotifier` replays those queues on reconnect and exposes `waitForSync()` as a sync barrier for repositories.
- Repositories often return cached data first, then refresh from Supabase when possible.
- `AppointmentNotifier` supplements repository caching with a secure `FlutterSecureStorage` cache for the active appointments list.
- `ProfileNotifier` does the same for the signed-in profile.

## 8. Current Realtime and Error Boundaries

Realtime is currently scoped to appointments only.

- `AppointmentNotifier` subscribes to appointment changes for the signed-in user and silently refetches after change events.
- `MainWrapper` refreshes appointments and profile on app resume.
- There is no equivalent realtime subscription for doctors, profile, medical records, favorites, or the local inbox.

Error handling is centralized more strongly than routing or state management.

- Unhandled Flutter and platform errors are forwarded to `client-error-log`.
- Widget build failures fall back to `AppErrorFallback`.
- A dedicated `RouteErrorScreen` exists in `lib/core/widgets/`, but it is not currently wired into the router.
