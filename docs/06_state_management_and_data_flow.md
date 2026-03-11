# DaktarPai - State Management and Data Flow

## 1. State Model

The app uses three state layers:

- singleton `ChangeNotifier`s for cross-screen app state
- repositories for backend access, cache policy, and offline queues
- local `StatefulWidget` state for transient interaction

There is no external state-management framework. Singletons are imported and listened to directly.

The result is a mixed model:

- notifier-managed RAM for domains that need cross-screen consistency
- direct repository calls or `FutureBuilder` for narrower, screen-local read models

## 2. Shared Notifiers

| Notifier | Current responsibility | Persistence / hydration |
|---|---|---|
| `SettingsNotifier` | Theme mode, drawer hint, inactivity timeout, notification preferences, medical-record lock flag, cached biometric/2FA capability flags | `SharedPreferences` |
| `ProfileNotifier` | Current user profile plus convenience values like avatar, display name, and currency symbol | Secure cache first, then `ProfileRepository` refresh |
| `FavoritesNotifier` | Favorite doctor ids plus full favorite doctor maps | Backend-backed, RAM-first after load |
| `AppointmentNotifier` | Upcoming appointments, pending review items, pending complaint items, activity log, realtime subscription state | Secure cache first, then repository refresh |
| `NotificationNotifier` | Local inbox list and unread-count rules | Hive |
| `NetworkNotifier` | Connectivity state, reconnect sync barrier, queue replay coordination | Runtime only |

## 3. Centralized Domains

The most centralized domains in the current codebase are favorites, profile, appointments, notifications, and app settings.

### Favorites

- `FavoritesNotifier` stores both ids and full doctor maps
- `MyDoctorsScreen` reads the favorites tab directly from RAM
- toggles update UI immediately and then call `DoctorRepository.toggleFavorite(...)`
- real database errors revert the optimistic state; transient network failures are queued instead

### Profile

- `ProfileNotifier.loadProfile()` hydrates from secure storage first
- it then refreshes from `ProfileRepository`
- profile edits push updated values back into the notifier so other screens refresh without manual refetches

### Appointments and activity

- `AppointmentNotifier.fetchAppointments()` fetches appointments, pending reviews, pending complaints, and the activity log together
- the notifier also owns appointment realtime subscription setup
- `AccountActivityScreen` reads the notifier's shared activity log instead of loading a separate copy
- complaint and review submissions update RAM immediately before the repository finishes syncing

### Notifications

- `NotificationNotifier` owns the device-local inbox only
- it sorts notifications by timestamp and hides future-dated reminders from unread calculations and the visible notifications screen

## 4. Repository Read Flow

The common read pattern is:

1. screen or notifier requests data
2. repository checks connectivity and local cache
3. cached data may be returned immediately
4. `NetworkNotifier.waitForSync()` blocks fresh reads if reconnect queue replay is still running
5. fresh Supabase data is fetched when allowed
6. cache is updated
7. screen or notifier rebuilds

Common repository patterns today:

- Hive-backed list caches for doctors, appointments, records, banners, and offline queues
- secure caches for the signed-in profile and appointment list
- 60-minute freshness windows in several repositories
- cached fallback on backend failure where possible

## 5. Repository Write Flow

Writes follow one of three paths depending on the feature.

- Direct online write
  Used when the action is simple and connectivity is available.
- Optimistic RAM update plus background write
  Used for favorites, complaints, and reviews where fast UI feedback matters.
- Offline queue
  Used when a repository explicitly supports reconnect replay.

Current offline-queue scope:

- appointments
- profile updates and saved-patient changes
- medical-record metadata changes
- doctor favorites

`NetworkNotifier` is the coordinator for reconnect replay. It sets `_isSyncing`, exposes `waitForSync()`, replays all supported queues, and then silently refreshes appointments.

## 6. Notification Data Flow

Notifications are intentionally local-first.

Current write sources:

- `DummyPaymentScreen` for booking confirmations and scheduled in-app reminders
- `FcmService` for foreground FCM messages
- the top-level Firebase background handler in `main.dart` for background or terminated-state FCM messages

Current read path:

1. notifications are loaded from Hive on startup
2. `NotificationNotifier` sorts them newest-first
3. `NotificationsScreen` only renders entries whose timestamp is already due

That means the inbox doubles as both a delivered-notification list and a time-released reminder queue.

## 7. Realtime and Refresh Rules

Realtime is currently limited to appointments.

- `AppointmentNotifier` subscribes to `public:appointments` for the signed-in user
- change events trigger a silent background fetch
- `NetworkNotifier` triggers a silent appointment refresh after reconnect sync
- `MainWrapper` refreshes appointments and profile on app resume

There is no realtime subscription for doctors, favorites, profile, medical records, or the local inbox.

## 8. What Still Lives in Local Screen State

Large parts of the app still use local widget state by design.

Examples:

- auth form fields, forgot-password flow state, and Google sign-in loading flags
- doctor-list search controllers, debounces, and selected filters
- booking-form controllers, draft debounce, selected patient category, and local image selection
- slot-selection state in `AppointmentConfirmationScreen`
- payment-processing state in `DummyPaymentScreen`
- map-navigation controls in `ClinicLocationMapSection`
- medical-record file selection, viewer dialogs, and download/open state
- settings dialog step state and MFA enrollment wizard progress

The architecture intentionally keeps this transient state local rather than forcing it into a global notifier.

## 9. Current State-Management Tradeoffs

The current model works well for the app's present shape, but it is intentionally pragmatic rather than pure.

- Cross-screen data that frequently drifts now lives in notifiers
- Read-mostly or one-screen-only data still uses repository calls and `FutureBuilder`
- Repositories own more cache and sync logic than a thinner data layer would
- The app gains fast pragmatic iteration at the cost of direct singleton imports and looser dependency boundaries

That tradeoff matches the current implementation: the app is centralized where consistency matters most, and lightweight everywhere else.
