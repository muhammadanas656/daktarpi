# DaktarPai - Architecture Overview

## 1. Summary

DaktarPai is a feature-first Flutter app backed by Supabase.

Current architectural building blocks:
- Flutter UI with `GoRouter` navigation.
- `ChangeNotifier` singletons for shared app state.
- Repository classes for Supabase access, caching, and offline queues.
- Local persistence split across Hive, `FlutterSecureStorage`, and `SharedPreferences`.
- Platform services for notifications, biometrics, device integrity, and error telemetry.

## 2. Startup Sequence

`lib/main.dart` currently does the following before `runApp`:
1. Initializes Flutter bindings, dotenv, Hive, and Supabase.
2. Loads persisted settings through `SettingsNotifier`.
3. Loads the local notification inbox through `NotificationNotifier`.
4. Initializes `AppointmentNotificationService`.
5. Starts `NetworkNotifier`.
6. Runs `DeviceIntegrityService.enforceOnStartup()`.
7. Installs global error telemetry and fallback error UI.

`lib/app.dart` then builds `MaterialApp.router` and wraps routed content with:
- `OfflineModeGuard`
- `InactivityLockGuard`

## 3. Runtime Layers

The app follows a practical layered structure:

- Presentation
  Screens, dialogs, and reusable widgets under `lib/features/**/presentation` and `lib/presentation/widgets`.
- Shared state
  `SettingsNotifier`, `ProfileNotifier`, `FavoritesNotifier`, `AppointmentNotifier`, `NotificationNotifier`, and `NetworkNotifier`.
- Data access
  Feature repositories such as `AuthRepository`, `DoctorRepository`, `AppointmentRepository`, `ProfileRepository`, and `MedicalRecordRepository`.
- Platform and cross-cutting services
  Notifications, device integrity, biometrics, inactivity lock, and telemetry.

## 4. Persistence Model

Current storage responsibilities are split as follows:

| Purpose | Implementation |
|---|---|
| Repository caches and offline queues | Hive |
| Notification inbox | Hive |
| Secure appointment cache | `AppointmentSecureCacheRepository` with `FlutterSecureStorage` |
| Secure profile cache | `ProfileSecureCacheRepository` with `FlutterSecureStorage` |
| Booking draft | `BookingDraftRepository` with `FlutterSecureStorage` |
| Trusted device token | `TrustedDeviceRepository` with `FlutterSecureStorage` |
| Settings and recent searches | `SharedPreferences` |
| Auth, database, file storage | Supabase |

Many repository caches use a 60-minute freshness window. That rule is not global to every local store.

## 5. Offline and Sync Behavior

The app is offline-aware, but not every feature behaves the same way.

- `AppointmentRepository`, `ProfileRepository`, and `MedicalRecordRepository` keep Hive-backed offline action queues.
- `NetworkNotifier` replays those three queues when connectivity returns.
- `DoctorRepository` also has an offline queue for favorite toggles, but `NetworkNotifier` does not currently call `DoctorRepository.syncOfflineQueue()`.
- Repositories call `NetworkNotifier.waitForSync()` before fresh reads so reconnect-time queue replay finishes before live fetches resume.

Operations that still require a live backend include:
- global search
- live booked-slot checks
- profile picture uploads
- medical file uploads
- signed medical file URLs

## 6. Realtime and Refresh

Realtime is currently scoped to appointments.

- `AppointmentNotifier` subscribes to Supabase Realtime changes on `appointments` for the signed-in user.
- Appointment changes trigger a silent refetch instead of a full-screen reload.
- `MainWrapper` also refreshes appointments and profile data when the app resumes.

There is no equivalent realtime subscription in the current code for doctors, profile, notifications, or medical records.
