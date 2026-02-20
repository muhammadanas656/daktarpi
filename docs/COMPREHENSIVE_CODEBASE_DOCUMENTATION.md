# DaktarPi Comprehensive Codebase Documentation

Last updated: February 19, 2026

This document explains the current Flutter codebase end-to-end: architecture, runtime flow, routes, feature behavior, Supabase contract, shared UI/state patterns, platform integration, and current risks.

## 1. Product and System Scope

DaktarPi is a patient-facing mobile app for:
- account signup/login
- profile onboarding and editing
- doctor discovery and filtering
- doctor details with schedule and location map
- appointment booking and rescheduling
- medical records upload and retrieval
- security controls (2FA and recovery codes)
- settings, legal, and support screens

The frontend is a Flutter app, and backend services are consumed through Supabase (Auth, Postgres, Storage, Realtime, and RPC functions).

## 2. Technology Stack

Core dependencies (from `pubspec.yaml`):
- Flutter SDK
- `supabase_flutter` for auth/data/storage/realtime
- `go_router` for navigation
- `flutter_dotenv` for environment configuration
- `shared_preferences` for local settings persistence
- `geolocator` and `geocoding` for location features
- `flutter_map` and `latlong2` for embedded maps
- `google_sign_in` for Google auth
- `image_picker` and `file_picker` for media/document selection
- `url_launcher` for external maps/email flows
- `flutter_local_notifications` and `timezone` present as dependencies (not deeply wired in current flow)

## 3. Repository Structure

Primary app code lives in `lib/`.

Top-level app composition:
- `lib/main.dart` initializes environment and Supabase
- `lib/app.dart` configures `MaterialApp.router` with theme/localization/router
- `lib/core/router/app_router.dart` defines all routes
- `lib/core/main_wrapper/main_wrapper.dart` implements bottom tabs + custom animated drawer

Feature-first folder pattern:
- `lib/features/auth`
- `lib/features/home`
- `lib/features/doctors`
- `lib/features/appointments`
- `lib/features/medical_records`
- `lib/features/profile`
- `lib/features/menu`
- `lib/features/settings`
- `lib/features/support`
- `lib/features/legal`

Shared resources:
- `lib/presentation/widgets` for reusable UI components
- `lib/core/theme` for visual tokens and theme
- `lib/core/localization` for in-app string localization
- `lib/core/constants` for routes/legal constants

## 4. Application Bootstrap and Runtime Entry

Boot sequence:

1. `main()` in `lib/main.dart`
- calls `WidgetsFlutterBinding.ensureInitialized()`
- loads `.env`
- initializes Supabase with:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- runs `MyApp`

2. `MyApp` in `lib/app.dart`
- listens to `SettingsNotifier.instance` through `AnimatedBuilder`
- configures:
  - light/dark theme from `AppTheme`
  - locale from settings
  - localization delegates
  - router config from `appRouter`

3. Initial route
- router starts at `/` (splash)
- splash makes session/profile decision and redirects to login, profile edit, or home

## 5. Routing and Navigation Architecture

Routes are centralized in `lib/core/router/app_router.dart` and path constants in `lib/core/constants/app_routes.dart`.

### 5.1 Route Topology

The app has two navigation layers:
- root navigator routes (auth, modal-like feature pages, detail flows)
- shell route (`StatefulShellRoute.indexedStack`) for four bottom tabs

Bottom tabs:
- `/home`
- `/doctors`
- `/appointments`
- `/profile`

### 5.2 Route Catalog

Public/auth:
- `/` -> Splash
- `/login` -> Login
- `/signup` -> Sign Up
- `/verify-2fa` -> 2FA verification

Primary app tabs:
- `/home` -> Home tab
- `/doctors` -> Doctors tab
- `/appointments` -> My Appointments tab
- `/profile` -> Profile view tab
- `/profile/edit` -> Profile edit/setup (root navigator child route)

Doctors and discovery:
- `/popular_doctors`
- `/featured_doctors`
- `/doctor_details/:id`
- `/specialty_doctors/:id` (uses `state.extra` for name)
- `/clinic_doctors/:id` (uses `state.extra` for clinic name)
- `/my_doctors`

Appointments:
- `/appointment_booking` (patient details)
- `/payment_method` (appointment confirmation/reschedule)

Medical records:
- `/medical_records`
- `/add_medical_record` (optional `state.extra` for edit mode)

Settings/support/legal:
- `/settings`
- `/linked-accounts`
- `/help-center`
- `/privacy_policy`
- `/terms_of_service`

Utility:
- `/location_permission`

### 5.3 Main Wrapper Behavior

`lib/core/main_wrapper/main_wrapper.dart`:
- wraps tab shell in a 3-layer animated card/drawer effect
- custom left drawer with profile and navigation links
- horizontal gesture handling for:
  - drawer open/close on Home tab
  - tab switching via swipe
- custom back handling with `PopScope`:
  - closes drawer first if open
  - exits app via `SystemNavigator.pop()` on root tabs
  - otherwise pops current route
- bottom navigation bar with four destinations
- intro drawer hint animation controlled by `SettingsNotifier.showDrawerHint`

## 6. State Management Strategy

Pattern used:
- singleton `ChangeNotifier` classes for cross-screen state
- direct `setState` for screen-local state

Key global notifiers:
- `ProfileNotifier` (`lib/features/profile/presentation/profile_notifier.dart`)
  - holds current user profile and derived helpers (currency symbol)
- `FavoritesNotifier` (`lib/features/doctors/presentation/favorites_notifier.dart`)
  - holds favorite doctor id set and optimistic toggle behavior
- `AppointmentNotifier` (`lib/features/appointments/presentation/appointment_notifier.dart`)
  - holds confirmed appointments and loading/error state
- `SettingsNotifier` (`lib/features/settings/presentation/settings_notifier.dart`)
  - theme mode, locale, drawer hint preference via SharedPreferences

State observations:
- notifiers are listened to via `addListener` + `setState` in many screens
- there is no Provider/Riverpod/BLoC currently
- most screens combine global notifier state with local transient state

## 7. Supabase Backend Contract (Inferred from Code)

The code directly references the following tables, buckets, and RPCs.

### 7.1 Postgres Tables

Used tables:
- `profiles`
- `doctors`
- `specialties`
- `clinics`
- `doctor_clinics`
- `doctor_schedules`
- `favorite_doctors`
- `appointments`
- `medical_records`

Behavior expectations by table:

`profiles`:
- keyed by auth user id
- stores user personal data and avatar URL

`doctors`:
- doctor profile, ratings, pricing, specialty relation
- filtered by flags like `is_popular` and `is_featured`

`specialties`:
- id/name/icon data for specialty browsing

`clinics`:
- facility records with type (`hospital` or `clinic`) and location fields

`doctor_clinics`:
- many-to-many doctor-clinic relation and visit pricing metadata

`doctor_schedules`:
- schedule rows by doctor and optionally clinic with time window and slot duration

`favorite_doctors`:
- user-doctor favorites relation

`appointments`:
- appointment records with status, schedule date/time, patient fields, relations

`medical_records`:
- user-specific record metadata and file path array

### 7.2 Storage Buckets

Buckets referenced:
- `profile_pictures`
- `medical_docs`

Storage usage:
- profile picture uploads are public URL-based (`getPublicUrl`) with timestamp cache-busting
- medical docs are treated as private and accessed by signed URLs (`createSignedUrl`)

### 7.3 RPC Functions

RPCs called:
- `use_recovery_code`
- `user_has_recovery_codes`
- `save_recovery_codes`
- `delete_user_account`

Implication:
- backend contains custom security/account lifecycle logic outside Flutter code
- these functions are required for full settings/2FA/account deletion flows

### 7.4 Realtime

Channel:
- `public:appointments`

Filter:
- table `appointments`, `user_id = currentUserId`

Consumer:
- My Appointments screen refreshes list on any appointment row change

## 8. Feature Deep Dives

## 8.1 Splash and Session Gate

File: `lib/features/splash/presentation/screens/splash_screen.dart`

Flow:
- waits 2 seconds
- checks `Supabase.instance.client.auth.currentSession`
- if no session -> `/login`
- if session:
  - checks user metadata `dob`
  - missing `dob` -> `/profile/edit`
  - otherwise -> `/home`

Notes:
- splash intentionally does not force 2FA verification on every launch
- medical records flow applies additional 2FA gating for sensitive access

## 8.2 Authentication

### Login

File: `lib/features/auth/presentation/screens/login_screen.dart`

Capabilities:
- email/password login
- Google sign-in login
- forgot password (multi-step modal sheet)

Post-login routing:
- checks app metadata:
  - `is_2fa_enabled`
  - `aal`
- if 2FA enabled and session effectively AAL1 -> `/verify-2fa`
- else checks `dob` metadata:
  - missing -> `/profile/edit`
  - present -> `/home`

### Signup

File: `lib/features/auth/presentation/screens/signup_screen.dart`

Flow:
- validates name/email/password/terms
- creates user via Supabase auth signup
- stores `full_name` in auth metadata data payload
- if immediate session exists -> `/profile/edit`
- if email verification required -> success message then `/login`

### 2FA Verification

File: `lib/features/auth/presentation/screens/verify_2fa_screen.dart`

Modes:
- normal TOTP entry (6 digits)
- recovery code mode (backup code via RPC)

Operations:
- TOTP: `auth.mfa.challengeAndVerify(...)`
- recovery: `rpc('use_recovery_code', params: { input_code })`

Successful verification routes to `/home`.

### Forgot Password

Implemented inside login screen as modal:
- Step 1: email input + reset request
- Step 2: OTP entry and verification
- Step 3: update password

Supabase methods used:
- `resetPasswordForEmail`
- `verifyOTP` with `OtpType.recovery`
- `updateUser(UserAttributes(password: ...))`

## 8.3 Profile Setup and Profile View

### Profile Edit/Setup

File: `lib/features/profile/presentation/screens/profile_screen.dart`

Responsibilities:
- initial profile load from `profiles`
- avatar selection and upload
- required field enforcement:
  - full name
  - contact number
  - date of birth
  - location
- GPS-assisted location set
- profile persistence to `profiles`
- metadata sync to auth (`full_name`, `dob`)

Back behavior:
- during first-time setup (missing required fields), back action signs user out and sends to login
- when editing existing profile, back returns normally

### Profile View

File: `lib/features/profile/presentation/screens/profileview_screen.dart`

Read-only profile card:
- avatar, name, phone, DOB, location
- edit action navigates to `/profile/edit`

No logout action on this screen (removed).

## 8.4 Home Dashboard

File: `lib/features/home/presentation/screens/home_screen.dart`

Loads:
- profile notifier
- favorites notifier
- specialty list
- popular doctors
- featured doctors

Main UI blocks:
- personalized greeting header
- search bar (navigates to popular doctors list)
- specialty chips
- popular doctor horizontal list
- featured doctor horizontal list

Refresh:
- pull-to-refresh style through internal `_refreshData()` calls and refresh after returning from detail/list screens

## 8.5 Doctors Discovery and Details

### Doctors Tab

File: `lib/features/doctors/presentation/screens/doctors_screen.dart`

Capabilities:
- free text search
- filter chips:
  - All
  - Nearest
  - Hospital
  - Clinic
  - Best Rated
- doctor list with favorite toggling
- hospital/clinic grid views and navigation into clinic-specific doctor list

Nearest behavior:
- requests location permission/services if needed
- fetches doctors and sorts by computed minimum clinic distance

### Popular/Featured/Specialty/Clinic Lists

Files:
- `popular_doctors_screen.dart`
- `featured_doctors_screen.dart`
- `specialty_doctors_screen.dart`
- `clinic_doctors_screen.dart`

Common pattern:
- search with debounce
- list cards with favorite icon and navigation to detail
- repository query specific to list context

### My Doctors

File: `lib/features/doctors/presentation/screens/my_doctors_screen.dart`

Tabs:
- Favorites (from `favorite_doctors`)
- Recent Visits (derived from completed appointments)

Uses `DoctorListCard` with tab-specific trailing behavior.

### Doctor Details

File: `lib/features/doctors/presentation/screens/doctor_details_screen.dart`

High-value feature screen with:
- doctor summary and stats
- favorite toggle
- clinic selector
- schedule rendering
- generated available slots per selected date/clinic
- map visualization of clinic/user/route
- external navigation launch
- in-app route polyline via OSRM API
- booking initiation to patient details screen

Data loaded in stages:
1. doctor details first (to render early)
2. clinics + schedules + favorite status in parallel
3. booked slots for selected date/clinic

Booking handoff payload includes:
- doctor
- selected clinic
- selected date
- selected time slot (optional at this stage)

## 8.6 Appointments

### Step 1: Patient Details

File: `lib/features/appointments/presentation/screens/patient_details_screen.dart`

Collects:
- patient name, phone, email
- DOB (day/month/year)
- gender
- patient type (self, child, custom relation)
- optional patient image (non-self modes)

Then pushes `/payment_method` with doctor/clinic/patient details/date/time data.

### Step 2: Appointment Confirmation / Reschedule

File: `lib/features/appointments/presentation/screens/appointment_confirmation_screen.dart`

Behavior:
- loads doctor schedule filtered by clinic
- loads booked slots for selected date
- allows selecting a free slot and reminder minutes
- creates new appointment OR updates existing appointment

Write operation:
- inserts/updates `appointments` with status `confirmed`

Success:
- shows success dialog and routes to `/appointments` with refresh extra

### My Appointments

File: `lib/features/appointments/presentation/screens/my_appointments_screen.dart`

Displays:
- confirmed upcoming appointments from notifier

Actions:
- reschedule (re-enter confirmation screen with existing appointment id)
- mark complete (status update)
- cancel (status update)

Realtime:
- subscribes to appointments changes by user id and refetches on change

## 8.7 Medical Records

### Records List

File: `lib/features/medical_records/presentation/screens/medical_records_screen.dart`

Loads user records via repository.

2FA gate:
- if repository throws `Requires2FAException`, user sees verification-required dialog and can route to `/verify-2fa`

Capabilities:
- add record
- edit record
- delete record + associated files
- open attached files

Attachment view:
- images open in-app dialog
- docs download to temp then open in native app

### Add/Edit Record

File: `lib/features/medical_records/presentation/screens/add_record_screen.dart`

Supports:
- record metadata form
- selecting images (camera/gallery)
- selecting docs (pdf/doc/docx)
- keeping existing attachments in edit mode
- uploading new files and combining final path list
- add/update `medical_records` row

## 8.8 Settings, Security, and Account Management

File: `lib/features/menu/presentation/screens/settings_screen.dart`

Sections:
- Account & Security
- Preferences
- Support & Legal

Security features:
- change password dialog
- link/unlink accounts screen
- 2FA toggle:
  - enroll TOTP factor
  - QR and secret display
  - challenge + verify code
  - disable by unenroll
- recovery codes generation/regeneration
- account deletion flow (storage cleanup + RPC + signout)

Preferences:
- language selection
- theme mode selection
- currency display (derived from profile location)
- drawer hint toggle

## 8.9 Linked Accounts

File: `lib/features/menu/presentation/screens/linked_accounts_screen.dart`

Current behavior:
- lists current auth identities
- can link Google identity
- can unlink non-email linked provider identities

## 8.10 Support and Legal

Help center:
- `lib/features/support/presentation/screens/help_center_screen.dart`
- FAQ search and expandable answers
- contact support via email intent

Privacy policy:
- `lib/features/menu/presentation/screens/privacy_policy_screen.dart`

Terms of service:
- `lib/features/legal/presentation/screens/terms_of_service_screen.dart`
- content source in `lib/core/constants/legal_text.dart`

## 9. Reusable UI Components

Shared widgets in `lib/presentation/widgets` and feature widget folders:
- buttons: `primary_button.dart`, `social_button.dart`
- inputs: `auth_text_field.dart`, `app_text_field.dart`, `custom_search_bar.dart`
- cards: doctor cards, appointment card, record card
- feedback: `custom_snackbar.dart`
- doctor detail composition widgets in `lib/features/doctors/presentation/widgets`

Design pattern:
- screens compose many shared widgets
- styling mostly centralized in `AppColors`, `AppTextStyles`, and `AppStyles`

## 10. Theming and Localization

Theme:
- `lib/core/theme/app_theme.dart`
- Google Fonts Poppins text theme
- light and dark `ThemeData`

Color/text tokens:
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_styles.dart`

Localization:
- `lib/core/localization/app_localizations.dart`
- static map-based localization (no codegen ARB)
- explicitly supported locales in app config:
  - `en_US`
  - `bn_BD`

## 11. Permissions and Platform Integration

Android manifest (`android/app/src/main/AndroidManifest.xml`):
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`

iOS plist (`ios/Runner/Info.plist`):
- location usage descriptions for in-use and always

External integrations:
- map tile usage through `flutter_map` + Carto tile URL
- OSRM routing endpoint via HTTP
- email/map launching via `url_launcher`

## 12. Error Handling and User Feedback

User feedback methods:
- `CustomSnackbar` for most app messages
- dialogs and bottom sheets for confirmation/critical flows
- loading indicators on async operations

Patterns:
- many repository methods throw `Exception(...)` with wrapped error text
- screens generally catch and present user-facing messages
- not all errors are normalized; message style differs per feature

## 13. Caching, Realtime, and Performance Notes

Caching in `DoctorRepository`:
- specialties, popular doctors, featured doctors
- 5-minute in-memory cache
- optional `forceRefresh` bypass

Realtime:
- appointments list updates via Supabase Realtime subscription

Screen performance:
- heavy detail screens rely on staged loading
- map and route rendering can be network/location intensive

## 14. Current Constraints and Technical Debt

Observed gaps and risks from current code:

1. Data access is partially duplicated
- repositories exist, but several screens still call Supabase directly

2. Some utility/repository files are currently underused
- `lib/features/auth/data/auth_repository.dart`
- `lib/features/home/data/home_repository.dart`
- `lib/data/services/user_service.dart`
- `lib/core/utils/auth_lib.dart`

3. Localization mismatch
- settings shows extra languages (`es`, `fr`, `hi`, `ar`) but app only supports `en` and `bn` delegates/routes

4. Linked-account deep link assumptions
- linked account flow uses a custom redirect URI string; platform deep-link wiring should be verified end-to-end

5. Routing HTTP endpoint
- OSRM route fetch uses plain HTTP; some environments may restrict or alter behavior

6. Signup social button in sign-up screen
- Google button exists in UI with empty handler in sign-up screen

7. Testing baseline is not aligned with app
- `test/widget_test.dart` remains default counter test

8. Supabase migration/versioning artifacts
- `supabase/` folder currently has no checked-in migration files in this repository snapshot

## 15. Developer Setup and Local Run

Prerequisites:
- Flutter SDK compatible with project SDK constraints
- Android Studio/Xcode toolchains as needed
- valid `.env` with:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `GOOGLE_WEB_CLIENT_ID` (for Google sign-in path)

Suggested local commands:
- `flutter pub get`
- `flutter analyze`
- `flutter run`

Build metadata:
- app version: `1.0.0+1` in `pubspec.yaml`

## 16. Testing Status and Recommendations

Current test status:
- only default widget test present (`test/widget_test.dart`) and not representative of real app behavior

Recommended test priorities:
1. Auth routing logic (session + metadata + 2FA branches)
2. Profile completion and mandatory field enforcement
3. Appointment slot generation and booking/reschedule writes
4. Medical record 2FA gate and file upload/view flows
5. Settings 2FA enrollment/disable/recovery code flows
6. Route-level smoke tests for all `AppRoutes` paths

## 17. Practical Feature Extension Guide

When adding a new feature:

1. Define route constant in `lib/core/constants/app_routes.dart`
2. Register route in `lib/core/router/app_router.dart`
3. Add feature module:
- `data/` model + repository
- `presentation/` screens/widgets/notifier as needed
4. Add Supabase access in repository first, then keep screen logic thin
5. Reuse shared components from `lib/presentation/widgets`
6. Update this documentation with:
- new route
- new table/bucket/RPC dependencies
- new flow description

## 18. Troubleshooting Quick Reference

Login loops to profile edit:
- verify auth metadata `dob` and profile setup completion path

2FA prompt appears unexpectedly:
- inspect `app_metadata.is_2fa_enabled` and factor enrollment state

No slots shown in booking:
- verify `doctor_schedules` rows for selected day and clinic
- check booked-slot collisions and time filtering

Medical files fail to open:
- verify storage bucket policy/signing
- verify file type and native app association

Nearest filter fails:
- verify device location services and permission status

## 19. Critical File Index

App composition:
- `lib/main.dart`
- `lib/app.dart`
- `lib/core/router/app_router.dart`
- `lib/core/main_wrapper/main_wrapper.dart`

Auth:
- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/auth/presentation/screens/signup_screen.dart`
- `lib/features/auth/presentation/screens/verify_2fa_screen.dart`
- `lib/features/splash/presentation/screens/splash_screen.dart`

Profile:
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/presentation/screens/profileview_screen.dart`
- `lib/features/profile/presentation/profile_notifier.dart`
- `lib/features/profile/data/profile_repository.dart`

Doctors:
- `lib/features/home/presentation/screens/home_screen.dart`
- `lib/features/doctors/presentation/screens/doctors_screen.dart`
- `lib/features/doctors/presentation/screens/doctor_details_screen.dart`
- `lib/features/doctors/data/doctor_repository.dart`
- `lib/features/doctors/presentation/favorites_notifier.dart`

Appointments:
- `lib/features/appointments/presentation/screens/patient_details_screen.dart`
- `lib/features/appointments/presentation/screens/appointment_confirmation_screen.dart`
- `lib/features/appointments/presentation/screens/my_appointments_screen.dart`
- `lib/features/appointments/data/appointment_repository.dart`
- `lib/features/appointments/presentation/appointment_notifier.dart`

Medical records:
- `lib/features/medical_records/presentation/screens/medical_records_screen.dart`
- `lib/features/medical_records/presentation/screens/add_record_screen.dart`
- `lib/features/medical_records/data/medical_record_repository.dart`

Settings/menu/support/legal:
- `lib/features/menu/presentation/screens/settings_screen.dart`
- `lib/features/menu/presentation/widgets/custom_drawer.dart`
- `lib/features/menu/presentation/screens/linked_accounts_screen.dart`
- `lib/features/support/presentation/screens/help_center_screen.dart`
- `lib/features/menu/presentation/screens/privacy_policy_screen.dart`
- `lib/features/legal/presentation/screens/terms_of_service_screen.dart`

Theme/localization/constants:
- `lib/core/theme/app_theme.dart`
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/localization/app_localizations.dart`
- `lib/core/constants/app_routes.dart`
- `lib/core/constants/legal_text.dart`

