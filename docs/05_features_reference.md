# DaktarPai - Features Reference

This document summarizes active feature modules and current source behavior.

## 1. Splash

- `features/splash/presentation/screens/splash_screen.dart`
- Resolves initial route after auth-state checks.

## 2. Auth

Key files:
- `features/auth/data/auth_repository.dart`
- `features/auth/data/auth_entry_route_service.dart`
- `features/auth/data/auth_route_resolver.dart`
- `features/auth/data/security_gate_service.dart`
- `features/auth/data/trusted_device_repository.dart`
- `features/auth/presentation/screens/login_screen.dart`
- `features/auth/presentation/screens/signup_screen.dart`
- `features/auth/presentation/screens/verify_2fa_screen.dart`

Behavior:
- email/password + Google sign-in
- MFA and recovery code verification
- step-up-aware post-auth routing

## 3. Home

Main files:
- `features/home/presentation/screens/home_screen.dart`
- `features/home/presentation/widgets/home_header.dart`
- `features/home/presentation/widgets/home_banner.dart`
- `features/home/presentation/widgets/home_specialties_row.dart`
- `features/home/presentation/widgets/home_section_header.dart`

Behavior:
- pull-to-refresh supported
- manual refresh paths call doctor repository with `forceRefresh: true` to bypass short-lived in-memory caches

## 4. Doctors

Screens:
- `doctors_screen.dart`
- `doctor_details_screen.dart`
- `popular_doctors_screen.dart`
- `featured_doctors_screen.dart`
- `specialty_doctors_screen.dart`
- `clinic_doctors_screen.dart`
- `my_doctors_screen.dart`

Widgets:
- `doctor_details_header.dart`
- `doctor_stats_row.dart`
- `doctor_appointment_card.dart`
- `doctor_timing_list.dart`
- `clinic_location_map_section.dart`

Data:
- `doctor_repository.dart`
- `route_repository.dart`

Current behavior highlights:
- doctor view counting via delayed timer + `incrementDoctorViewCount()`
- smart analytics RPC `increment_doctor_views_smart` requires authenticated user
- doctor detail screen supports pull-to-refresh
- map/navigation logic is modularized inside `ClinicLocationMapSection`
- route fetching uses OSRM direct call with `route-proxy` edge-function fallback
- Clinic wait times are stored as integer `min_wait_time` and `max_wait_time` in the database, but synthesized into a display string (e.g., "20-30 mins") inside repository to decouple UI from backend calculations.

## 5. Appointments

### Data layer

- `appointment.dart`
- `appointment_repository.dart`
- `booking_draft_repository.dart`
- `appointment_secure_cache_repository.dart`

Current repository capabilities:
- load active appointments
- cancel and complete mutations
- submit review (`submitReview`)
- fetch pending review candidates (`fetchPendingReviews`)
- fetch activity log with review-state flag (`fetchActivityLog` adds `has_review`)
- submit complaint (`submitComplaint`)
- fetch pending complaint candidates (`fetchPendingComplaints`)

Cancellation and transition behavior:
- cancellation failures are mapped to `AppFailure` with user-safe fallback messages
- Database utilizes highly precise `pg_cron` jobs (running every 5 mins) to automatically transition expired confirmed appointments to `waiting` (based on clinic max wait time) and then to `missed` (after a 15-minute grace period).

### Presentation and state

- `patient_details_screen.dart`
- `appointment_confirmation_screen.dart`
- `dummy_payment_screen.dart`
- `my_appointments_screen.dart`
- `appointment_notifier.dart`
- `booking_route_args.dart`

State behavior:
- `AppointmentNotifier` is singleton owner of appointment realtime subscription
- notifier listens to auth-state changes and refreshes/resubscribes accordingly
- notifier combines pending reviews and complaints into a single `actionRequiredItems` getter for the UI carousel
- Appointment booking dynamically schedules local time-out notifications precisely synced with the clinic's `max_wait_time` + 15m grace period. This scheduling is strictly gated by `SettingsNotifier.instance.notificationsEnabled`.

UX behavior:
- step 3 success dialog supports add-to-calendar
- My Appointments action sheet supports add-to-calendar, reschedule, complete, cancel
- pending review carousel is rendered from notifier state
- list supports pull-to-refresh in empty/non-empty states

## 6. Medical Records

- `medical_record_repository.dart`
- `medical_records_screen.dart`
- `add_record_screen.dart`

Behavior:
- security-gated record access
- record CRUD with file support

## 7. Profile

- `profile_repository.dart`
- `profile_notifier.dart`
- `profile_screen.dart`
- `profileview_screen.dart`

Behavior:
- view/edit profile
- country/currency-aware profile display
- saved patient profiles

## 8. Menu and Settings

Screens:
- `settings_screen.dart`
- `account_activity_screen.dart`
- `privacy_policy_screen.dart`
- `linked_accounts_screen.dart`

Widgets:
- `settings_account_security_section.dart`
- `settings_preferences_section.dart`
- `settings_support_legal_section.dart`
- `review_dialog.dart`

Current behavior:
- Account Activity is accessible from settings section tile
- Account Activity supports review submission via reusable dialog
- review CTA only renders for completed activities without `has_review`
- Account Activity natively handles the automated `WAITING` status, displaying a contextual "running behind schedule" banner to prevent user confusion during the 15-minute grace period.
- Account Activity supports complaint submission via `ComplaintDialog` with dynamic routing to either Platform Support or the specific Doctor

## 9. Support and Legal

- `help_center_screen.dart`
- `terms_of_service_screen.dart`
- `legal_text.dart`

## 10. Common

- `enable_location_screen.dart`

## 11. Core Services Used Across Features

- `appointment_notification_service.dart`
- `error_telemetry_service.dart`
- security services under `core/security/`
