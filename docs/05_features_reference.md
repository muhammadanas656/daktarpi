# DaktarPai - Features Reference

This document maps active feature modules to current behavior in source.

## 1. Splash

Key file:
- `features/splash/presentation/screens/splash_screen.dart`

Behavior:
- resolves initial route via auth entry logic.

## 2. Auth

Key files:
- `features/auth/data/auth_repository.dart`
- `features/auth/data/auth_entry_route_service.dart`
- `features/auth/data/security_gate_service.dart`
- `features/auth/presentation/screens/login_screen.dart`
- `features/auth/presentation/screens/signup_screen.dart`
- `features/auth/presentation/screens/verify_2fa_screen.dart`

Behavior:
- email/password and Google sign-in,
- MFA verify and backup-code recovery,
- post-auth route resolution,
- forgot-password modal flow.

## 3. Home

Key files:
- `features/home/presentation/screens/home_screen.dart`
- `features/home/data/home_repository.dart`
- `features/home/presentation/widgets/*`

Behavior:
- doctor discovery sections and quick navigation,
- refreshable home data composition.

## 4. Doctors

Screens:
- `doctors_screen.dart`
- `global_search_screen.dart`
- `doctor_details_screen.dart`
- `popular_doctors_screen.dart`
- `featured_doctors_screen.dart`
- `specialty_doctors_screen.dart`
- `clinic_doctors_screen.dart`
- `my_doctors_screen.dart`

Data layer:
- `doctor_repository.dart`
- `route_repository.dart`

Behavior highlights:
- categorized global search,
- doctor detail analytics increment flow,
- modular clinic/map/navigation section,
- route fetch with OSRM + edge-function fallback,
- nearest-first sorting when coordinates are available (`get_nearby_doctors` RPC with client-side Haversine fallback),
- global search/live server-dependent fetches gated behind active network checks.

## 5. Appointments

Data layer:
- `appointment_repository.dart`
- `appointment_secure_cache_repository.dart`
- `booking_draft_repository.dart`

Presentation/state:
- `patient_details_screen.dart`
- `appointment_confirmation_screen.dart`
- `dummy_payment_screen.dart`
- `my_appointments_screen.dart`
- `appointment_notifier.dart`

Behavior highlights:
- booking is a multi-step flow,
- realtime appointment sync is owned by `AppointmentNotifier`,
- pull-to-refresh + action sheet controls,
- Action Required carousel combines pending review and complaint items,
- review submission dialogs now use `AppTextField` and keyboard-safe layout composition,
- offline write actions are queued in local storage and replayed automatically on reconnect via `NetworkNotifier`.

## 6. Medical Records

Key files:
- `medical_records_screen.dart`
- `add_record_screen.dart`
- `medical_record_repository.dart`

Behavior:
- record list and add/edit flows,
- attachment upload support,
- record-for input now standardized on `AppTextField`,
- Hive-backed record caching and dedicated offline queue (`medical_offline_queue`),
- signed URL and physical upload operations are online-only with `AppFailureType.network` fallback.

## 7. Profile

Key files:
- `profile_screen.dart`
- `profileview_screen.dart`
- `profile_repository.dart`
- `profile_notifier.dart`

Behavior:
- profile display/edit,
- saved patient relations,
- location/timezone-related profile persistence,
- Hive-backed profile/saved-patient caching and dedicated offline queue (`profile_offline_queue`),
- profile image upload is online-only and safely blocked while offline.

## 8. Menu and Settings

Screens:
- `settings_screen.dart`
- `linked_accounts_screen.dart`
- `account_activity_screen.dart`
- `privacy_policy_screen.dart`

Widgets:
- `review_dialog.dart`
- `complaint_dialog.dart`
- settings section widgets

Behavior:
- account/security operations with step-up checks,
- linked account management (Google/email),
- account activity timeline with review/complaint actions.

## 9. Support and Legal

Support:
- `help_center_screen.dart`

Legal:
- `terms_of_service_screen.dart`
- legal constants/text modules

Behavior:
- help center FAQ search now uses standardized `AppTextField`.

## 10. Common/Infrastructure-Adjacent Feature

- `enable_location_screen.dart` for location permission onboarding.

## 11. Shared Cross-Feature Services

- `appointment_notification_service.dart`
- `error_telemetry_service.dart`
- security services under `core/security/`
- offline/inactivity guards applied at app builder level (`app.dart`),
- `NetworkNotifier` global connectivity observer and offline-queue replay coordinator
