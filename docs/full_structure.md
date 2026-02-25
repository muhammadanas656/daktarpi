DaktarPai — Exhaustive Directory & File Profile Map (Updated)
1. Root & Core Application Structure
Plaintext
lib/
├── main.dart 
│   # App Entry: Calls `WidgetsFlutterBinding.ensureInitialized()`, loads `.env`, initializes Supabase. 
│   # Startup logic: Calls `SettingsNotifier.loadSettings()`, `AppointmentNotificationService.initialize()`, `DeviceIntegrityService.enforceOnStartup()`. 
│   # Security fallback: Renders `_CompromisedDeviceApp` if device integrity fails; otherwise, runs `runApp(MyApp)`.
│
├── app.dart 
│   # MaterialApp Wrapper: Implements `MaterialApp.router` with `AppTheme` and `appRouter`. 
│   # Listeners: Uses `AnimatedBuilder` for theme changes via `SettingsNotifier.instance`. 
│   # Global Guards: Wraps application in `OfflineModeGuard` and `InactivityLockGuard`.
│
├── core/
│   ├── constants/
│   │   └── legal_text.dart # Stores raw string constants for legal text.
│   ├── errors/
│   │   └── app_failure.dart # Typed error class (userMessage, isRequiresRecentMfa, error factories).
│   ├── localization/
│   │   └── app_localizations.dart # Handles translations for English (`en_US`) and Bengali (`bn_BD`).
│   ├── main_wrapper/
│   │   └── main_wrapper.dart 
│   │       # Shell Navigation: `StatefulShellRoute.indexedStack` for 4 branches (Home, Doctors, Appointments, Profile).
│   │       # Drawer Animation: `AnimationController` and `GestureDetector` for swipe-to-reveal content scaling.
│   │       # Nav Indicator: `AnimatedPositioned` for bottom nav selection.
│   ├── network/
│   │   └── offline_mode_guard.dart # Monitors connectivity with animated yellow banner.
│   ├── router/
│   │   ├── app_router.dart # Defines GoRouter tables and global unauthenticated redirect logic.
│   │   └── auth_refresh_stream.dart # Wraps `onAuthStateChange` into a `ChangeNotifier`.
│   ├── security/
│   │   ├── biometric_auth_service.dart # Wraps `local_auth` for secure biometric operations.
│   │   ├── biometric_helper_service.dart # High-level biometric operation helpers.
│   │   ├── biometric_security_service.dart # Extra security-focused utilities for biometrics.
│   │   ├── device_integrity_service.dart # Root/jailbreak checks via MethodChannel; wipes storage on failure.
│   │   ├── inactivity_lock_guard.dart # Enforces session timeouts with overlay and auto-biometric unlock.
│   │   └── sensitive_action_step_up_service.dart # Bypasses TOTP via biometric/trusted device checks.
│   ├── services/
│   │   ├── appointment_notification_service.dart # Singleton for local notifications.
│   │   └── error_telemetry_service.dart # Captures errors from FlutterError, PlatformDispatcher, and Zones.
│   ├── theme/
│   │   ├── app_colors.dart # Hex constants (primaryGreen: #00C689, dangerRed: #E53935, etc.).
│   │   ├── app_dimens.dart # Stores page padding and elevation levels.
│   │   ├── app_motion.dart # Timings (200-400ms) and Curves.
│   │   ├── app_shapes.dart # Standardized BorderRadius (sm, md, lg).
│   │   ├── app_styles.dart # Predefined Decorations (surfaceCard, pageGradient).
│   │   ├── app_text_styles.dart # Google Fonts Poppins weights (h1 24px Bold, button 16px SemiBold).
│   │   └── app_theme.dart # Material 3 ThemeData for Light/Dark modes.
│   ├── utils/
│   │   ├── backup_code_formatter.dart # TextInputFormatter for XXXX-XXXX rendering.
│   │   ├── navigation_helper.dart # Helper navigation functions.
│   │   └── security_formatters.dart # Input formatting and clipboard detection.
│   └── widgets/
│       ├── app_error_fallback.dart # Red error screen override with "Go Home" button.
│       └── route_error_screen.dart # 404/invalid route UI.
│
├── data/
│   └── services/user_service.dart # Shared generic user utilities.
2. Feature Modules Structure (lib/features/)
Plaintext
├── appointments/
│   ├── data/
│   │   ├── appointment.dart # Freezed model for appointments.
│   │   ├── appointment_repository.dart # Supabase CRUD operations on the `appointments` table.
│   │   ├── appointment_secure_cache_repository.dart # Local encrypted caching for offline viewing.
│   │   └── booking_draft_repository.dart # Caches multi-step booking data locally.
│   └── presentation/
│       ├── appointment_notifier.dart # Singleton state with Realtime subscription logic.
│       ├── models/booking_route_args.dart # Carries doctor, clinic, and slot data through flow.
│       └── screens/
│           ├── appointment_confirmation_screen.dart # Step 2 of booking (Payment/Confirmation).
│           ├── my_appointments_screen.dart # Real-time list; action sheets for cancel/reschedule.
│           └── patient_details_screen.dart # Step 1 of booking (Form input).
│
├── auth/
│   ├── data/
│   │   ├── auth_entry_route_service.dart # Evaluates session for login/2FA/home redirection.
│   │   ├── auth_repository.dart # Core hub for signup, Google OAuth, password reset, and session management.
│   │   ├── auth_route_resolver.dart # Pure logic decoupling for auth routing tests.
│   │   ├── security_gate_service.dart # Evaluates Aal2 Step-Up needs (TOTP/Recovery code).
│   │   ├── trusted_device_repository.dart # Generates UUID and stores SHA-256 hash server-side.
│   │   └── trusted_device_service.dart # High-level operations for devices.
│   └── presentation/
│       ├── models/verify_2fa_route_args.dart # Configuration args for 2FA screen.
│       └── screens/
│           ├── login_screen.dart # Email/Pass and Google login; 3-step animated forgot password sheet.
│           ├── signup_screen.dart # Registration and ToS acceptance.
│           └── verify_2fa_screen.dart # OTP/Recovery code crossfade with clipboard detection.
│
├── common/
│   └── presentation/screens/enable_location_screen.dart # Location permission interface.
│
├── doctors/
│   ├── data/
│   │   ├── clinic.dart # Clinic Freezed model.
│   │   ├── doctor.dart # Doctor Freezed model (Updated: includes `countryIso`).
│   │   ├── doctor_repository.dart # Updated: Search/Filter logic now uses `country_iso` eq filters.
│   │   ├── route_repository.dart # OpenRouteService API wrapper for driving polylines.
│   │   └── specialty.dart # Specialty Freezed model.
│   └── presentation/
│       ├── favorites_notifier.dart # Singleton ChangeNotifier for favorite doctor state.
│       ├── screens/
│       │   ├── clinic_doctors_screen.dart # Lists doctors by specific clinic.
│       │   ├── doctor_details_screen.dart 
│       │   │   # Map integration with CartoDB Voyager; animated FAB and Distance bar expansion.
│       │   ├── doctors_screen.dart # Main directory; pulls state using `ProfileNotifier.userCountryIso`.
│       │   ├── featured_doctors_screen.dart # Country-filtered featured list.
│       │   ├── my_doctors_screen.dart # Maps FavoritesNotifier to list view.
│       │   ├── popular_doctors_screen.dart # Country-filtered popular list.
│       │   └── specialty_doctors_screen.dart # Doctors separated by specialty.
│       └── widgets/
│           ├── doctor_appointment_card.dart # In-profile appointment list item.
│           ├── doctor_details_header.dart # Hero avatar/specialty header.
│           ├── doctor_stats_row.dart # Visual stat layout (Experience, patients, rating).
│           └── doctor_timing_list.dart # UI for schedule availability.
│
├── home/
│   ├── data/home_repository.dart # Pulls specialties/banners; Updated to accept `countryIso` parameter for RPC calls.
│   └── presentation/screens/home_screen.dart # Dashboard with pull-to-refresh; dashboard data fetched based on user country.
│
├── legal/
│   └── presentation/screens/terms_of_service_screen.dart # Renders ToS content.
│
├── medical_records/
│   ├── data/
│   │   ├── medical_record.dart # MedicalRecord Freezed model.
│   │   └── medical_record_repository.dart # Storage/CRUD with Aal2 security enforcement.
│   └── presentation/screens/
│       ├── add_record_screen.dart # Upload form with image_picker.
│       └── medical_records_screen.dart # Security-gated UI (Biometric/Aal1 fallback sequence).
│
├── menu/ & settings/
│   ├── data/settings_repository.dart # MFA API calls and recovery code generation.
│   ├── presentation/
│   │   ├── settings_notifier.dart # Persisted UI state (theme, timeout, notifications).
│   │   ├── screens/
│   │   │   ├── linked_accounts_screen.dart # Google OAuth identity management.
│   │   │   ├── privacy_policy_screen.dart # Renders privacy copy.
│   │   │   └── settings_screen.dart 
│   │   │       # MFA toggle wizard; sensitive action step-up workflows.
│   │   └── widgets/custom_drawer.dart # Drawer content with sliding animation via MainWrapper.
│
├── profile/
│   ├── data/
│   │   ├── profile_repository.dart # Manages `profiles` table and avatar storage.
│   │   └── user_profile.dart # Freezed model (Updated: includes `countryIso` and `countryCode`).
│   └── presentation/
│       ├── profile_notifier.dart # Updated: Holds `userCountryIso` as global state for repository filtering.
│       └── screens/profile_screen.dart # Updated: Extracts ISO country code from GPS/Geolocator and CountryCodePicker.
│
├── splash/
│   └── presentation/screens/splash_screen.dart # Logo animation; evaluates post-auth routing logic.
│
└── support/
    └── presentation/screens/help_center_screen.dart # FAQ/Help Desk UI.
3. Shared Presentation Widgets (lib/presentation/widgets/)
Plaintext
├── app_network_image.dart # Network image loader with fallback icon.
├── app_text_field.dart # Primary text input.
├── appointment_card.dart # Generic appointment list item.
├── auth_code_input.dart # Sized digit boxes for TOTP and recovery codes.
├── auth_text_field.dart # Styled input for auth backgrounds.
├── custom_search_bar.dart # Search bar with prefix/suffix icons.
├── custom_snackbar.dart # Animated Success/Error/Info alerts.
├── custom_text_field.dart # Alternative customized input variant.
├── doctor_list_card.dart # Vertical doctor display.
├── featured_doctor_card.dart # Horizontal doctor display.
├── home_featured_doctor_card.dart # Compact dashboard featured card.
├── home_popular_doctor_card.dart # Compact dashboard popular card.
├── pessimistic_switch.dart # Toggle switch with async callback protection.
├── primary_button.dart # Main Green CTA (#00C689) with internal loading states.
└── social_button.dart # Styled buttons for Google OAuth flows.