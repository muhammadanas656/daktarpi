# DaktarPi - Source of Truth: Structure, Runtime, and Functional Map

This document is the repository-level source of truth for:
- the current app/workspace structure
- the bootstrap and runtime spine
- the route table and shell navigation model
- shared state ownership, persistence, and background services
- feature ownership by directory
- backend, asset, test, platform, and helper-script surfaces

It is intended to answer both of these questions in one place:
1. Where does this code live right now?
2. Which part of the app currently owns this behavior?

Last reconciled: May 4, 2026.

Ground rules for this file:
- The structure snapshot is based on the current on-disk workspace, not only git-tracked files.
- Empty placeholder directories are included when they currently exist in the repo, such as `assets/fonts/`, `lib/services/`, `supabase/functions/delete-user/`, and `supabase/snippets/`.
- Transient local/build artifacts are intentionally excluded: `.git/`, `.dart_tool/`, `build/`, `.idea/`, `.env`, `.flutter-plugins*`, `*.iml`, `local.properties`, Android Gradle/CMake intermediates such as `android/.gradle/` and `android/app/.cxx/`, platform `Flutter/ephemeral/` folders, Flutter crash/analyzer log files, and generated Flutter screenshot dumps.
- Generated platform files currently present under Flutter runner folders are included when they participate in the current build surface.
- Root-level helper, patch, recovery, and diagnostic artifacts currently kept in the workspace are included because they are part of the practical codebase context today.

## 1. Runtime Spine

The live runtime path through the app is:

1. `lib/main.dart`
   - Ensures Flutter binding and preserves the native splash.
   - Loads `.env`.
   - Initializes Firebase, Hive, and Supabase in parallel.
   - Registers the top-level FCM background handler.
   - Runs device-integrity enforcement before the routed app starts.
   - Registers global Flutter, platform, zone, and error-widget telemetry.
   - Starts either the normal routed app (`MyApp`) or the security fallback (`_CompromisedDeviceApp`).
2. Deferred startup inside `lib/main.dart`
   - Loads `SettingsNotifier` and `NotificationNotifier`.
   - When the user already has a session, prefetches profile, favorites, specialties, featured/popular doctors, banners, and warms image textures during splash.
   - Starts local appointment reminders through `AppointmentNotificationService`.
   - Starts connectivity/offline sync through `NetworkNotifier`.
   - Initializes FCM for the current session and again on later auth changes.
3. `lib/app.dart`
   - Builds `MaterialApp.router`.
   - Applies light/dark theme from `SettingsNotifier`.
   - Applies localization delegates and the current supported locales (`en_US` and `bn_BD`).
   - Injects global bouncy scrolling physics inline.
   - Wraps the routed app with `OfflineModeGuard` and `InactivityLockGuard`.
4. `lib/core/router/app_router.dart`
   - Owns the root `GoRouter`.
   - Uses `/splash` as the initial location.
   - Enforces auth redirects to `/login?from=...`.
   - Hosts root-level detail/settings/support/legal routes above the shell.
   - Defines the 4-branch `StatefulShellRoute`.
   - Centralizes notification payload navigation through `handleNotificationTap`.
5. `lib/core/main_wrapper/main_wrapper.dart`
   - Hosts the shell UI.
   - Owns the animated drawer, gesture-driven branch switching, and floating dock.
   - Hydrates appointments and profile state after shell mount.
   - Starts appointment realtime subscriptions.
   - Performs silent refreshes on app resume.

The app currently uses singleton `ChangeNotifier` instances imported directly where needed. It does not currently use Provider, Riverpod, BLoC, or a dependency-injection container.

## 2. Navigation Model

### 2.1 Global Routing Rules

- Initial location is `/splash`.
- The splash screen is allowed to load without auth redirect.
- Unauthenticated users are redirected to `/login`, with the intended destination preserved in the `from` query parameter.
- Settings, notifications, booking flows, doctor detail flows, medical records, and support/legal screens are pushed on the root navigator above the shell.
- Notification payload routing is centralized in `handleNotificationTap`.
  - `appointment:*` payloads switch the user to the appointments tab.
  - Other payloads fall back to the notifications inbox.

### 2.2 Public and Auth Routes

| Path | Screen / Owner | Purpose |
|---|---|---|
| `/splash` | `SplashScreen` | Initial splash entrypoint while auth/routing settles |
| `/login` | `LoginScreen` | Login screen; accepts `from` query parameter |
| `/signup` | `SignUpScreen` | Account creation |
| `/verify-2fa` | `Verify2FAScreen` | Second-factor verification during auth/security flows |

### 2.3 Root-Level App Routes Above the Shell

| Path | Screen / Owner | Purpose |
|---|---|---|
| `/privacy_policy` | `PrivacyPolicyScreen` | Privacy/legal content |
| `/settings` | `SettingsScreen` | Settings hub |
| `/linked-accounts` | `LinkedAccountsScreen` | Linked identity providers/accounts |
| `/help-center` | `HelpCenterScreen` | Support and FAQ |
| `/terms_of_service` | `TermsOfServiceScreen` | Terms/legal content |
| `/location_permission` | `EnableLocationScreen` | Location permission onboarding |
| `/account_activity` | `AccountActivityScreen` | Security/account activity feed |
| `/notifications` | `NotificationsScreen` | Notification inbox |
| `/global_search` | `GlobalSearchScreen` | Global doctor search |
| `/popular_doctors` | `PopularDoctorsScreen` | Expanded popular-doctors list |
| `/featured_doctors` | `FeaturedDoctorsScreen` | Expanded featured-doctors list |
| `/doctor_details/:id` | `DoctorDetailsScreen` | Doctor detail screen and booking entry |
| `/appointment_booking` | `PatientDetailsScreen` | Booking step for patient details |
| `/payment_method` | `AppointmentConfirmationScreen` | Booking confirmation/payment step |
| `/dummy_payment` | `DummyPaymentScreen` | Payment simulation screen |
| `/specialty_doctors/:id` | `SpecialtyDoctorsScreen` | Specialty roster |
| `/clinic_doctors/:id` | `ClinicDoctorsScreen` | Clinic/facility roster |
| `/my_doctors` | `MyDoctorsScreen` | Favorite and recent doctors surface |
| `/medical_records` | `MedicalRecordsScreen` | Medical records index |
| `/add_medical_record` | `AddRecordScreen` | Record create/edit |

### 2.4 Shell Branches

The shell is implemented with `StatefulShellRoute.indexedStack` and wrapped by `MainWrapper`.

| Branch | Route | Screen | Notes |
|---|---|---|---|
| 0 | `/home` | `HomeScreen` | Home dashboard |
| 1 | `/doctors` | `DoctorsScreen` | Doctor discovery hub |
| 2 | `/appointments` | `MyAppointmentsScreen` | Appointments, pending actions, and history |
| 3 | `/profile` | `ProfileViewScreen` | Profile view root |

Nested under the profile branch:

| Route | Screen | Notes |
|---|---|---|
| `/profile/edit` | `ProfileScreen` | Editable profile screen pushed via the root navigator |

### 2.5 Navigation Helpers

`lib/core/constants/app_routes.dart` is the canonical path registry. It also exposes helpers for parameterized routes:
- `doctorDetailsById`
- `specialtyDoctorsById`
- `clinicDoctorsById`

## 3. Shared State, Persistence, and Background Services

### 3.1 Singleton State Owners

| State owner | Main responsibility | Backing persistence |
|---|---|---|
| `SettingsNotifier` | Theme mode, inactivity timeout, medical-record lock, biometric/2FA state, notification preferences, and drawer-hint visibility | `SharedPreferences` |
| `ProfileNotifier` | Current signed-in profile, hydration, and convenience accessors | `ProfileSecureCacheRepository` plus `ProfileRepository` |
| `AppointmentNotifier` | Appointments, pending reviews, pending complaints, booking mutations, activity log, and realtime refresh | `AppointmentSecureCacheRepository` plus `AppointmentRepository` |
| `DoctorsNotifier` | Shared specialties, popular doctors, featured doctors, home-feed doctor caches, and loading/error state | RAM-first, backed by `DoctorRepository` |
| `FavoritesNotifier` | Favorite doctor IDs and hydrated favorite doctor data with optimistic updates | RAM plus `DoctorRepository` local storage/sync |
| `NotificationNotifier` | Notification inbox, unread calculations, dedup, local-first cache, and sync behavior | `NotificationRepository` with Hive plus remote sync |
| `NetworkNotifier` | Online/offline status, sync barrier, and replay coordination for offline queues | Runtime only |

`HomeRepository` is currently a repository/composition layer used by the home surface. It is not a separate singleton state owner.

### 3.2 Background and Infra Services

| Service | Current role |
|---|---|
| `AppointmentNotificationService` | Schedules, cancels, and manages local appointment reminders |
| `FcmService` | FCM initialization and foreground push integration |
| `ErrorTelemetryService` | Sends Flutter/platform/zone errors to backend telemetry |
| `DeviceIntegrityService` | Startup device-integrity enforcement |
| `SensitiveActionStepUpService` | Step-up verification for security-sensitive actions |
| `BiometricAuthService` / `BiometricSecurityService` / `BiometricHelperService` | Biometric capability checks and authentication |

### 3.3 Offline and Sync Behavior

Offline queue replay is currently coordinated by `NetworkNotifier` and dispatched to:
- `AppointmentRepository`
- `ProfileRepository`
- `MedicalRecordRepository`
- `DoctorRepository`

Other notable sync/runtime behavior:
- Appointment realtime is established through `AppointmentNotifier`.
- Notifications refresh on resume and periodically in-process.
- Splash-time startup prefetch warms the home/profile/favorites surfaces before the shell appears.
- Profile and appointment data are silently refreshed on app resume from `MainWrapper`.

## 4. Feature Ownership by Directory

### 4.1 `lib/features/appointments/`

Current ownership:
- appointment models and serialization
- remote appointment fetch/mutation
- secure appointment caching
- booking-draft persistence
- appointment screens and booking flow
- pending review/complaint surfaces
- appointment realtime refresh

Directory contents:
- `data/`
  - `appointment.dart`, `appointment.freezed.dart`, `appointment.g.dart`
  - `appointment_repository.dart`
  - `appointment_secure_cache_repository.dart`
  - `booking_draft_repository.dart`
- `presentation/`
  - `appointment_notifier.dart`
  - `models/booking_route_args.dart`
  - `screens/appointment_confirmation_screen.dart`
  - `screens/dummy_payment_screen.dart`
  - `screens/my_appointments_screen.dart`
  - `screens/patient_details_screen.dart`
  - `widgets/live_countdown_badge.dart`

### 4.2 `lib/features/auth/`

Current ownership:
- login/signup
- Google sign-in entrypoints
- 2FA verification
- auth route resolution
- security gating
- trusted device management

Directory contents:
- `data/`
  - `auth_entry_route_service.dart`
  - `auth_repository.dart`
  - `auth_route_resolver.dart`
  - `security_gate_service.dart`
  - `trusted_device_repository.dart`
  - `trusted_device_service.dart`
- `presentation/`
  - `models/verify_2fa_route_args.dart`
  - `screens/login_screen.dart`
  - `screens/signup_screen.dart`
  - `screens/verify_2fa_screen.dart`

### 4.3 `lib/features/common/`

Current ownership:
- non-domain one-off shared screen(s)
- location permission onboarding

Directory contents:
- `presentation/screens/enable_location_screen.dart`

### 4.4 `lib/features/doctors/`

Current ownership:
- doctor discovery
- all-doctors, featured, and popular lists
- specialty rosters
- clinic/facility rosters
- doctor detail pages
- favorites and recent-doctor surfaces
- global search and recent-search handoff
- route/map helpers for clinic locations
- caching and offline sync for doctor/favorite data

Notable user-facing surfaces:
- `DoctorsScreen` supports All, Nearest, Hospital, Clinic, and Best Rated filters.
- `GlobalSearchScreen` is the full doctor/specialty/clinic search surface.
- `DoctorDetailsScreen` owns booking handoff, clinic cards, schedules, map, and favorite actions.
- `MyDoctorsScreen` owns the favorite/recent doctor surface.

Directory contents:
- `data/`
  - `clinic.dart`, `clinic.freezed.dart`, `clinic.g.dart`
  - `doctor.dart`, `doctor.freezed.dart`, `doctor.g.dart`
  - `doctor_repository.dart`
  - `route_repository.dart`
  - `specialty.dart`
- `presentation/`
  - `doctors_notifier.dart`
  - `favorites_notifier.dart`
  - `models/doctors_route_args.dart`
  - `screens/clinic_doctors_screen.dart`
  - `screens/doctors_screen.dart`
  - `screens/doctor_details_screen.dart`
  - `screens/featured_doctors_screen.dart`
  - `screens/global_search_screen.dart`
  - `screens/my_doctors_screen.dart`
  - `screens/popular_doctors_screen.dart`
  - `screens/specialty_doctors_screen.dart`
  - `widgets/clinic_location_map_section.dart`
  - `widgets/doctor_appointment_card.dart`
  - `widgets/doctor_details_header.dart`
  - `widgets/doctor_stats_row.dart`
  - `widgets/doctor_timing_list.dart`
  - `widgets/smart_filter_bar.dart`

### 4.5 `lib/features/home/`

Current ownership:
- home dashboard entrypoint
- banner/header composition
- specialties row
- curated doctor highlights
- declarative entrance/stagger animation orchestration for the home surface

User-facing surfaces:
- home banners
- specialties carousel/row
- featured doctors preview
- popular doctors preview

Current implementation notes:
- `presentation/screens/home_screen.dart` now uses `flutter_animate` for the header entrance instead of screen-owned ticker controllers.
- Staggered arrival for home preview items is owned by `home_specialties_row.dart`, `home_popular_doctor_card.dart`, and `home_featured_doctor_card.dart` via widget-level `index` delays.

Directory contents:
- `data/home_repository.dart`
- `presentation/screens/home_screen.dart`
- `presentation/widgets/home_banner.dart`
- `presentation/widgets/home_header.dart`
- `presentation/widgets/home_section_header.dart`
- `presentation/widgets/home_specialties_row.dart`

### 4.6 `lib/features/legal/`

Current ownership:
- legal terms screen

Directory contents:
- `presentation/screens/terms_of_service_screen.dart`

### 4.7 `lib/features/medical_records/`

Current ownership:
- medical record CRUD
- signed URL generation
- attachment upload/download handling
- local caching and offline queueing
- record create/edit flows
- biometric-gated record visibility

Directory contents:
- `data/`
  - `medical_record.dart`
  - `medical_record.freezed.dart`
  - `medical_record.g.dart`
  - `medical_record_repository.dart`
- `presentation/`
  - `models/medical_record_route_args.dart`
  - `screens/add_record_screen.dart`
  - `screens/medical_records_screen.dart`
  - `widgets/record_card.dart`

### 4.8 `lib/features/menu/`

Current ownership:
- settings UI
- drawer UI
- privacy policy screen
- linked-accounts screen
- account activity screen
- review dialog and settings sections
- repository for destructive/security settings actions

User-facing surfaces:
- main drawer and shell navigation handoff
- settings preferences and support/legal sections
- linked providers/accounts
- privacy policy and account activity

Directory contents:
- `data/settings_repository.dart`
- `presentation/screens/account_activity_screen.dart`
- `presentation/screens/linked_accounts_screen.dart`
- `presentation/screens/privacy_policy_screen.dart`
- `presentation/screens/settings_screen.dart`
- `presentation/widgets/custom_drawer.dart`
- `presentation/widgets/review_dialog.dart`
- `presentation/widgets/settings_account_security_section.dart`
- `presentation/widgets/settings_preferences_section.dart`
- `presentation/widgets/settings_section_header.dart`
- `presentation/widgets/settings_support_legal_section.dart`
- `presentation/widgets/settings_tile.dart`

### 4.9 `lib/features/notifications/`

Current ownership:
- notification inbox
- local-first cache and dedup
- foreground/background FCM merge behavior
- remote read/delete sync

Directory contents:
- `data/notification_repository.dart`
- `presentation/notification_notifier.dart`
- `presentation/screens/notifications_screen.dart`

### 4.10 `lib/features/profile/`

Current ownership:
- signed-in profile fetch/edit state
- secure profile cache
- profile view/edit screens
- avatar upload
- location capture and reverse geocoding
- saved-patient management for booking
- shared profile-derived convenience values

Directory contents:
- `data/profile_repository.dart`
- `data/profile_secure_cache_repository.dart`
- `data/user_profile.dart`
- `data/user_profile.freezed.dart`
- `data/user_profile.g.dart`
- `presentation/profile_notifier.dart`
- `presentation/screens/profileview_screen.dart`
- `presentation/screens/profile_screen.dart`

### 4.11 `lib/features/settings/`

Current ownership:
- global settings state owner only

Tracked settings state concerns:
- theme mode
- inactivity lock timeout
- medical record lock
- biometric and 2FA state
- notification and reminder preferences
- drawer hint/tutorial visibility

Directory contents:
- `presentation/settings_notifier.dart`

Visible settings screens and widgets are implemented under `lib/features/menu/`.

### 4.12 `lib/features/splash/`

Current ownership:
- splash entry screen before auth/shell routing settles

Directory contents:
- `presentation/screens/splash_screen.dart`

### 4.13 `lib/features/support/`

Current ownership:
- help center screen
- FAQ data set

Directory contents:
- `data/faq_data.dart`
- `presentation/screens/help_center_screen.dart`

## 5. Shared Cross-Feature Layers

### 5.1 `lib/core/`

This directory owns app-wide infrastructure:
- `constants/`: route constants and legal text constants
- `errors/`: shared failure model (`AppFailure`)
- `localization/`: localization wiring
- `main_wrapper/`: shell wrapper, drawer, floating dock, and root-tab orchestration
- `network/`: offline guard plus connectivity/offline queue sync
- `router/`: `GoRouter` configuration and auth refresh stream
- `security/`: biometrics, device integrity, inactivity lock, and step-up auth
- `services/`: notifications, FCM, and error telemetry
- `theme/`: colors, typography, dimensions, shapes, styles, motion, and themes
- `utils/`: route/security formatting helpers, list fingerprinting helpers, and small shared utilities
- `widgets/`: app-wide UI helpers such as loaders, background-sync indicators, cards, route-error screens, error fallbacks, and the `VolumetricScaffold` (Z-Axis spatial hierarchy wrapper)

### 5.2 `lib/presentation/widgets/`

This is the shared UI primitive layer used across features.

Tracked shared widgets and sublayers:
- `animations/dynamic_glass_shelf_delegate.dart`
- `animations/premium_list_animator.dart`
- `physics/app_scroll_behavior.dart`
- `app_bottom_tray.dart`
- `app_floating_dialog.dart`
- `app_network_image.dart`
- `app_text_field.dart`
- `appointment_card.dart`
- `auth_text_field.dart`
- `complaint_dialog.dart`
- `custom_search_bar.dart`
- `custom_snackbar.dart`
- `custom_text_field.dart`
- `doctor_list_card.dart`
- `doctor_list_card_skeleton.dart`
- `featured_doctor_card.dart`
- `home_featured_doctor_card.dart`
- `home_popular_doctor_card.dart`
- `pessimistic_switch.dart`
- `primary_button.dart`
- `social_button.dart`

Note:
- `app.dart` currently injects bounce physics inline through `MaterialScrollBehavior().copyWith(...)`.
- `lib/presentation/widgets/physics/app_scroll_behavior.dart` still exists as a reusable shared scroll-behavior helper even though it is not the current global injection path.

### 5.3 Legacy / Misc Shared Code

- `lib/data/services/user_service.dart`: legacy/shared service code outside the feature folders
- `lib/test_auth_check.dart`: diagnostic/helper Dart file at the app root
- `lib/services/`: currently exists as an empty placeholder directory

## 6. Backend, Assets, Docs, Platform, and Test Surfaces

### 6.1 Supabase Surface

Current backend-side surface:
- `supabase/config.toml`
- `supabase/functions/client-error-log/index.ts`: backend target for client telemetry
- `supabase/functions/route-proxy/index.ts`: route helper/proxy for doctor route flows
- `supabase/functions/send-reminders/index.ts`: reminder-sending function
- `supabase/functions/send-reminders/deno.json`
- `supabase/functions/send-reminders/.npmrc`
- `supabase/functions/delete-user/`: currently present empty placeholder directory
- `supabase/migrations/20260221183000_add_trusted_devices.sql`
- `supabase/.branches/_current_branch`
- `supabase/.temp/*`
- `supabase/snippets/`: currently present empty placeholder directory
- `supabase_add_country_iso.sql`: root-level helper SQL artifact

### 6.2 Firebase Surface

Firebase-related files currently present:
- `firebase.json`
- `lib/firebase_options.dart`

Firebase is used for app boot initialization, background FCM handling in `main.dart`, and foreground push setup through `FcmService`.

### 6.3 Assets

Current runtime asset surface:
- `assets/animations/darkmode.json`
- `assets/animations/lightmode.json`
- `assets/images/darkmode.svg`
- `assets/images/lightmode.svg`
- `assets/images/logo.png`
- `assets/fonts/`: currently present empty placeholder directory

Additional launch/splash assets currently present:
- Android drawables across `android/app/src/main/res/drawable*`
- iOS launch images/backgrounds under `ios/Runner/Assets.xcassets/Launch*`
- Web splash rasters under `web/splash/img/`

Important runtime note:
- `.env` is declared and loaded by `main.dart`, but it is intentionally excluded from the structure snapshot because it is local/secret configuration.

### 6.4 Documentation Surface

Docs currently present:
- `docs/01_architecture.md`
- `docs/02_app_flow_and_navigation.md`
- `docs/03_security.md`
- `docs/04_design_system_and_animations.md`
- `docs/05_features_reference.md`
- `docs/06_state_management_and_data_flow.md`
- `docs/07_sql.md`
- `docs/full_structure.md`

### 6.5 Tests

Current test surface:

Unit/model/widget tests:
- `test/core/errors/app_failure_test.dart`
- `test/core/utils/security_formatters_test.dart`
- `test/features/appointments/presentation/models/booking_route_args_test.dart`
- `test/features/auth/data/auth_route_resolver_test.dart`
- `test/features/auth/data/security_gate_service_test.dart`
- `test/features/medical_records/presentation/models/medical_record_route_args_test.dart`
- `test/test_db_diagnostic_test.dart`
- `test/widget_test.dart`

Integration/resilience tests:
- `integration_test/auth_2fa_records_flow_test.dart`
- `integration_test/booking_flow_test.dart`
- `integration_test/heavy_load_scroll_test.dart`
- `integration_test/inactivity_lock_booking_resume_test.dart`
- `integration_test/medical_record_network_chaos_test.dart`
- `integration_test/stress_test.dart`

### 6.6 Platform Shells

Current Flutter platform shells:
- `android/`
- `ios/`
- `linux/`
- `macos/`
- `web/`
- `windows/`

These contain the expected runner/config/generated-plugin files for each platform plus the currently present Android, Apple, and web launch/splash resources.

### 6.7 Workspace Helper / Diagnostic Artifacts

Current root-level helper and investigation surface includes:
- Patch/fix scripts: `fix_add_record.py`, `fix_appbar.dart`, `fix_dock.dart`, `fix_dock2.dart`, `fix_home.dart`, `fix_medical.py`, `fix_notifications.py`, `fix_settings.py`, `patch_approute_fix.dart`, `patch_compilation.py`, `patch_discovery.py`, `patch_doctors_decoding.dart`, `patch_encode.dart`, `patch_facility_sort.dart`, `patch_filter_location.dart`, `patch_home.py`, `patch_home_decoding.dart`, `patch_main_precache.dart`, `patch_network_stagger.dart`, `patch_specialty.py`, `patch_splash_handoff.dart`, `patch_splash_lottie.dart`, `patch_sync.dart`, `replace_all_appbars.dart`, `replace_appbars.py`
- Temporary helpers: `tmp_resize.dart`, `tmp_wrapper.dart`, `tmp/update_clinic.py`, `tmp/update_specialty.py`
- Local scratch harnesses: `test_cropper.dart`, `test_cropper2.dart`
- Diagnostics/recovery artifacts: `.gemini_diff_left.txt`, `.gemini_git_status.txt`, `.gemini_utf8.txt`, `analyze.txt`, `analyze_out.txt`, `analyze_utf8.txt`, `errors.txt`, `missing_methods.dart`, `restored_doctor_repo.dart`, `temp_diff.txt`, `wrapper_diff.txt`, `wrapper_diff_history.txt`, `wrapper_log.txt`

These are part of the current workspace snapshot and therefore intentionally appear in the tree below.

## 7. Full Repository Tree Snapshot

```text
daktarpi/
|-- .github/
|   \-- workflows/
|       \-- test.yml
|-- .vscode/
|   |-- launch.json
|   \-- settings.json
|-- android/
|   |-- app/
|   |   |-- src/
|   |   |   |-- debug/
|   |   |   |   \-- AndroidManifest.xml
|   |   |   |-- main/
|   |   |   |   |-- java/
|   |   |   |   |   \-- io/
|   |   |   |   |       \-- flutter/
|   |   |   |   |           \-- plugins/
|   |   |   |   |               \-- GeneratedPluginRegistrant.java
|   |   |   |   |-- kotlin/
|   |   |   |   |   \-- com/
|   |   |   |   |       \-- example/
|   |   |   |   |           \-- daktarpi/
|   |   |   |   |               \-- MainActivity.kt
|   |   |   |   |-- res/
|   |   |   |   |   |-- drawable/
|   |   |   |   |   |   |-- background.png
|   |   |   |   |   |   \-- launch_background.xml
|   |   |   |   |   |-- drawable-hdpi/
|   |   |   |   |   |   |-- android12splash.png
|   |   |   |   |   |   \-- splash.png
|   |   |   |   |   |-- drawable-mdpi/
|   |   |   |   |   |   |-- android12splash.png
|   |   |   |   |   |   \-- splash.png
|   |   |   |   |   |-- drawable-night/
|   |   |   |   |   |   |-- background.png
|   |   |   |   |   |   \-- launch_background.xml
|   |   |   |   |   |-- drawable-night-hdpi/
|   |   |   |   |   |   \-- android12splash.png
|   |   |   |   |   |-- drawable-night-mdpi/
|   |   |   |   |   |   \-- android12splash.png
|   |   |   |   |   |-- drawable-night-v21/
|   |   |   |   |   |   |-- background.png
|   |   |   |   |   |   \-- launch_background.xml
|   |   |   |   |   |-- drawable-night-xhdpi/
|   |   |   |   |   |   \-- android12splash.png
|   |   |   |   |   |-- drawable-night-xxhdpi/
|   |   |   |   |   |   \-- android12splash.png
|   |   |   |   |   |-- drawable-night-xxxhdpi/
|   |   |   |   |   |   \-- android12splash.png
|   |   |   |   |   |-- drawable-v21/
|   |   |   |   |   |   |-- background.png
|   |   |   |   |   |   \-- launch_background.xml
|   |   |   |   |   |-- drawable-xhdpi/
|   |   |   |   |   |   |-- android12splash.png
|   |   |   |   |   |   \-- splash.png
|   |   |   |   |   |-- drawable-xxhdpi/
|   |   |   |   |   |   |-- android12splash.png
|   |   |   |   |   |   \-- splash.png
|   |   |   |   |   |-- drawable-xxxhdpi/
|   |   |   |   |   |   |-- android12splash.png
|   |   |   |   |   |   \-- splash.png
|   |   |   |   |   |-- mipmap-hdpi/
|   |   |   |   |   |   \-- ic_launcher.png
|   |   |   |   |   |-- mipmap-mdpi/
|   |   |   |   |   |   \-- ic_launcher.png
|   |   |   |   |   |-- mipmap-xhdpi/
|   |   |   |   |   |   \-- ic_launcher.png
|   |   |   |   |   |-- mipmap-xxhdpi/
|   |   |   |   |   |   \-- ic_launcher.png
|   |   |   |   |   |-- mipmap-xxxhdpi/
|   |   |   |   |   |   \-- ic_launcher.png
|   |   |   |   |   |-- values/
|   |   |   |   |   |   |-- strings.xml
|   |   |   |   |   |   \-- styles.xml
|   |   |   |   |   |-- values-night/
|   |   |   |   |   |   \-- styles.xml
|   |   |   |   |   |-- values-night-v31/
|   |   |   |   |   |   \-- styles.xml
|   |   |   |   |   \-- values-v31/
|   |   |   |   |       \-- styles.xml
|   |   |   |   \-- AndroidManifest.xml
|   |   |   \-- profile/
|   |   |       \-- AndroidManifest.xml
|   |   \-- build.gradle.kts
|   |-- gradle/
|   |   \-- wrapper/
|   |       |-- gradle-wrapper.jar
|   |       \-- gradle-wrapper.properties
|   |-- .gitignore
|   |-- build.gradle.kts
|   |-- gradle.properties
|   |-- gradlew
|   |-- gradlew.bat
|   \-- settings.gradle.kts
|-- assets/
|   |-- animations/
|   |   |-- darkmode.json
|   |   \-- lightmode.json
|   |-- fonts/
|   \-- images/
|       |-- darkmode.svg
|       |-- lightmode.svg
|       \-- logo.png
|-- docs/
|   |-- 01_architecture.md
|   |-- 02_app_flow_and_navigation.md
|   |-- 03_security.md
|   |-- 04_design_system_and_animations.md
|   |-- 05_features_reference.md
|   |-- 06_state_management_and_data_flow.md
|   |-- 07_sql.md
|   \-- full_structure.md
|-- integration_test/
|   |-- auth_2fa_records_flow_test.dart
|   |-- booking_flow_test.dart
|   |-- heavy_load_scroll_test.dart
|   |-- inactivity_lock_booking_resume_test.dart
|   |-- medical_record_network_chaos_test.dart
|   \-- stress_test.dart
|-- ios/
|   |-- Flutter/
|   |   |-- AppFrameworkInfo.plist
|   |   |-- Debug.xcconfig
|   |   |-- flutter_export_environment.sh
|   |   |-- Generated.xcconfig
|   |   \-- Release.xcconfig
|   |-- Runner/
|   |   |-- Assets.xcassets/
|   |   |   |-- AppIcon.appiconset/
|   |   |   |   |-- Contents.json
|   |   |   |   |-- Icon-App-1024x1024@1x.png
|   |   |   |   |-- Icon-App-20x20@1x.png
|   |   |   |   |-- Icon-App-20x20@2x.png
|   |   |   |   |-- Icon-App-20x20@3x.png
|   |   |   |   |-- Icon-App-29x29@1x.png
|   |   |   |   |-- Icon-App-29x29@2x.png
|   |   |   |   |-- Icon-App-29x29@3x.png
|   |   |   |   |-- Icon-App-40x40@1x.png
|   |   |   |   |-- Icon-App-40x40@2x.png
|   |   |   |   |-- Icon-App-40x40@3x.png
|   |   |   |   |-- Icon-App-60x60@2x.png
|   |   |   |   |-- Icon-App-60x60@3x.png
|   |   |   |   |-- Icon-App-76x76@1x.png
|   |   |   |   |-- Icon-App-76x76@2x.png
|   |   |   |   \-- Icon-App-83.5x83.5@2x.png
|   |   |   |-- LaunchBackground.imageset/
|   |   |   |   |-- background.png
|   |   |   |   |-- Contents.json
|   |   |   |   \-- darkbackground.png
|   |   |   \-- LaunchImage.imageset/
|   |   |       |-- Contents.json
|   |   |       |-- LaunchImage.png
|   |   |       |-- LaunchImage@2x.png
|   |   |       |-- LaunchImage@3x.png
|   |   |       \-- README.md
|   |   |-- Base.lproj/
|   |   |   |-- LaunchScreen.storyboard
|   |   |   \-- Main.storyboard
|   |   |-- AppDelegate.swift
|   |   |-- GeneratedPluginRegistrant.h
|   |   |-- GeneratedPluginRegistrant.m
|   |   |-- Info.plist
|   |   \-- Runner-Bridging-Header.h
|   |-- Runner.xcodeproj/
|   |   |-- project.xcworkspace/
|   |   |   |-- xcshareddata/
|   |   |   |   |-- IDEWorkspaceChecks.plist
|   |   |   |   \-- WorkspaceSettings.xcsettings
|   |   |   \-- contents.xcworkspacedata
|   |   |-- xcshareddata/
|   |   |   \-- xcschemes/
|   |   |       \-- Runner.xcscheme
|   |   \-- project.pbxproj
|   |-- Runner.xcworkspace/
|   |   |-- xcshareddata/
|   |   |   |-- IDEWorkspaceChecks.plist
|   |   |   \-- WorkspaceSettings.xcsettings
|   |   \-- contents.xcworkspacedata
|   |-- RunnerTests/
|   |   \-- RunnerTests.swift
|   \-- .gitignore
|-- lib/
|   |-- core/
|   |   |-- constants/
|   |   |   |-- app_routes.dart
|   |   |   \-- legal_text.dart
|   |   |-- errors/
|   |   |   \-- app_failure.dart
|   |   |-- localization/
|   |   |   \-- app_localizations.dart
|   |   |-- main_wrapper/
|   |   |   \-- main_wrapper.dart
|   |   |-- network/
|   |   |   |-- network_notifier.dart
|   |   |   \-- offline_mode_guard.dart
|   |   |-- router/
|   |   |   |-- app_router.dart
|   |   |   \-- auth_refresh_stream.dart
|   |   |-- security/
|   |   |   |-- biometric_auth_service.dart
|   |   |   |-- biometric_helper_service.dart
|   |   |   |-- biometric_security_service.dart
|   |   |   |-- device_integrity_service.dart
|   |   |   |-- inactivity_lock_guard.dart
|   |   |   \-- sensitive_action_step_up_service.dart
|   |   |-- services/
|   |   |   |-- appointment_notification_service.dart
|   |   |   |-- error_telemetry_service.dart
|   |   |   \-- fcm_service.dart
|   |   |-- theme/
|   |   |   |-- app_colors.dart
|   |   |   |-- app_dimens.dart
|   |   |   |-- app_motion.dart
|   |   |   |-- app_shapes.dart
|   |   |   |-- app_styles.dart
|   |   |   |-- app_text_styles.dart
|   |   |   \-- app_theme.dart
|   |   |-- utils/
|   |   |   |-- backup_code_formatter.dart
|   |   |   |-- list_fingerprint_ext.dart
|   |   |   |-- navigation_helper.dart
|   |   |   \-- security_formatters.dart
|   |   \-- widgets/
|   |       |-- app_error_fallback.dart
|   |       |-- app_loader.dart
|   |       |-- background_sync_indicator.dart
|   |       |-- custom_app_bar.dart
|   |       |-- custom_card.dart
|   |       |-- empty_state_widget.dart
|   |       |-- route_error_screen.dart
|   |       \-- volumetric_scaffold.dart
|   |-- data/
|   |   \-- services/
|   |       \-- user_service.dart
|   |-- features/
|   |   |-- appointments/
|   |   |   |-- data/
|   |   |   |   |-- appointment.dart
|   |   |   |   |-- appointment.freezed.dart
|   |   |   |   |-- appointment.g.dart
|   |   |   |   |-- appointment_repository.dart
|   |   |   |   |-- appointment_secure_cache_repository.dart
|   |   |   |   \-- booking_draft_repository.dart
|   |   |   \-- presentation/
|   |   |       |-- models/
|   |   |       |   \-- booking_route_args.dart
|   |   |       |-- screens/
|   |   |       |   |-- appointment_confirmation_screen.dart
|   |   |       |   |-- dummy_payment_screen.dart
|   |   |       |   |-- my_appointments_screen.dart
|   |   |       |   \-- patient_details_screen.dart
|   |   |       |-- widgets/
|   |   |       |   \-- live_countdown_badge.dart
|   |   |       \-- appointment_notifier.dart
|   |   |-- auth/
|   |   |   |-- data/
|   |   |   |   |-- auth_entry_route_service.dart
|   |   |   |   |-- auth_repository.dart
|   |   |   |   |-- auth_route_resolver.dart
|   |   |   |   |-- security_gate_service.dart
|   |   |   |   |-- trusted_device_repository.dart
|   |   |   |   \-- trusted_device_service.dart
|   |   |   \-- presentation/
|   |   |       |-- models/
|   |   |       |   \-- verify_2fa_route_args.dart
|   |   |       \-- screens/
|   |   |           |-- login_screen.dart
|   |   |           |-- signup_screen.dart
|   |   |           \-- verify_2fa_screen.dart
|   |   |-- common/
|   |   |   \-- presentation/
|   |   |       \-- screens/
|   |   |           \-- enable_location_screen.dart
|   |   |-- doctors/
|   |   |   |-- data/
|   |   |   |   |-- clinic.dart
|   |   |   |   |-- clinic.freezed.dart
|   |   |   |   |-- clinic.g.dart
|   |   |   |   |-- doctor.dart
|   |   |   |   |-- doctor.freezed.dart
|   |   |   |   |-- doctor.g.dart
|   |   |   |   |-- doctor_repository.dart
|   |   |   |   |-- route_repository.dart
|   |   |   |   \-- specialty.dart
|   |   |   \-- presentation/
|   |   |       |-- models/
|   |   |       |   \-- doctors_route_args.dart
|   |   |       |-- screens/
|   |   |       |   |-- clinic_doctors_screen.dart
|   |   |       |   |-- doctor_details_screen.dart
|   |   |       |   |-- doctors_screen.dart
|   |   |       |   |-- featured_doctors_screen.dart
|   |   |       |   |-- global_search_screen.dart
|   |   |       |   |-- my_doctors_screen.dart
|   |   |       |   |-- popular_doctors_screen.dart
|   |   |       |   \-- specialty_doctors_screen.dart
|   |   |       |-- widgets/
|   |   |       |   |-- clinic_location_map_section.dart
|   |   |       |   |-- doctor_appointment_card.dart
|   |   |       |   |-- doctor_details_header.dart
|   |   |       |   |-- doctor_stats_row.dart
|   |   |       |   |-- doctor_timing_list.dart
|   |   |       |   \-- smart_filter_bar.dart
|   |   |       |-- doctors_notifier.dart
|   |   |       \-- favorites_notifier.dart
|   |   |-- home/
|   |   |   |-- data/
|   |   |   |   \-- home_repository.dart
|   |   |   \-- presentation/
|   |   |       |-- screens/
|   |   |       |   \-- home_screen.dart
|   |   |       \-- widgets/
|   |   |           |-- home_banner.dart
|   |   |           |-- home_header.dart
|   |   |           |-- home_section_header.dart
|   |   |           \-- home_specialties_row.dart
|   |   |-- legal/
|   |   |   \-- presentation/
|   |   |       \-- screens/
|   |   |           \-- terms_of_service_screen.dart
|   |   |-- medical_records/
|   |   |   |-- data/
|   |   |   |   |-- medical_record.dart
|   |   |   |   |-- medical_record.freezed.dart
|   |   |   |   |-- medical_record.g.dart
|   |   |   |   \-- medical_record_repository.dart
|   |   |   \-- presentation/
|   |   |       |-- models/
|   |   |       |   \-- medical_record_route_args.dart
|   |   |       |-- screens/
|   |   |       |   |-- add_record_screen.dart
|   |   |       |   \-- medical_records_screen.dart
|   |   |       \-- widgets/
|   |   |           \-- record_card.dart
|   |   |-- menu/
|   |   |   |-- data/
|   |   |   |   \-- settings_repository.dart
|   |   |   \-- presentation/
|   |   |       |-- screens/
|   |   |       |   |-- account_activity_screen.dart
|   |   |       |   |-- linked_accounts_screen.dart
|   |   |       |   |-- privacy_policy_screen.dart
|   |   |       |   \-- settings_screen.dart
|   |   |       \-- widgets/
|   |   |           |-- custom_drawer.dart
|   |   |           |-- review_dialog.dart
|   |   |           |-- settings_account_security_section.dart
|   |   |           |-- settings_preferences_section.dart
|   |   |           |-- settings_section_header.dart
|   |   |           |-- settings_support_legal_section.dart
|   |   |           \-- settings_tile.dart
|   |   |-- notifications/
|   |   |   |-- data/
|   |   |   |   \-- notification_repository.dart
|   |   |   \-- presentation/
|   |   |       |-- screens/
|   |   |       |   \-- notifications_screen.dart
|   |   |       \-- notification_notifier.dart
|   |   |-- profile/
|   |   |   |-- data/
|   |   |   |   |-- profile_repository.dart
|   |   |   |   |-- profile_secure_cache_repository.dart
|   |   |   |   |-- user_profile.dart
|   |   |   |   |-- user_profile.freezed.dart
|   |   |   |   \-- user_profile.g.dart
|   |   |   \-- presentation/
|   |   |       |-- screens/
|   |   |       |   |-- profile_screen.dart
|   |   |       |   \-- profileview_screen.dart
|   |   |       \-- profile_notifier.dart
|   |   |-- settings/
|   |   |   \-- presentation/
|   |   |       \-- settings_notifier.dart
|   |   |-- splash/
|   |   |   \-- presentation/
|   |   |       \-- screens/
|   |   |           \-- splash_screen.dart
|   |   \-- support/
|   |       |-- data/
|   |       |   \-- faq_data.dart
|   |       \-- presentation/
|   |           \-- screens/
|   |               \-- help_center_screen.dart
|   |-- presentation/
|   |   \-- widgets/
|   |       |-- animations/
|   |       |   |-- dynamic_glass_shelf_delegate.dart
|   |       |   \-- premium_list_animator.dart
|   |       |-- physics/
|   |       |   \-- app_scroll_behavior.dart
|   |       |-- app_bottom_tray.dart
|   |       |-- app_floating_dialog.dart
|   |       |-- app_network_image.dart
|   |       |-- app_text_field.dart
|   |       |-- appointment_card.dart
|   |       |-- auth_text_field.dart
|   |       |-- complaint_dialog.dart
|   |       |-- custom_search_bar.dart
|   |       |-- custom_snackbar.dart
|   |       |-- custom_text_field.dart
|   |       |-- doctor_list_card.dart
|   |       |-- doctor_list_card_skeleton.dart
|   |       |-- featured_doctor_card.dart
|   |       |-- home_featured_doctor_card.dart
|   |       |-- home_popular_doctor_card.dart
|   |       |-- pessimistic_switch.dart
|   |       |-- primary_button.dart
|   |       \-- social_button.dart
|   |-- services/
|   |-- app.dart
|   |-- firebase_options.dart
|   |-- main.dart
|   \-- test_auth_check.dart
|-- linux/
|   |-- flutter/
|   |   |-- CMakeLists.txt
|   |   |-- generated_plugin_registrant.cc
|   |   |-- generated_plugin_registrant.h
|   |   \-- generated_plugins.cmake
|   |-- runner/
|   |   |-- CMakeLists.txt
|   |   |-- main.cc
|   |   |-- my_application.cc
|   |   \-- my_application.h
|   |-- .gitignore
|   \-- CMakeLists.txt
|-- macos/
|   |-- Flutter/
|   |   |-- Flutter-Debug.xcconfig
|   |   |-- Flutter-Release.xcconfig
|   |   \-- GeneratedPluginRegistrant.swift
|   |-- Runner/
|   |   |-- Assets.xcassets/
|   |   |   \-- AppIcon.appiconset/
|   |   |       |-- app_icon_1024.png
|   |   |       |-- app_icon_128.png
|   |   |       |-- app_icon_16.png
|   |   |       |-- app_icon_256.png
|   |   |       |-- app_icon_32.png
|   |   |       |-- app_icon_512.png
|   |   |       |-- app_icon_64.png
|   |   |       \-- Contents.json
|   |   |-- Base.lproj/
|   |   |   \-- MainMenu.xib
|   |   |-- Configs/
|   |   |   |-- AppInfo.xcconfig
|   |   |   |-- Debug.xcconfig
|   |   |   |-- Release.xcconfig
|   |   |   \-- Warnings.xcconfig
|   |   |-- AppDelegate.swift
|   |   |-- DebugProfile.entitlements
|   |   |-- Info.plist
|   |   |-- MainFlutterWindow.swift
|   |   \-- Release.entitlements
|   |-- Runner.xcodeproj/
|   |   |-- project.xcworkspace/
|   |   |   \-- xcshareddata/
|   |   |       \-- IDEWorkspaceChecks.plist
|   |   |-- xcshareddata/
|   |   |   \-- xcschemes/
|   |   |       \-- Runner.xcscheme
|   |   \-- project.pbxproj
|   |-- Runner.xcworkspace/
|   |   |-- xcshareddata/
|   |   |   \-- IDEWorkspaceChecks.plist
|   |   \-- contents.xcworkspacedata
|   |-- RunnerTests/
|   |   \-- RunnerTests.swift
|   \-- .gitignore
|-- supabase/
|   |-- .branches/
|   |   \-- _current_branch
|   |-- .temp/
|   |   |-- cli-latest
|   |   |-- gotrue-version
|   |   |-- pooler-url
|   |   |-- postgres-version
|   |   |-- project-ref
|   |   |-- rest-version
|   |   |-- storage-migration
|   |   \-- storage-version
|   |-- functions/
|   |   |-- client-error-log/
|   |   |   \-- index.ts
|   |   |-- delete-user/
|   |   |-- route-proxy/
|   |   |   \-- index.ts
|   |   \-- send-reminders/
|   |       |-- .npmrc
|   |       |-- deno.json
|   |       \-- index.ts
|   |-- migrations/
|   |   \-- 20260221183000_add_trusted_devices.sql
|   |-- snippets/
|   \-- config.toml
|-- test/
|   |-- core/
|   |   |-- errors/
|   |   |   \-- app_failure_test.dart
|   |   \-- utils/
|   |       \-- security_formatters_test.dart
|   |-- features/
|   |   |-- appointments/
|   |   |   \-- presentation/
|   |   |       \-- models/
|   |   |           \-- booking_route_args_test.dart
|   |   |-- auth/
|   |   |   \-- data/
|   |   |       |-- auth_route_resolver_test.dart
|   |   |       \-- security_gate_service_test.dart
|   |   \-- medical_records/
|   |       \-- presentation/
|   |           \-- models/
|   |               \-- medical_record_route_args_test.dart
|   |-- test_db_diagnostic_test.dart
|   \-- widget_test.dart
|-- tmp/
|   |-- update_clinic.py
|   \-- update_specialty.py
|-- web/
|   |-- icons/
|   |   |-- Icon-192.png
|   |   |-- Icon-512.png
|   |   |-- Icon-maskable-192.png
|   |   \-- Icon-maskable-512.png
|   |-- splash/
|   |   \-- img/
|   |       |-- dark-1x.png
|   |       |-- dark-2x.png
|   |       |-- dark-3x.png
|   |       |-- dark-4x.png
|   |       |-- light-1x.png
|   |       |-- light-2x.png
|   |       |-- light-3x.png
|   |       \-- light-4x.png
|   |-- favicon.png
|   |-- index.html
|   \-- manifest.json
|-- windows/
|   |-- flutter/
|   |   |-- CMakeLists.txt
|   |   |-- generated_plugin_registrant.cc
|   |   |-- generated_plugin_registrant.h
|   |   \-- generated_plugins.cmake
|   |-- runner/
|   |   |-- resources/
|   |   |   \-- app_icon.ico
|   |   |-- CMakeLists.txt
|   |   |-- flutter_window.cpp
|   |   |-- flutter_window.h
|   |   |-- main.cpp
|   |   |-- resource.h
|   |   |-- runner.exe.manifest
|   |   |-- Runner.rc
|   |   |-- utils.cpp
|   |   |-- utils.h
|   |   |-- win32_window.cpp
|   |   \-- win32_window.h
|   |-- .gitignore
|   \-- CMakeLists.txt
|-- .gemini_diff_left.txt
|-- .gemini_git_status.txt
|-- .gemini_utf8.txt
|-- .gitignore
|-- .metadata
|-- analysis_options.yaml
|-- analyze.txt
|-- analyze_out.txt
|-- analyze_utf8.txt
|-- errors.txt
|-- firebase.json
|-- fix_add_record.py
|-- fix_appbar.dart
|-- fix_dock.dart
|-- fix_dock2.dart
|-- fix_home.dart
|-- fix_medical.py
|-- fix_notifications.py
|-- fix_settings.py
|-- missing_methods.dart
|-- patch_approute_fix.dart
|-- patch_compilation.py
|-- patch_discovery.py
|-- patch_doctors_decoding.dart
|-- patch_encode.dart
|-- patch_facility_sort.dart
|-- patch_filter_location.dart
|-- patch_home.py
|-- patch_home_decoding.dart
|-- patch_main_precache.dart
|-- patch_network_stagger.dart
|-- patch_specialty.py
|-- patch_splash_handoff.dart
|-- patch_splash_lottie.dart
|-- patch_sync.dart
|-- pubspec.lock
|-- pubspec.yaml
|-- README.md
|-- replace_all_appbars.dart
|-- replace_appbars.py
|-- restored_doctor_repo.dart
|-- supabase_add_country_iso.sql
|-- temp_diff.txt
|-- test_cropper.dart
|-- test_cropper2.dart
|-- tmp_resize.dart
|-- tmp_wrapper.dart
|-- wrapper_diff.txt
|-- wrapper_diff_history.txt
\-- wrapper_log.txt

```
