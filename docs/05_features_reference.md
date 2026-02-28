# DaktarPai — Features Reference

Every feature module follows the same structure: `data/` (models + repositories), `presentation/screens/` (UI), `presentation/widgets/` (feature-specific widgets), and optionally a notifier.

---

## 1. Splash

**Directory:** `lib/features/splash/`

| File | Purpose |
|---|---|
| [splash_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/splash/presentation/screens/splash_screen.dart) | App entry screen. Shows logo + brand name for 2 seconds, then calls `AuthEntryRouteService.resolvePostAuthRoute()` to redirect to login, verify-2fa, or home. |

---

## 2. Auth

**Directory:** `lib/features/auth/`

### Data Layer

| File | Description |
|---|---|
| [auth_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/data/auth_repository.dart) | Central auth wrapper around Supabase Auth. 25 methods covering sign-up, sign-in, OAuth, MFA, password, account deletion, file management. |
| [auth_entry_route_service.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/data/auth_entry_route_service.dart) | Determines post-auth route (login/verify-2fa/home) |
| [auth_route_resolver.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/data/auth_route_resolver.dart) | Pure logic for route resolution (testable) |
| [security_gate_service.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/data/security_gate_service.dart) | AAL2 gate evaluation, TOTP/recovery code verification |
| [trusted_device_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/data/trusted_device_repository.dart) | Trusted device token management (UUID + SHA-256 hashing, 30-day TTL, FlutterSecureStorage) |
| [trusted_device_service.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/data/trusted_device_service.dart) | Higher-level trusted device operations |

### Presentation Layer

| File | Description |
|---|---|
| [login_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/presentation/screens/login_screen.dart) | 805 lines. Email/password login, Google OAuth, forgot password bottom sheet (3-step: email → OTP → new password), link animations. |
| [signup_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/presentation/screens/signup_screen.dart) | 318 lines. Full name, email, password, confirm password fields. Terms of Service acceptance. |
| [verify_2fa_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/presentation/screens/verify_2fa_screen.dart) | 517 lines. TOTP 6-digit code or 8-char backup code entry. AnimatedCrossFade between modes, remember device checkbox, recovery assist timer. |
| [verify_2fa_route_args.dart](file:///C:/skills%20development/daktarpi/lib/features/auth/presentation/models/verify_2fa_route_args.dart) | Route args: `popOnSuccess`, `markAsTrustedDevice` |

---

## 3. Home

**Directory:** `lib/features/home/`

| File | Description |
|---|---|
| [home_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/home/data/home_repository.dart) | Fetches home screen data using `userCountryIso` to prevent regional leakage. |
| [home_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/home/presentation/screens/home_screen.dart) | 441 lines. Dashboard layout: header with greeting + profile avatar, search bar, promotional banner, specialties grid, popular doctors horizontal list, featured doctors horizontal list, upcoming appointment card. Pull-to-refresh. |

### Home Screen Sections

1. **Header:** User greeting ("Hi, {name}!") + notification icon + profile avatar
2. **Search bar:** `CustomSearchBar` → navigates to DoctorsScreen with search
3. **Banner:** Promotional card with gradient background
4. **Specialties:** Grid of specialty icons (fallback icons for missing images)
5. **Popular doctors:** Horizontal scroll of `HomePopularDoctorCard`
6. **Featured doctors:** Horizontal scroll of `HomeFeaturedDoctorCard`

---

## 4. Doctors

**Directory:** `lib/features/doctors/`

### Data Layer

| File | Description |
|---|---|
| [doctor.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/data/doctor.dart) | `Doctor` Freezed model (Includes `countryIso` for geographic isolation) |
| [clinic.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/data/clinic.dart) | `Clinic` Freezed model |
| [specialty.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/data/specialty.dart) | Specialty model |
| [doctor_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/data/doctor_repository.dart) | Doctor CRUD, search, filtering. Extensively uses `.eq('country_iso', userCountryIso)` to segregate data by user's region. |
| [route_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/data/route_repository.dart) | OpenRouteService API for driving directions (polyline) |

### Presentation Layer — Screens

| Screen | Lines | Description |
|---|---|---|
| [doctors_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/doctors_screen.dart) | Tab 1 | Main doctor listing with filters |
| [doctor_details_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/doctor_details_screen.dart) | 1559 | Full doctor profile: header, stats, schedule, multi-clinic selector, FlutterMap with navigation, booking CTA |
| [featured_doctors_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/featured_doctors_screen.dart) | | Featured doctors list |
| [popular_doctors_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/popular_doctors_screen.dart) | | Popular doctors list |
| [specialty_doctors_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/specialty_doctors_screen.dart) | | Doctors by specialty |
| [clinic_doctors_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/clinic_doctors_screen.dart) | | Doctors by clinic |
| [my_doctors_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/screens/my_doctors_screen.dart) | | User's favorited doctors |

### Presentation Layer — Widgets

| Widget | Description |
|---|---|
| [doctor_details_header.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/widgets/doctor_details_header.dart) | Hero section with avatar, name, specialty |
| [doctor_stats_row.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/widgets/doctor_stats_row.dart) | Experience, patients, rating stats |
| [doctor_timing_list.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/widgets/doctor_timing_list.dart) | Availability schedule display |
| [doctor_appointment_card.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/widgets/doctor_appointment_card.dart) | Appointment card within doctor view |

### Doctor Details — Map & Navigation

The `DoctorDetailsScreen` includes an embedded FlutterMap with:
- **Map provider:** CartoDB Voyager tiles via OpenStreetMap
- **Markers:** Clinic (green with gradient) + User (blue with navigation icon)
- **Route polyline:** Blue line from user to clinic (via OpenRouteService API)
- **Distance bar:** Floating overlay showing distance (km/m), animated expansion during "Calculating..." states.
- **Floating action buttons:** expandable menus for navigation controls (center clinic, center user, route overview) and direction launch (external maps, in-app navigation). Smoothly animates into a standard FAB when panning.

State management: `_isNavigating`, `_routePoints`, `_distanceToClinic`, `_isDistanceBarExpanded`, `_isUserPanning`, `_isMenuOpen`, `_isLocatorMenuOpen`

### FavoritesNotifier

**File:** [favorites_notifier.dart](file:///C:/skills%20development/daktarpi/lib/features/doctors/presentation/favorites_notifier.dart)

Singleton `ChangeNotifier` managing doctor favorites (Set of IDs). Has `clear()` for logout.

---

## 5. Appointments

**Directory:** `lib/features/appointments/`

### Data Layer

| File | Description |
|---|---|
| [appointment.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/data/appointment.dart) | `Appointment` Freezed model |
| [appointment_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/data/appointment_repository.dart) | CRUD operations for appointments (Supabase) |
| [appointment_secure_cache_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/data/appointment_secure_cache_repository.dart) | Local encrypted cache for offline viewing |
| [booking_draft_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/data/booking_draft_repository.dart) | Persists booking drafts during the flow |

### Presentation Layer

| File | Description |
|---|---|
| [my_appointments_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/presentation/screens/my_appointments_screen.dart) | 571 lines. Lists upcoming/past appointments with Supabase realtime subscription. Actions: cancel, complete, reschedule. Canceling/Completing directly removes local push notification alarms. |
| [patient_details_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/presentation/screens/patient_details_screen.dart) | Booking flow (Step 1): parses relational `saved_patients` into UI components (draggable avatars) to capture form details. Passes mapped data downstream. |
| [appointment_confirmation_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/presentation/screens/appointment_confirmation_screen.dart) | Booking flow (Step 2): Displays calendar tools and chip-based reminder selectors. Commits DB insertion and schedules exact alarms using `flutter_local_notifications`. |
| [appointment_notifier.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/presentation/appointment_notifier.dart) | State management for appointment list |
| [booking_route_args.dart](file:///C:/skills%20development/daktarpi/lib/features/appointments/presentation/models/booking_route_args.dart) | Route args: doctor, clinic, patient details map, idempotency key |

### Realtime Updates

`MyAppointmentsScreen` subscribes to a Supabase realtime channel on the `appointments` table, so the list updates automatically when appointment status changes (e.g., doctor confirms).

---

## 6. Medical Records

**Directory:** `lib/features/medical_records/`

### Data Layer

| File | Description |
|---|---|
| [medical_record.dart](file:///C:/skills%20development/daktarpi/lib/features/medical_records/data/medical_record.dart) | `MedicalRecord` Freezed model |
| [medical_record_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/medical_records/data/medical_record_repository.dart) | Record CRUD + file upload to Supabase Storage. Throws `Requires2FAException` when AAL2 is required. |

### Presentation Layer

| File | Description |
|---|---|
| [medical_records_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/medical_records/presentation/screens/medical_records_screen.dart) | 563 lines. Security-gated record list with biometric/2FA verification. File viewing (image viewer, PDF, document download). Delete with confirmation. |
| [add_record_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/medical_records/presentation/screens/add_record_screen.dart) | Form for adding/editing records with file upload |

---

## 7. Profile

**Directory:** `lib/features/profile/`

### Data Layer

| File | Description |
|---|---|
| [user_profile.dart](file:///C:/skills%20development/daktarpi/lib/features/profile/data/user_profile.dart) | `UserProfile` model (`countryIso`, `currencySymbol`) |
| [profile_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/profile/data/profile_repository.dart) | Fetch/update core profile + CRUD operations for the secondary `saved_patients` table. Avatar upload logic. |

### Presentation Layer

| File | Description |
|---|---|
| [profile_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/profile/presentation/screens/profile_screen.dart) | 639 lines. Edit profile: retrieves rigorous `countryIso` codes via reverse geocoding/pickers. Validates and manages nested family member records. |
| [profile_notifier.dart](file:///C:/skills%20development/daktarpi/lib/features/profile/presentation/profile_notifier.dart) | Singleton `ChangeNotifier` for profile data. Holds the vital `userCountryIso` driving app-wide regional segregation. |

---

## 8. Settings

**Directory:** `lib/features/settings/` + `lib/features/menu/`

### Data Layer

| File | Description |
|---|---|
| [settings_repository.dart](file:///C:/skills%20development/daktarpi/lib/features/menu/data/settings_repository.dart) | Server-side settings operations: MFA management, session refresh, recovery codes |

### Presentation Layer

| File | Description |
|---|---|
| [settings_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/menu/presentation/screens/settings_screen.dart) | 2585 lines (largest file). Full settings UI: account security (password, 2FA, biometrics, recovery codes, linked accounts, forget device), preferences (notifications, inactivity lock, theme, currency, drawer hint), support/legal, sign out, delete account. |
| [privacy_policy_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/menu/presentation/screens/privacy_policy_screen.dart) | Privacy policy display |
| [linked_accounts_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/menu/presentation/screens/linked_accounts_screen.dart) | Google account linking/unlinking |
| [custom_drawer.dart](file:///C:/skills%20development/daktarpi/lib/features/menu/presentation/widgets/custom_drawer.dart) | Navigation drawer with user info, menu items |
| [settings_notifier.dart](file:///C:/skills%20development/daktarpi/lib/features/settings/presentation/settings_notifier.dart) | Singleton `ChangeNotifier`. Manages: themeMode, inactivityTimeoutMs, drawerHintShown, notificationsEnabled. Has `loadSettings()`, `clear()`. |

---

## 9. Support & Legal

| File | Description |
|---|---|
| [help_center_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/support/presentation/screens/help_center_screen.dart) | FAQ and support content |
| [terms_of_service_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/legal/presentation/screens/terms_of_service_screen.dart) | Terms of service display |
| [legal_text.dart](file:///C:/skills%20development/daktarpi/lib/core/constants/legal_text.dart) | Legal text constants |

---

## 10. Common

| File | Description |
|---|---|
| [enable_location_screen.dart](file:///C:/skills%20development/daktarpi/lib/features/common/presentation/screens/enable_location_screen.dart) | Location permission request screen |
