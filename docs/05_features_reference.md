# DaktarPai - Features Reference

This document reflects the current source code, not planned behavior.

## 1. Splash and Auth

Current auth-related behavior:
- `SplashScreen` resolves the first route after a short delay.
- Login supports email/password and Google sign-in.
- Forgot-password is handled inside a bottom sheet and uses an 8-digit recovery OTP flow.
- `Verify2FAScreen` supports TOTP verification, backup-code recovery, and optional device trust.
- Post-auth routing can lead to `/home`, `/verify-2fa`, or `/profile/edit`.

## 2. Home

`HomeScreen` currently loads:
- specialties
- popular doctors
- featured doctors
- banners

The doctor and banner queries are filtered by the profile's `location` or `countryIso` when available.

## 3. Doctors and Search

Current doctor discovery features:
- all-doctors browsing in the doctors tab
- doctor details
- specialty doctor lists
- clinic doctor lists
- popular and featured doctor screens
- favorite doctors in `MyDoctorsScreen`
- global search with recent searches stored in `SharedPreferences`

`GlobalSearchScreen` behavior:
- local specialty hinting
- remote doctor and clinic hints
- full remote search after submit
- specialty exact-match redirect when the search text matches a specialty name

Favorites use optimistic UI through `FavoritesNotifier`.

## 4. Appointments

The current appointments feature set includes:
- appointment list in `MyAppointmentsScreen`
- appointment realtime refresh through `AppointmentNotifier`
- pending review and complaint tracking
- account activity history
- cancel and complete actions

Current booking flow:
1. `PatientDetailsScreen`
   Loads the signed-in profile, saved patients, and a secure booking draft tied to doctor and clinic context.
2. `AppointmentConfirmationScreen`
   Loads doctor schedules and live booked slots for the selected clinic and date.
3. `DummyPaymentScreen`
   Creates or updates the appointment, shows booking confirmation, writes a local inbox notification when enabled, and schedules device reminders from `SettingsNotifier`.

`DummyPaymentScreen` is still a simulated checkout screen. It writes the appointment after a delayed success path.

## 5. Medical Records

Current medical-record behavior:
- list, add, edit, and soft-delete records
- upload one or more files before saving a record
- open image and non-image attachments from signed URLs
- queue metadata changes offline through `MedicalRecordRepository`

Important limitation:
- physical file upload and signed URL access remain online-only

`MedicalRecordsScreen` also supports a persistent local lock state controlled through biometrics and `SettingsNotifier`.

## 6. Profile

Current profile-related behavior:
- profile view and edit screens
- secure profile cache through `ProfileSecureCacheRepository`
- profile picture upload to Supabase Storage
- saved-patient management used by the booking flow

`ProfileRepository` also queues profile updates and saved-patient mutations when offline.

## 7. Settings, Menu, and Account

Current settings and account surfaces include:
- theme mode
- notification preferences
- global reminder lead time
- inactivity lock timeout
- medical records protection toggle
- linked accounts
- account activity
- privacy policy
- terms of service
- help center

Currency is display-only and inferred from the loaded profile location data.

## 8. Notifications

The notification inbox is local to the device:
- stored in Hive through `NotificationRepository`
- loaded on startup through `NotificationNotifier`
- supports mark-as-read, mark-all-read, and delete

At the moment, the most direct write path is the appointment booking confirmation flow in `DummyPaymentScreen`.
