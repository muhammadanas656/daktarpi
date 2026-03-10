# DaktarPai - State Management and Data Flow

## 1. State Model

The app uses:
- singleton `ChangeNotifier` objects for shared state
- repository classes for backend and local persistence
- local `StatefulWidget` state for screen-specific interaction

There is no external state-management framework in the current codebase.

## 2. Shared Notifiers

| Notifier | Responsibility |
|---|---|
| `SettingsNotifier` | Theme, inactivity timeout, medical-record lock state, notification preferences, drawer hint |
| `ProfileNotifier` | Current profile, secure profile cache hydration, profile-derived display values |
| `FavoritesNotifier` | Favorite doctor ids with optimistic toggle behavior |
| `AppointmentNotifier` | Appointments list, pending reviews, pending complaints, secure appointment cache, appointment realtime subscription |
| `NotificationNotifier` | Local notification inbox state |
| `NetworkNotifier` | Connectivity status, reconnect sync, and sync gating |

## 3. Repository Read Flow

The usual read path is:

1. screen or notifier requests data
2. repository checks local state and connectivity
3. cached data may be returned immediately
4. fresh Supabase data is fetched when allowed
5. repository stores updated cache
6. notifier or screen rebuilds with the latest state

Common patterns in the current repositories:
- Hive-backed caches for appointments, doctors, profile data, medical records, banners, and offline queues
- 60-minute freshness windows for many repository caches
- cached fallback on backend failure where possible

## 4. Repository Write Flow

Write behavior depends on the feature:

- online-safe writes go straight to Supabase
- offline-capable writes are added to a repository queue in Hive
- reconnect-time replay is triggered by `NetworkNotifier`

Current reconnect replay scope:
- appointments
- profile and saved patients
- medical records

Current gap:
- doctor favorite toggles can be queued by `DoctorRepository`, but `NetworkNotifier` does not currently replay that queue centrally

## 5. Storage Mapping

Current local storage usage is:

| Storage | Current usage |
|---|---|
| Hive | repository caches, offline action queues, home banners, local notification inbox |
| `FlutterSecureStorage` | secure appointment cache, secure profile cache, booking draft, trusted-device token |
| `SharedPreferences` | settings, toggles, inactivity timeout, recent searches |

This split matters because not every cached item lives in Hive.

## 6. Realtime and Refresh Rules

Realtime is currently limited to appointments.

- `AppointmentNotifier` subscribes to Supabase changes for the current user's appointments.
- Realtime changes trigger a silent background fetch.
- `MainWrapper` refreshes appointments and profile on app resume.
- `AccountActivityScreen` listens to `NetworkNotifier` so it can refresh after reconnect.

There is no current realtime subscription for profile, doctors, medical records, or the notification inbox.

## 7. Local Screen State

Not every feature uses a notifier.

Examples of screen-level state that stays local:
- booking form controllers and draft debounce in `PatientDetailsScreen`
- slot selection and loading state in `AppointmentConfirmationScreen`
- payment-processing state in `DummyPaymentScreen`
- search text, hint visibility, and recent-search UI in `GlobalSearchScreen`
- medical-record viewer dialogs and attachment opening state

This keeps global state focused on cross-screen data instead of transient widget interaction.
