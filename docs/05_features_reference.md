# DaktarPai - Features Reference

This document reflects the current implementation, including simulated flows and local-only behaviors.

## 1. Splash, Auth, and Onboarding

Current auth-related behavior:

- `SplashScreen` resolves the first route after a short delay
- Login supports email/password and Google sign-in
- Sign-up supports email/password plus Google sign-in
- Forgot-password lives inside the login bottom sheet and uses an 8-digit recovery OTP flow
- `Verify2FAScreen` supports TOTP verification, backup-code recovery, and optional "remember this device" trust
- Post-auth routing can land on `/home`, `/verify-2fa`, or `/profile/edit`

New email sign-ups that immediately receive a session are pushed into profile completion. Existing users missing DOB metadata are also forced through profile setup.

## 2. Home and Doctor Discovery

`HomeScreen` currently loads:

- specialties
- popular doctors
- featured doctors
- banners

These queries are filtered by the signed-in profile's `countryIso` first, then by `location` when applicable.

Doctor discovery surfaces currently include:

- the doctors tab (`DoctorsScreen`)
- specialty doctor lists
- clinic doctor lists
- popular doctor list
- featured doctor list
- favorite doctors and recent visits in `MyDoctorsScreen`
- global search

`DoctorsScreen` supports five filter chips:

- `All`
- `Nearest`
- `Hospital`
- `Clinic`
- `Best Rated`

`Nearest` requests live GPS coordinates. `Hospital` and `Clinic` switch the screen into facility grids. The general doctor list remains rating-sorted.

## 3. Search and Doctor Details

`GlobalSearchScreen` is a progressive search flow:

- recent searches are stored in `SharedPreferences`
- local specialty matches appear first
- remote doctor and clinic hints are fetched as the user types
- submitting a search performs a heavier remote doctor search
- exact specialty-name matches route directly to the specialty screen

`DoctorDetailsScreen` currently provides:

- instant handoff rendering from list data when available
- a full doctor refresh in the background
- clinic list and per-clinic pricing/wait-time display
- per-day slot generation from doctor schedules
- live booked-slot filtering from the appointments table
- embedded map display with `flutter_map`
- in-app route drawing through `RouteRepository`
- external map handoff through `NavigationHelper`
- favorite toggling and delayed view-count tracking

## 4. Appointments and Booking

The appointment feature set currently includes:

- upcoming appointments list in `MyAppointmentsScreen`
- appointment realtime refresh through `AppointmentNotifier`
- cancel, complete, and reschedule flows
- pending review and complaint prompts
- account activity history backed by the shared appointment vault
- receipt dialog generation and receipt sharing
- add-to-calendar entry points

Current booking path:

1. `PatientDetailsScreen`
   Loads the signed-in profile, saved patient categories, and a secure draft keyed to doctor and clinic context.
2. `AppointmentConfirmationScreen`
   Loads schedules for the selected clinic and excludes already booked slots.
3. `DummyPaymentScreen`
   Simulates payment, then creates or updates the appointment.

Important current behavior:

- checkout is still simulated
- the checkout UI shows a fixed wallet/escrow summary rather than a real payment gateway
- booking confirmation can create immediate local notifications, scheduled reminders, and in-app inbox entries depending on settings

Reminder scheduling currently includes:

- immediate booking confirmation
- a configurable lead-time reminder
- a 5-hour pre-visit warning
- a post-visit timeout/status notification

## 5. Medical Records

Current medical-record behavior:

- list, add, edit, and soft-delete records
- attach one or more images or documents
- upload files to Supabase Storage before save
- open image and non-image attachments
- cache opened attachments locally for later reuse
- lock and unlock record visibility through a biometric gate

Important limitations:

- physical file upload is online-only
- signed URL generation is online-only
- metadata changes can queue offline, but first-time document access cannot

## 6. Profile

Current profile-related behavior:

- profile view and edit screens
- secure profile cache through `ProfileSecureCacheRepository`
- profile picture upload to the `profile_pictures` bucket
- GPS location lookup and reverse geocoding
- capture of `countryIso` and UTC offset
- saved-patient management used by booking

`ProfileRepository` queues profile writes and saved-patient mutations when offline.

## 7. Notifications

The notification inbox is local to the device and currently combines multiple sources:

- booking confirmations written by `DummyPaymentScreen`
- future in-app reminder entries scheduled at booking time
- foreground FCM messages handled by `FcmService`
- background FCM messages written through the top-level Firebase background handler

Inbox behavior:

- stored in Hive through `NotificationRepository`
- loaded on startup through `NotificationNotifier`
- supports mark-as-read, mark-all-read, and delete
- future-dated notifications stay hidden from the visible list and unread count until their timestamp passes

## 8. Settings, Account, and Linked Providers

Current settings/account surfaces include:

- two-factor authentication setup and removal
- trusted-device biometric login enable/disable
- notification preferences and global reminder lead time
- inactivity lock timeout, when biometric login is configured
- theme mode
- currency display derived from profile location
- menu drawer intro hint toggle
- linked account management for email/password and Google
- password change for accounts with an email provider
- account deletion flow

Note: medical-record locking is controlled from `MedicalRecordsScreen`, not from Settings.

## 9. Support and Legal

Current support/legal surfaces include:

- `HelpCenterScreen` with static searchable FAQ content from `faq_data.dart`
- support complaint submission through the shared `ComplaintDialog`
- `PrivacyPolicyScreen` with in-app policy copy
- `TermsOfServiceScreen` backed by `LegalText.termsOfService`

The `About App` tile is currently informational only and does not open a dedicated screen.
