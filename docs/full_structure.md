
# DaktarPai — Exhaustive Directory & File Profile Map

## 1. Root & Core Application Structure

```text
lib/
├── main.dart 
│   # App Entry: Calls `WidgetsFlutterBinding.ensureInitialized()`, loads `.env`, and initializes Supabase. 
│   # Startup logic: Calls `SettingsNotifier.loadSettings()`, `AppointmentNotificationService.initialize()`, and `DeviceIntegrityService.enforceOnStartup()`. 
│   # Security fallback: Renders `_CompromisedDeviceApp` if device integrity fails; otherwise, runs `runApp(MyApp)`.
│
├── app.dart 
│   # MaterialApp Wrapper: Implements `MaterialApp.router`, feeding it `AppTheme` (light/dark modes) and the `appRouter` (GoRouter). 
│   # Listeners: Uses an `AnimatedBuilder` to listen to `SettingsNotifier.instance` for theme changes. 
│   # Global Guards: Wraps the entire application in `OfflineModeGuard` and `InactivityLockGuard`.
│
├── core/
│   ├── constants/
│   │   └── legal_text.dart # Stores raw string constants for legal text.
│   ├── errors/
│   │   └── app_failure.dart # Typed error class containing `userMessage` for snackbars, `isRequiresRecentMfa` flags, and factory constructors for error types.
│   ├── localization/
│   │   └── app_localizations.dart # Handles translations for English (`en_US`) and Bengali (`bn_BD`).
│   ├── main_wrapper/
│   │   └── main_wrapper.dart 
│   │       # Shell Navigation: Uses `StatefulShellRoute.indexedStack` for 4 branches (`shellHome`, `shellDoctors`, `shellAppointments`, `shellProfile`).
│   │       # Drawer Animation: Employs an `AnimationController` triggered by a `GestureDetector` (swipe velocity-based snap) to apply `Transform.translate`, `Transform.scale`, and `ClipRRect` to the main content.
│   │       # Nav Indicator: Uses `AnimatedPositioned` for bottom nav selection.
│   ├── network/
│   │   └── offline_mode_guard.dart # Monitors connectivity. Displays a yellow banner utilizing an `AnimatedContainer` (height 0 ↔ 40).
│   ├── router/
│   │   ├── app_router.dart # Defines GoRouter tables and implements a global redirect checking `Supabase.instance.client.auth.currentSession` to send unauthenticated users to `/login?from=<path>`.
│   │   └── auth_refresh_stream.dart # Wraps `onAuthStateChange` into a `ChangeNotifier` to power `GoRouter.refreshListenable`.
│   ├── security/
│   │   ├── biometric_auth_service.dart # Wraps `local_auth`. Features `canUseBiometricUnlock()` and `authenticate()` (utilizing `biometricOnly: true` and `stickyAuth: true`).
│   │   ├── biometric_helper_service.dart # Provides high-level biometric operation helpers.
│   │   ├── biometric_security_service.dart # Extra security-focused utilities for biometrics.
│   │   ├── device_integrity_service.dart # Calls `MethodChannel('com.daktarpi/device_integrity')` for root/jailbreak checks. On failure, wipes `FlutterSecureStorage` and signs out.
│   │   ├── inactivity_lock_guard.dart # Enforces session timeouts. Locks app based on `SettingsNotifier.inactivityTimeoutMs` or absolute 12-hour timeout. Shows a lock screen overlay via `AnimatedOpacity` with gradient and auto-attempts biometric unlock.
│   │   └── sensitive_action_step_up_service.dart # `authenticateIfTrusted()` merges biometric and trusted device checks to conditionally bypass TOTP.
│   ├── services/
│   │   ├── appointment_notification_service.dart # Singleton managing local notifications, initialized after successful login.
│   │   └── error_telemetry_service.dart # Captures errors from `FlutterError.onError`, `PlatformDispatcher.instance.onError`, and `runZonedGuarded`.
│   ├── theme/
│   │   ├── app_colors.dart # Central hex constants (`primaryGreen`: `#00C689`, `dangerRed`: `#E53935`, `cyanHeader`: `#E0F7FA`, etc.).
│   │   ├── app_dimens.dart # Stores page horizontal/vertical padding and elevation levels.
│   │   ├── app_motion.dart # Timings: `fast` (200ms), `standard` (300ms), `slow` (400ms). Curves: `Curves.easeOutBack`, `Curves.easeInOut`.
│   │   ├── app_shapes.dart # Standardized `BorderRadius` (sm, md, lg).
│   │   ├── app_styles.dart # Predefined `BoxDecoration` sets like `surfaceCard()` and `pageGradient` (a 4-stop linear gradient).
│   │   ├── app_text_styles.dart # Google Fonts Poppins weights. E.g., `h1` (24px Bold), `button` (16px SemiBold).
│   │   └── app_theme.dart # Material 3 `ThemeData`. Light background `#FBFBFB`; Dark background `#121212` with `#1E1E1E` inputs.
│   ├── utils/
│   │   ├── backup_code_formatter.dart # `TextInputFormatter` for visual XXXX-XXXX rendering.
│   │   ├── navigation_helper.dart # Helper navigation functions.
│   │   └── security_formatters.dart # `BackupCodeFormatter` input formatting and `extractFirstBackupCode()` clipboard detection.
│   └── widgets/
│       ├── app_error_fallback.dart # Overrides the red error screen, injecting a "Go Home" button.
│       └── route_error_screen.dart # Displays 404/invalid route UI.
│
├── data/
│   └── services/user_service.dart # Shared generic user utilities.

```

---

## 2. Feature Modules Structure (`lib/features/`)

```text
├── appointments/
│   ├── data/
│   │   ├── appointment.dart # Freezed model for appointments.
│   │   ├── appointment_repository.dart # Wraps Supabase CRUD operations on the `appointments` table.
│   │   ├── appointment_secure_cache_repository.dart # Local encrypted caching allowing offline appointment viewing.
│   │   └── booking_draft_repository.dart # Caches data locally during the multi-step booking flow.
│   └── presentation/
│       ├── appointment_notifier.dart # Singleton state holding local lists. Calls `notifyListeners()` when triggered by its Supabase Realtime subscription.
│       ├── models/booking_route_args.dart # Carries doctor, clinic, date, time slot, and idempotency key through the flow.
│       └── screens/
│           ├── appointment_confirmation_screen.dart # Step 2 of booking (Payment/Confirmation).
│           ├── my_appointments_screen.dart # (571 lines) Real-time list of appointments. Shows action sheets and confirmation dialogs for canceling/rescheduling.
│           └── patient_details_screen.dart # Step 1 of booking (Form input).
│
├── auth/
│   ├── data/
│   │   ├── auth_entry_route_service.dart # `resolvePostAuthRoute()` evaluates session state to return `/login`, `/verify-2fa`, or `/home`.
│   │   ├── auth_repository.dart # Hub containing 25 methods encompassing `supabase.auth`. Methods include `signUp()`, `signIn()`, `signInWithGoogleIdToken()`, `refreshSession()`, `resetPasswordForEmail()`, `verifyRecoveryOtp()`, `updatePassword()`, and `deleteUserAccount()`. `signOut()` triggers `.clear()` on all notifiers.
│   │   ├── auth_route_resolver.dart # Pure logic decoupling for auth routing testing.
│   │   ├── security_gate_service.dart # `evaluateAal2Gate()` determines Step-Up needs. Executes `verifyWithTotp()` and `verifyWithRecoveryCode()`.
│   │   ├── trusted_device_repository.dart # `trustCurrentDevice()` generates a UUID, stores a SHA-256 hash server-side (30-day TTL), and saves raw string to `FlutterSecureStorage`.
│   │   └── trusted_device_service.dart # High-level operations for devices.
│   └── presentation/
│       ├── models/verify_2fa_route_args.dart # Configuration args: `popOnSuccess`, `markAsTrustedDevice`.
│       └── screens/
│           ├── login_screen.dart # (805 lines) Handles email/password and Google login. Houses a 3-step animated forgot password bottom sheet (Email → OTP → New Password).
│           ├── signup_screen.dart # (318 lines) Registration and ToS acceptance.
│           └── verify_2fa_screen.dart # (517 lines) Crossfades between 6-digit OTP and 8-char recovery code entry using `AnimatedSwitcher` and `AnimatedCrossFade`. Employs a 5-second `AnimatedOpacity` delay before revealing the recovery assist link. Includes clipboard detection.
│
├── common/
│   └── presentation/screens/enable_location_screen.dart # Location permission interface.
│
├── doctors/
│   ├── data/
│   │   ├── clinic.dart # `Clinic` Freezed model.
│   │   ├── doctor.dart # `Doctor` Freezed model.
│   │   ├── doctor_repository.dart # CRUD, search logic, filters, and favorite operations on Supabase tables.
│   │   ├── route_repository.dart # HTTP wrapper fetching driving polylines via OpenRouteService API.
│   │   └── specialty.dart # `Specialty` Freezed model.
│   └── presentation/
│       ├── favorites_notifier.dart # Singleton `ChangeNotifier` retaining a `Set<int>` of `favoriteIds` and an `isLoaded` flag. Features `toggleFavorite()` and `loadFavorites()`.
│       ├── screens/
│       │   ├── clinic_doctors_screen.dart # Lists doctors by specific clinic.
│       │   ├── doctor_details_screen.dart 
│       │   │   # (1559 lines) The heaviest UI. Local states: `_isNavigating`, `_routePoints`, `_distanceToClinic`, `_isDistanceBarExpanded`, `_isUserPanning`. 
│       │   │   # FlutterMap implementation: Uses CartoDB Voyager tiles via OpenStreetMap. 
│       │   │   # Animations: Map height transition (`AnimatedContainer` 150px → 350px), Distance bar expansion, FAB reveal (`AnimatedSize`), and FAB open/close rotation (`AnimatedRotation` 180°).
│       │   ├── doctors_screen.dart # Tab 1. Main filterable directory.
│       │   ├── featured_doctors_screen.dart # Filtered list.
│       │   ├── my_doctors_screen.dart # Maps `FavoritesNotifier` to list view.
│       │   ├── popular_doctors_screen.dart # Filtered list.
│       │   └── specialty_doctors_screen.dart # Doctors separated by specialty.
│       └── widgets/
│           ├── doctor_appointment_card.dart # In-profile appointment list item.
│           ├── doctor_details_header.dart # Hero rendering for avatar, name, and specialty.
│           ├── doctor_stats_row.dart # Visual stat layout (Experience, patients, rating).
│           └── doctor_timing_list.dart # UI for schedule availability.
│
├── home/
│   ├── data/home_repository.dart # Pulls specialties, banners, and doctor arrays via Supabase RPCs.
│   └── presentation/screens/home_screen.dart # (441 lines) The dashboard integrating `CustomSearchBar`, promotional banner card, specialties grid, and horizontal scrolling cards. Implements pull-to-refresh.
│
├── legal/
│   └── presentation/screens/terms_of_service_screen.dart # Renders ToS content.
│
├── medical_records/
│   ├── data/
│   │   ├── medical_record.dart # `MedicalRecord` Freezed model.
│   │   └── medical_record_repository.dart # File upload to `supabase.storage` and row CRUD. Designed to throw `Requires2FAException` if AAL2 evaluates false.
│   └── presentation/screens/
│       ├── add_record_screen.dart # Upload form interface utilizing `image_picker`.
│       └── medical_records_screen.dart # (563 lines) Security-gated UI. Fallback sequence: Forces setup if no security exists; optionally suggests biometric; fetches using `allowAal1Bypass` if biometric succeeds; pushes to full 2FA verify on failure. Supports in-app image viewing and PDF document downloading.
│
├── menu/ & settings/
│   ├── data/settings_repository.dart # Handles Supabase MFA API calls and RPCs for recovery code generation.
│   ├── presentation/
│   │   ├── settings_notifier.dart # Persisted state: `themeMode`, `inactivityTimeoutMs`, `showDrawerHint`, `notificationsEnabled`. Features `setThemeMode()`, `clear()`, and `loadSettings()`.
│   │   ├── screens/
│   │   │   ├── linked_accounts_screen.dart # Connects/disconnects Google OAuth identity.
│   │   │   ├── privacy_policy_screen.dart # Renders privacy copy.
│   │   │   └── settings_screen.dart 
│   │   │       # (2585 lines) The largest file. Uses `StatefulBuilder` within `showDialog()` for local dialog states. 
│   │   │       # Local state variables: `_is2FAEnabled`, `_hasRecoveryCodes`, `_isBiometricEnabled`, `_verifiedFactorId`, `_is2FAToggleBusy`.
│   │   │       # Workflows: Calls `_verifyRecentMfaForSensitiveAction()` (falling back to biometric Step-Up) before allowing account deletion, password changes, or MFA toggles. 
│   │   │       # 2FA Wizard: Animates an `AnimatedSwitcher` through Info → QR → Backup codes → Success steps.
│   │   └── widgets/custom_drawer.dart # Content layout for the drawer (User info, setting tiles). Sliding animation controlled by `MainWrapper`.
│
├── profile/
│   ├── data/
│   │   ├── profile_repository.dart # Manages `profiles` table and `supabase.storage` avatar uploads.
│   │   └── user_profile.dart # `UserProfile` model class.
│   └── presentation/
│       ├── profile_notifier.dart # Singleton state holding `fullName`, `avatarUrl`, and `currencySymbol`. Populated via `hydrate()` post-login.
│       └── screens/profile_screen.dart # (639 lines) Input fields for phone, DOB, blood group. Incorporates `Geolocator` reverse geocoding for location assignment. Triggers unsaved changes dialog.
│
├── splash/
│   └── presentation/screens/splash_screen.dart # Shows gradient (`primaryGreen` at 10% opacity) and logo statically for 2 seconds. Evaluates `AuthEntryRouteService` logic to redirect.
│
└── support/
    └── presentation/screens/help_center_screen.dart # FAQ/Help Desk UI.

```

---

## 3. Shared Presentation Widgets (`lib/presentation/widgets/`)

```text
├── app_network_image.dart # Displays network images, rendering a fallback icon upon error.
├── app_text_field.dart # Primary input field implementation.
├── appointment_card.dart # Shared UI for generic appointment listing.
├── auth_code_input.dart # UI component specifically sizing digit boxes for 6-digit TOTP and 8-character recovery codes.
├── auth_text_field.dart # Input field uniquely styled for login/signup backgrounds.
├── custom_search_bar.dart # Search bar containing specific prefix/suffix icon designs; triggers navigation to `DoctorsScreen`.
├── custom_snackbar.dart # Manages built-in Material animations to present Success, Error, Info, or Warning alerts.
├── custom_text_field.dart # Alternative customized input variant.
├── doctor_list_card.dart # Vertically oriented doctor display card.
├── featured_doctor_card.dart # Horizontally oriented doctor card.
├── home_featured_doctor_card.dart # Compact variant specifically designed to fit the `HomeScreen` dashboard list.
├── home_popular_doctor_card.dart # Compact variant for popular dashboard listings.
├── pessimistic_switch.dart # A toggle switch that prevents visual state changes until an asynchronous backend callback returns true.
├── primary_button.dart # Implements the main `#00C689` CTA button utilizing `AppShapes.lg` border radius and handling internal loading states.
└── social_button.dart # Specially styled buttons explicitly meant for third-party OAuth flows like Google Sign-In.

```
