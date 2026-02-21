# DaktarPi Perspective-Based Codebase Documentation

Last validated: February 21, 2026
Codebase root: `c:\skills development\daktarpi`

Implementation wave update (Feb 20, 2026 - security/routing/testing hardening):
- moved remaining critical settings/profile/linked-account auth-security calls behind repositories (`AuthRepository` / `ProfileRepository`) and removed direct `Supabase.instance.client` usage from those presentation paths
- replaced remaining untyped doctor route extras with typed args (`SpecialtyRouteArgs`, `ClinicRouteArgs`)
- aligned locale config with available localizations (`en_US`, `bn_BD`)
- removed obsolete `lib/test_auth_check.dart`
- added integration test scaffolds:
  - `integration_test/auth_2fa_records_flow_test.dart`
  - `integration_test/booking_flow_test.dart`

Follow-up hardening update (Feb 21, 2026):
- removed remaining direct `Supabase.instance.client` usage from **presentation** layer auth/appointment screens by routing through repositories
- consolidated backup/recovery code input formatter into `lib/core/utils/security_formatters.dart`
- introduced shared motion tokens in `lib/core/theme/app_motion.dart` and applied them to snackbar timing/animation
- converted integration test scaffolds into executable, environment-driven scenarios (gated by `--dart-define=RUN_E2E=true`)
- added `SettingsRepository` to isolate destructive settings operations (`saveRecoveryCodes`, account deletion path)
- added inactivity session-timeout guard (`InactivityLockGuard`) wrapping router output
- completed typed route-extra migration for appointment refresh handoff via `AppointmentsRouteArgs` (removed map extra)
- added negative-path integration assertions for invalid 2FA and past-date booking validation anchor
- completed typed route-extra migration for medical record edit flow via `MedicalRecordRouteArgs`
- added global UI error boundary (`ErrorWidget.builder`) with secure telemetry forwarding and safe `/home` fallback action
- expanded integration happy-path coverage for booking and auth -> 2FA -> records access flows

Resilience + UX hardening wave (Feb 21, 2026):
- added standardized repository failure model (`AppFailure`) for patient-safe error messaging and technical diagnostics
- removed remaining utility-layer direct Supabase access by deleting `lib/core/utils/auth_lib.dart` and refactoring `lib/data/services/user_service.dart` to use `ProfileRepository`
- replaced inactivity auto-signout with biometric lock overlay/unlock flow (session-preserving) in `InactivityLockGuard`
- added encrypted booking-form autosave (`flutter_secure_storage`) for `PatientDetailsScreen`
- added global offline transparency banner: `Offline Mode: Viewing cached records.`
- moved route lookup behind Supabase Edge Function proxy (`supabase/functions/route-proxy`) and added telemetry endpoint scaffold (`supabase/functions/client-error-log`)
- introduced shape/dimension tokens (`lib/core/theme/app_shapes.dart`, `lib/core/theme/app_dimens.dart`) and applied them to shared theme/widgets

Final polish update (Feb 21, 2026):
- completed final settings security audit: MFA toggle/verification flows, password updates, and linked-account link/unlink operations now route through `SettingsRepository`
- hardened `route-proxy` with request rate limiting, upstream timeout controls, and provider abstraction (`ROUTE_PROVIDER=osrm|mapbox`) to support zero-Flutter-change provider swaps
- added PR CI workflow (`.github/workflows/test.yml`) to run unit/widget tests and integration suites (secret-gated)
- added lock-resume stress scenario (`integration_test/inactivity_lock_booking_resume_test.dart`) covering inactivity lock during booking + biometric unlock + draft persistence
- replaced hardcoded spacing/radius values across `lib/presentation/widgets/**` with `AppDimens`/`AppShapes` tokens

Master-plan remediation update (Feb 21, 2026):
- fixed biometric inactivity unlock race: `InactivityLockGuard` now records `paused` timestamp, hard-locks immediately on long background resume, and delays biometric prompt by 300ms after resume for reliable OS dialog display
- hardened MFA downgrade lifecycle: introduced `AppFailure.requiresRecentMfa`, mapped AAL downgrade failures in `SettingsRepository`, and made 2FA toggle flow pessimistic with inline loading + disabled switch while operation is in flight
- added step-up verification mode for `Verify2FAScreen` (`Verify2FARouteArgs.popOnSuccess`) so sensitive settings actions can force recent MFA and return to caller flow
- added idempotency key propagation across booking route DTOs and appointment write payload (`idempotency_key`) to protect against duplicate submits on repeated taps
- introduced encrypted local caches for profile and appointment history (`ProfileSecureCacheRepository`, `AppointmentSecureCacheRepository`) using `flutter_secure_storage` with encrypted Android shared prefs backing
- replaced core doctor/avatar network images with bounded `cached_network_image` + `shimmer` placeholders via `AppNetworkImage` to avoid blank/flicker states and image overflow
- added chaos scenario integration test scaffold: `integration_test/medical_record_network_chaos_test.dart` (network drop on medical-record update path + offline banner expectation)

Front-door friction hardening update (Feb 21, 2026):
- added trusted-device persistence (`TrustedDeviceRepository`) with hashed token storage in Supabase (`public.trusted_devices`) + secure on-device token storage, including 30-day bypass of `/verify-2fa` at splash/post-login when token remains valid
- updated `Verify2FAScreen` with optional "Remember this device for 30 days" control (non-step-up flows), delayed 5-second recovery CTA reveal, and regex-based backup-code block extraction for seamless paste+submit
- introduced trusted-biometric step-up (`SensitiveActionStepUpService`) so trusted devices can use Face ID/Touch ID before sensitive actions (medical records view and password change) with fallback to authenticator when backend requires recent MFA
- hardened Google Sign-In init/error handling: explicit `serverClientId` initialization from `GOOGLE_WEB_CLIENT_ID` and silent cancellation handling for expected user-abort paths

Compliance controls update (Feb 21, 2026):
- added startup device-integrity enforcement (`DeviceIntegrityService`) with platform-channel root/jailbreak checks; compromised-device detection now wipes secure local storage and signs the session out before app usage
- added Android screenshot protection with `FLAG_SECURE` in `MainActivity` (blocks screenshots and recents thumbnails for PHI surfaces)
- added iOS privacy shield during background/inactive transitions in `AppDelegate` to reduce PHI exposure in app switcher snapshots
- introduced on-device appointment reminder scheduling via `AppointmentNotificationService` using `flutter_local_notifications` + `timezone` with absolute UTC trigger timestamps
- wired reminder lifecycle sync into booking/cancel flows: schedule on create/reschedule and explicit cancel on cancel/complete paths
- aligned reminder UX options to clinically meaningful presets (`15 min`, `1 hour`, `24 hours`) and tightened OTP input ergonomics (`TextInputType.number`, OTP autofill hints, explicit clipboard support)
- added absolute session lifetime enforcement (`ABSOLUTE_SESSION_TIMEOUT_MS`, default 12h) in `InactivityLockGuard` in addition to inactivity lock timeout

## 1. Purpose and Scope

This document explains the app from multiple architecture perspectives so you can inspect the same system through different lenses:
- runtime and navigation behavior
- data and state flow
- security and trust boundaries
- UI/design system composition
- animation system behavior
- maintainability and risk profile

Method used for this update:
- static source inspection of `lib/**`
- dependency and route inspection from `pubspec.yaml` and router files
- full analyzer run (`flutter analyze`) on February 21, 2026

Analyzer status at time of writing:
- `flutter analyze` -> No issues found

## 2. Quick Topology

- App type: Flutter mobile-first app
- Backend: Supabase (Auth, Postgres, Storage, Realtime, RPC)
- Router: `go_router` with `StatefulShellRoute.indexedStack`
- Global state style: singleton `ChangeNotifier` objects + local `setState`
- UI style: tokenized `AppColors`/`AppTextStyles` + reusable cards/inputs/buttons

Core entry files:
- `lib/main.dart`
- `lib/app.dart`
- `lib/core/router/app_router.dart`
- `lib/core/main_wrapper/main_wrapper.dart`

## 3. Perspective Index

| Perspective | Primary question | Start files |
| --- | --- | --- |
| Runtime | How the app boots and makes first route decisions | `lib/main.dart`, `lib/app.dart`, `lib/features/splash/presentation/screens/splash_screen.dart` |
| Navigation | How routes, stacks, and shell branches are composed | `lib/core/router/app_router.dart`, `lib/core/constants/app_routes.dart`, `lib/core/main_wrapper/main_wrapper.dart` |
| Data flow | How data moves between Supabase, repositories, notifiers, and UI | `lib/features/**/data/*`, `lib/features/**/presentation/*` |
| State flow | Where shared state lives and how UI reacts | `lib/features/*/presentation/*_notifier.dart` |
| Security | How auth, MFA, recovery, and sensitive actions are enforced | `lib/features/auth/presentation/screens/*`, `lib/features/menu/presentation/screens/settings_screen.dart`, `lib/features/menu/presentation/screens/linked_accounts_screen.dart` |
| Design system | How visual tokens and reusable widgets control look/feel | `lib/core/theme/*`, `lib/presentation/widgets/*` |
| Animation | Which interactions are animated and how they are implemented | `lib/core/main_wrapper/main_wrapper.dart`, `lib/features/doctors/presentation/screens/doctor_details_screen.dart`, `lib/presentation/widgets/custom_snackbar.dart` |
| Operations | What is testable, deployable, and currently risky | `test/widget_test.dart`, `.env` usage, repo-wide conventions |

## 4. Runtime Flow Architecture

### 4.1 Boot sequence

```text
main()
  -> WidgetsFlutterBinding.ensureInitialized()
  -> dotenv.load(".env")
  -> Supabase.initialize(url, anonKey)
  -> initialize local reminder service
  -> run compromised-device enforcement (wipe + sign-out when rooted/jailbroken)
  -> runApp(MyApp) OR compromised-device block screen
```

Files:
- `lib/main.dart`

### 4.2 App composition

`MyApp` uses `AnimatedBuilder` on `SettingsNotifier.instance` so theme changes re-render `MaterialApp.router` without rebuilding app state manually.

Key points:
- `theme`, `darkTheme`, and `themeMode` are wired
- locale is currently hard-locked to `Locale('en', 'US')`
- router config is centralized

Files:
- `lib/app.dart`
- `lib/features/settings/presentation/settings_notifier.dart`

### 4.3 Initial gate behavior

Splash waits 2 seconds, then branches through a centralized auth-route resolver:

```text
if no session -> /login
if signed in and AAL2 step-up required -> /verify-2fa
if session and userMetadata['dob'] missing -> /profile/edit
if signed in and profile complete -> /home
```

This is now resolved through:
- `AuthRouteResolver` (`lib/features/auth/data/auth_route_resolver.dart`)
- `AuthRepositoryRouteProvider` adapter in splash/login flows

File:
- `lib/features/splash/presentation/screens/splash_screen.dart`

## 5. Navigation Architecture

### 5.1 Router shape

`GoRouter` is split into:
- root stack routes (auth, detail flows, settings/legal/support, booking steps)
- shell route with 4 persistent branches

Shell branches:
- `/home`
- `/doctors`
- `/appointments`
- `/profile`

File:
- `lib/core/router/app_router.dart`

### 5.2 Parameter and payload conventions

Patterns used:
- path params for entity identity (`/doctor_details/:id`, `/specialty_doctors/:id`)
- typed route argument objects for booking/payment flows

Typed booking payload contracts:
- `AppointmentBookingArgs`
- `PaymentMethodArgs`

Defined in:
- `lib/features/appointments/presentation/models/booking_route_args.dart`

Current typed booking fields:
- `doctor`, `clinic`, `initialDate`/`appointmentDate`, `timeSlot`, `patientDetails`, `appointmentId`
- specialty/clinic: `{ name: ... }`

### 5.3 Back-stack behavior and shell UX

`MainWrapper` owns:
- custom drawer + tab shell composition
- gesture policy (drawer drag only on Home index)
- swipe tab switching when drawer is closed
- custom back handling:
  - close drawer first
  - if at root tab, call `SystemNavigator.pop()`
  - else route pop

File:
- `lib/core/main_wrapper/main_wrapper.dart`

## 6. State Flow Architecture

### 6.1 Global shared state

Singleton notifiers:
- `ProfileNotifier`: profile cache + derived currency symbol
- `FavoritesNotifier`: favorite doctor IDs with optimistic toggle
- `AppointmentNotifier`: appointment list and mutation state
- `SettingsNotifier`: persisted theme mode and drawer hint toggle

Pattern:
- screens subscribe with `addListener(...)`
- local rebuild via `setState` in listener callbacks

### 6.2 Local state

Most screens keep screen-local state for:
- loading flags
- form fields and validation
- modal or wizard step indices
- transient UI selections (date, slot, selected clinic)

### 6.3 Observed state architecture tradeoff

Pros:
- simple to reason about
- low framework overhead

Cons:
- listener lifecycle boilerplate in every screen
- no centralized dependency injection or typed state graph
- screen and service boundaries can blur

## 7. Data Flow Architecture

## 7.1 Data source map

Supabase tables referenced in code:
- `profiles`
- `doctors`
- `specialties`
- `clinics`
- `doctor_clinics`
- `doctor_schedules`
- `favorite_doctors`
- `appointments`
- `medical_records`

Supabase storage buckets:
- `profile_pictures` (public URL usage)
- `medical_docs` (private + signed URL usage)

Supabase RPCs:
- `use_recovery_code`
- `user_has_recovery_codes`
- `save_recovery_codes`
- `delete_user_account`

Realtime channel:
- `public:appointments` filtered by `user_id`

External APIs/services:
- Supabase Edge Function `route-proxy` (upstream routing provider currently OSRM-compatible)
- location/geocoding (`geolocator`, `geocoding`)
- external map/email launch (`url_launcher`)

### 7.2 Main data flow patterns

Pattern A: repository-backed list screen

```text
Screen -> Repository query -> Supabase table -> parse model/map -> setState/notifier -> render list
```

Pattern B: form mutation flow

```text
Screen form -> local validation -> repository/auth call -> DB/storage write -> notifier refresh -> route/snackbar
```

Pattern C: security-gated read

```text
screen load -> check appMetadata AAL/2FA -> allow read OR throw gate exception -> redirect to verify screen
```

### 7.3 Feature-specific data flows

Auth login:
- email/password and Google ID token sign-in
- post-auth branch based on app metadata (`is_2fa_enabled`, `aal`) and user metadata (`dob`)

Files:
- `lib/features/auth/presentation/screens/login_screen.dart`

Profile:
- read from `profiles`
- upload avatar to `profile_pictures`
- upsert `profiles`
- update auth metadata (`full_name`, `dob`)

Files:
- `lib/features/profile/presentation/screens/profile_screen.dart`
- `lib/features/profile/data/profile_repository.dart`

Doctors and favorites:
- fetch doctors/specialties/clinics/schedules
- favorite toggles map to `favorite_doctors`
- nearest sort computes distance client-side from joined clinic coordinates

Files:
- `lib/features/doctors/data/doctor_repository.dart`
- `lib/features/doctors/presentation/favorites_notifier.dart`

Appointments:
- create/update in `appointments`
- list only `status = confirmed`
- cancel/complete mutate status
- realtime refresh subscription

Files:
- `lib/features/appointments/data/appointment_repository.dart`
- `lib/features/appointments/presentation/screens/my_appointments_screen.dart`

Medical records:
- gated read from `medical_records`
- upload docs/images to `medical_docs`
- persist storage paths in `file_urls`
- generate signed URL for secure viewing

Files:
- `lib/features/medical_records/data/medical_record_repository.dart`
- `lib/features/medical_records/presentation/screens/*.dart`

### 7.4 Repository boundary reality

Strict audit status (Feb 21, 2026):
- no direct `Supabase.instance.client` calls remain in:
  - `lib/features/doctors/presentation/**`
  - `lib/features/medical_records/presentation/**`
  - `lib/features/profile/presentation/**`
- auth/appointments/settings/profile presentation paths now route data access through repositories/services

Recent improvements applied:
- Splash/login post-auth routing moved to shared resolver/service path
- 2FA/AAL2 verification decisions centralized via `SecurityGateService`
- Patient details screen no longer reads auth user email directly from Supabase client; it now uses `ProfileRepository`
- destructive settings operations isolated in `SettingsRepository`

Utility-layer boundary gap from previous wave is now closed:
- `lib/core/utils/auth_lib.dart` removed
- `lib/data/services/user_service.dart` now delegates to `ProfileRepository`

Current direct Supabase client construction is restricted to repositories/services designed as backend gateways.

## 8. Security and Trust Architecture

### 8.1 Identity and session model

- primary auth: Supabase email/password and Google ID token
- optional MFA using TOTP factors
- recovery code support via RPC-backed one-time code consumption

### 8.2 AAL2 enforcement strategy

The app now enforces startup/auth routing via a centralized route resolver.
It enforces in sensitive flows through shared security services:
- verify screen branch when `is_2fa_enabled` and `aal1`
- medical records read gate in repository
- sensitive account changes in settings/linked accounts

Centralized components:
- `SecurityGateService` (`lib/features/auth/data/security_gate_service.dart`)
- `AuthRouteResolver` (`lib/features/auth/data/auth_route_resolver.dart`)

### 8.3 Sensitive operations requiring additional verification

- disable 2FA
- change password (when 2FA enabled)
- unlink identity / security changes
- account deletion

### 8.4 Account deletion path

Flow in settings:
- typed `DELETE` confirmation
- optional OTP verification
- storage cleanup for user files in `medical_docs`
- RPC `delete_user_account`
- sign out + redirect login

File:
- `lib/features/menu/presentation/screens/settings_screen.dart`

### 8.5 Screen privacy and device integrity

Implemented controls:
- Android screenshot/recents blocking via `FLAG_SECURE` in `MainActivity`
- iOS privacy shield overlay on inactive/background transitions in `AppDelegate`
- startup root/jailbreak checks via platform channel (`com.daktarpi/device_integrity`)
- compromise response path: secure-storage wipe (`FlutterSecureStorage.deleteAll`) + auth sign-out before app access

Important caveat:
- iOS does not provide a universal API to fully block user screenshots for all content; the current implementation protects app-switcher snapshots and enforces compromised-device handling but should still be validated against your target compliance interpretation.

### 8.6 Session timeout model

- inactivity lock timeout: `INACTIVITY_TIMEOUT_MS` (default 5 minutes)
- absolute session timeout: `ABSOLUTE_SESSION_TIMEOUT_MS` (default 12 hours)
- on absolute timeout expiry, session is signed out and routed to `/login`

## 9. Design Flow Architecture

### 9.1 Token pipeline

```text
AppColors/AppTextStyles/AppStyles
  -> AppTheme ThemeData
  -> Reusable widgets (buttons, fields, cards)
  -> Feature screens
```

Core token files:
- `lib/core/theme/app_colors.dart`
- `lib/core/theme/app_text_styles.dart`
- `lib/core/theme/app_styles.dart`
- `lib/core/theme/app_theme.dart`

### 9.2 Reusable component layers

Base controls:
- `PrimaryButton`
- `AuthTextField`
- `AppTextField`
- `CustomSearchBar`
- `CustomSnackbar`

Domain cards:
- doctor cards (`DoctorListCard`, `FeaturedDoctorCard`, home variants)
- appointment card
- record card

### 9.3 Visual language currently used

Common motifs:
- gradient page backgrounds
- rounded cards (12-20 radius)
- soft drop shadows
- green primary CTA emphasis
- sectioned pages with high visual contrast between header and content

### 9.4 Theme and localization behavior

- light and dark themes exist and are controlled by `SettingsNotifier`
- locale is currently fixed to English (`en_US`) in `MyApp`
- `AppLocalizations` contains both `en` and `bn`, but runtime support is effectively English-only due app configuration

## 10. Animation Flow Architecture

The codebase uses a layered animation model instead of one global animation manager.

### 10.1 Layer 1: Shell/navigation animations

Main wrapper drawer stack animation:
- `AnimationController` drives card translation, scaling, and corner radius
- staged visual layers: background card, drawer, foreground card, close button
- intro hint animation runs after launch when enabled

File:
- `lib/core/main_wrapper/main_wrapper.dart`

### 10.2 Layer 2: Cross-screen transition animation

Hero transitions for doctor avatars/cards:
- consistent hero tags (`doctor-hero-{id}`)
- used across home cards, list cards, and details header

Files:
- `lib/presentation/widgets/home_popular_doctor_card.dart`
- `lib/presentation/widgets/home_featured_doctor_card.dart`
- `lib/presentation/widgets/doctor_list_card.dart`
- `lib/features/doctors/presentation/widgets/doctor_details_header.dart`

### 10.3 Layer 3: Feature interaction animations

Doctor details map/fab controls:
- two independent animated menus (direction + locator)
- `SizeTransition` + `RotationTransition` + auto-close timers

Files:
- `lib/features/doctors/presentation/screens/doctor_details_screen.dart`

Auth and security dialogs:
- `AnimatedSwitcher` and `AnimatedCrossFade` for mode/step transitions

Files:
- `lib/features/auth/presentation/screens/verify_2fa_screen.dart`
- `lib/features/menu/presentation/screens/settings_screen.dart`

Micro-interactions:
- `AnimatedContainer` for chips/radios/forgot-password state
- `AnimatedSize` in forgot-password sheet step transitions

Files:
- `lib/features/doctors/presentation/screens/doctors_screen.dart`
- `lib/features/appointments/presentation/screens/patient_details_screen.dart`
- `lib/features/auth/presentation/screens/login_screen.dart`

Transient feedback animation:
- custom overlay snackbar with slide + scale + fade

File:
- `lib/presentation/widgets/custom_snackbar.dart`

## 11. Feature Architecture by Flow

### 11.1 Auth and onboarding flow

```text
Splash -> Login/Signup -> (optional Verify2FA) -> Profile edit gate -> Home
```

Key branch logic:
- session existence -> auth routing
- metadata `dob` -> profile completion gate
- app metadata `is_2fa_enabled` + `aal` -> verify2fa gate

Implementation note:
- splash and login now use the same shared route resolver logic to prevent branch drift.

### 11.2 Discovery and booking flow

```text
Home/Doctors lists -> Doctor details -> choose clinic/date/slot -> Patient details -> Appointment confirmation -> My appointments
```

Booking data handoff now uses typed argument DTOs (`AppointmentBookingArgs`, `PaymentMethodArgs`) in both route definitions and navigation call sites.

### 11.3 Medical records protected flow

```text
MedicalRecordsScreen load
  -> repository AAL check
  -> if requires AAL2, show verify dialog
  -> verify route
  -> return and reload records
```

### 11.4 Settings and account security flow

Settings centralizes:
- MFA setup wizard
- MFA disable flow
- backup code generation/regeneration
- password update flow (with optional AAL2 gate)
- linked account management entry
- account deletion

## 12. Operational and Quality Perspective

### 12.1 Build/run prerequisites

Required `.env` keys:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `GOOGLE_WEB_CLIENT_ID`

### 12.2 Static analysis

- `flutter analyze` passes with no issues
- lint baseline is default `flutter_lints`

### 12.3 Test baseline

Test baseline has improved but is still incomplete for full medical-grade confidence.

Implemented tests:
- `test/features/auth/data/security_gate_service_test.dart`
- `test/features/auth/data/auth_route_resolver_test.dart`
- `test/features/appointments/presentation/models/booking_route_args_test.dart`
- integration scenarios:
  - `integration_test/auth_2fa_records_flow_test.dart`
  - `integration_test/booking_flow_test.dart`
  - `integration_test/inactivity_lock_booking_resume_test.dart`
  - `integration_test/medical_record_network_chaos_test.dart`

CI automation:
- pull-request workflow on `main`: `.github/workflows/test.yml`
- unit/widget tests always run
- integration matrix runs when required E2E secrets are present

Remaining gap:
- executable integration coverage now includes booking/auth gates and inactivity-lock resume; broader long-run load/stress depth is still pending

### 12.4 Data and schema migration visibility

No in-repo migration directory is present in this snapshot, so schema evolution and RPC definitions are external to the app repository.

## 13. Architecture Risks and Debt (Prioritized)

1. Mixed data-access boundaries (low)
- presentation and previously-flagged utility paths now route through repositories/services
- effect: strong domain isolation baseline; maintainers should enforce repository-only policy for new features

2. Security logic duplication (resolved in current snapshot)
- final settings/linked-account audit completed: security-sensitive actions now route through `SettingsRepository` and `SecurityGateService`
- effect: previously identified drift risk from non-migrated settings paths is removed in current code snapshot

3. Untyped route payload contracts (low)
- booking/payment/appointments refresh/doctor route extras/medical-record edit handoff now use typed DTO contracts
- effect: state.extra runtime cast risk reduced to low; maintainers should preserve typed extras for any new route additions

4. Locale configuration mismatch (resolved in current snapshot)
- runtime locale support and localization assets are aligned (`en_US`, `bn_BD`)
- effect: previous mismatch risk removed for current supported locales

5. External routing provider reliability (medium)
- route fetch now runs via Supabase Edge Function proxy (`route-proxy`) instead of direct client->OSRM calls
- effect: proxy now enforces server-side rate limiting and supports env-driven upstream provider switching (`osrm`/`mapbox`), but production BAA-backed provider selection + contractual SLA decision remains pending

6. Duplicate formatter/util classes (resolved in current snapshot)
- backup code formatting utilities were consolidated into shared security formatter utilities in the Feb 21 update
- effect: prior duplication and drift risk removed in current snapshot

7. Limited automated test coverage (high)
- auth-routing, 2FA gate service, and typed booking-arg tests now exist
- effect: improved regression coverage with executable integration flows + negative-path checks, but still below target for full V&V expectations

8. Production-irrelevant utility in `lib/` (resolved in current snapshot)
- `lib/test_auth_check.dart` removed
- effect: previous clutter/confusion risk removed

9. PHI-at-rest posture (low-medium)
- profile and appointment cache persistence now uses encrypted local storage wrappers:
  - `lib/features/profile/data/profile_secure_cache_repository.dart`
  - `lib/features/appointments/data/appointment_secure_cache_repository.dart`
- non-PHI UI preferences (`theme_mode`, `show_drawer_hint`) remain in `SharedPreferences`
- effect: encrypted at-rest baseline now exists for cached profile/appointment surfaces; keep extending this policy to any future medical-record offline cache implementation

## 14. Recommended Roadmap by Perspective

### Data architecture
- keep presentation and utility layers free of direct Supabase calls; enforce repository/service-only backend access for new features
- standardize DTO/model mapping and error normalization

### Security architecture
- introduce a shared security gate service for AAL2/recovery workflows
- centralize verification dialogs/components

Status:
- shared security gate service + centralized auth route resolver implemented
- settings/linked-account security actions (MFA toggles, password updates, account unlinking, account deletion) are now routed through `SettingsRepository`; continue enforcing repository-only boundaries for any future settings/profile additions
- inactivity protection now uses lock-overlay + biometric resume instead of hard sign-out

### Navigation architecture
- replace `Map<String, dynamic>` route extras with typed argument classes

Status:
- implemented for appointment booking/payment routes
- appointment refresh handoff now also uses typed args (`AppointmentsRouteArgs`)

### Design system
- consolidate repeated style literals into theme extensions/tokens
- align locale configuration with `AppLocalizations` intent

Status:
- `AppShapes` and `AppDimens` introduced and applied to shared theme/widgets; continue replacing hardcoded per-screen values

### Animation architecture
- define shared motion constants (durations/curves)
- reduce duplicate animation primitives in similar flows where practical

### Quality and CI
- add route smoke tests and core flow integration tests:
  - login -> 2FA gate
  - profile completion gate
  - booking creation/reschedule
  - medical record AAL2 gate
  - settings security operations

Status:
- unit tests are wired in pull-request CI
- integration tests are wired in pull-request CI (secret-gated matrix)
- integration coverage includes negative-path anchors (wrong 2FA, past-date booking guard) plus inactivity-lock mid-booking resume with biometric unlock and draft persistence checks; broader scenario depth still pending
- repository error handling now standardized on `AppFailure` for safer patient-facing messaging

## 15. Key File Map by Perspective

Runtime and navigation:
- `lib/main.dart`
- `lib/app.dart`
- `lib/core/router/app_router.dart`
- `lib/core/main_wrapper/main_wrapper.dart`

Data and state:
- `lib/features/doctors/data/doctor_repository.dart`
- `lib/features/appointments/data/appointment_repository.dart`
- `lib/features/medical_records/data/medical_record_repository.dart`
- `lib/features/profile/data/profile_repository.dart`
- `lib/features/*/presentation/*_notifier.dart`

Security:
- `lib/features/auth/presentation/screens/login_screen.dart`
- `lib/features/auth/presentation/screens/verify_2fa_screen.dart`
- `lib/features/menu/presentation/screens/settings_screen.dart`
- `lib/features/menu/presentation/screens/linked_accounts_screen.dart`

Design and animation:
- `lib/core/theme/*`
- `lib/presentation/widgets/*`
- `lib/features/doctors/presentation/screens/doctor_details_screen.dart`
- `lib/core/main_wrapper/main_wrapper.dart`
- `lib/presentation/widgets/custom_snackbar.dart`

## 16. Closing Notes

This codebase already has clear feature modularization and a coherent UX language. The main next leverage points are boundary consistency (data/security), typed contracts (routing), and test coverage for high-risk flows.
