# DaktarPai - State Management and Data Flow

## 1. State Management Pattern

DaktarPai uses:
- singleton `ChangeNotifier` instances for shared app state,
- `StatefulWidget`/`setState` for local screen and dialog state.

No external state framework is used.

## 2. Global Notifiers

### `SettingsNotifier`
File: `lib/features/settings/presentation/settings_notifier.dart`

Tracks persisted app settings such as:
- theme mode,
- inactivity timeout,
- notification preference,
- security toggles (biometric/2FA related),
- UI onboarding hints.

### `ProfileNotifier`
File: `lib/features/profile/presentation/profile_notifier.dart`

Owns profile-facing shared data consumed by shell/profile-related surfaces.

### `FavoritesNotifier`
File: `lib/features/doctors/presentation/favorites_notifier.dart`

Tracks favorite doctor ids and toggle/read helpers.

### `AppointmentNotifier`
File: `lib/features/appointments/presentation/appointment_notifier.dart`

Owns:
- appointment list state,
- pending review items,
- pending complaint items,
- combined `actionRequiredItems` projection,
- loading/error state,
- Supabase realtime channel lifecycle for appointments.

## 3. Lifecycle-Oriented Data Refresh

`MainWrapper` acts as lifecycle coordinator:
- initializes appointment realtime once,
- performs initial silent `fetchAppointments()` and `loadProfile()`,
- refreshes both again on `AppLifecycleState.resumed`.

## 4. Repository Data Flow Pattern

```text
Screen/Notifier -> Repository -> Supabase/API -> Repository result -> UI state update
```

Key repositories in active flows:
- `AuthRepository`
- `HomeRepository`
- `DoctorRepository`
- `RouteRepository`
- `AppointmentRepository`
- `MedicalRecordRepository`
- `ProfileRepository`
- `SettingsRepository`
- `TrustedDeviceRepository`
- `BookingDraftRepository`
- `AppointmentSecureCacheRepository`

## 5. Appointment Data Flows

### Booking flow
1. `PatientDetailsScreen` gathers patient details.
2. `AppointmentConfirmationScreen` validates and prepares booking payload.
3. `DummyPaymentScreen` finalizes booking and follow-up actions.

### My Appointments flow
- screen listens to `AppointmentNotifier`,
- notifier owns realtime and refresh behavior,
- UI supports action sheet operations and pull-to-refresh.

### Review and complaint flow
1. Pending item triggers review or complaint dialog.
2. Repository submit method executes.
3. Notifier removes handled pending item from in-memory queue.
4. Timeline/list refresh remains available through notifier fetch paths.

## 6. Caching and Refresh Semantics

- Appointment cache is stored via `AppointmentSecureCacheRepository`.
- Notifier loads cache first for perceived responsiveness, then overlays fresh network data.
- Manual refresh controls still force live fetch behavior in relevant feature screens.

## 7. Local UI State Patterns

Common local state idioms:
- `isLoading`/`isSubmitting` flags,
- `mounted` checks before UI updates,
- `StatefulBuilder` for dialog-local mutable state,
- try/catch + snackbar feedback,
- timer-based interaction state in specific screens.

## 8. Input State and Form Composition

Current input architecture:
- text entry is standardized on `AppTextField`,
- legacy wrappers (`AuthTextField`, `CustomTextField`) delegate to `AppTextField`,
- keyboard-sensitive dialog/sheet content uses scroll/inset-safe patterns.

This reduces layout inconsistency and keeps form behavior predictable across features.

## 9. Non-Notifier Services in Flows

- `AppointmentNotificationService`
- `ErrorTelemetryService`
- `DeviceIntegrityService`
- `BiometricAuthService`
- `SensitiveActionStepUpService`

These services complement notifier/repository flows without owning broad UI state.
