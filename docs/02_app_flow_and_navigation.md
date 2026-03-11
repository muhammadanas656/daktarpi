# DaktarPai - App Flow and Navigation

## 1. Entry Routing

Startup navigation is driven by `SplashScreen` plus `AuthEntryRouteService`.

1. The app boots into `/`
2. `SplashScreen` waits 2 seconds
3. `AuthEntryRouteService.resolvePostAuthRoute()` decides the next screen

Current entry-routing rules are:

| Condition | Destination |
|---|---|
| No active session | `/login` |
| Signed in and AAL2 step-up still required | `/verify-2fa` |
| Signed in but auth metadata still lacks DOB | `/profile/edit` |
| Signed in, cleared security gate, and profile looks complete | `/home` |

Trusted-device bypass is applied after the basic route decision:

- If the initial target is `/verify-2fa` and the current device is still trusted, the app skips the TOTP screen.
- After bypass, the app lands on `/home` or `/profile/edit`.
- The `from=` query parameter captured during login is reused when the final destination would otherwise be `/home`.

## 2. Router Guard Model

`appRouter` uses a top-level redirect tied to Supabase auth state.

- Public routes are `/`, `/login`, `/signup`, and `/verify-2fa`
- Everything else requires an authenticated session
- Unauthenticated access to a protected route redirects to `/login?from=...`

Most non-tab screens are pushed on the root navigator with `parentNavigatorKey: _rootNavigatorKey`, so they appear above the tab shell instead of nesting inside a branch stack.

## 3. Route Inventory

Current route constants live in `lib/core/constants/app_routes.dart`.

### Public and auth

| Path | Screen |
|---|---|
| `/` | `SplashScreen` |
| `/login` | `LoginScreen` |
| `/signup` | `SignUpScreen` |
| `/verify-2fa` | `Verify2FAScreen` |

### Shell branches inside `MainWrapper`

| Path | Screen |
|---|---|
| `/home` | `HomeScreen` |
| `/doctors` | `DoctorsScreen` |
| `/appointments` | `MyAppointmentsScreen` |
| `/profile` | `ProfileViewScreen` |

### Root-level pushed routes

| Path | Screen |
|---|---|
| `/profile/edit` | `ProfileScreen` |
| `/global_search` | `GlobalSearchScreen` |
| `/popular_doctors` | `PopularDoctorsScreen` |
| `/featured_doctors` | `FeaturedDoctorsScreen` |
| `/my_doctors` | `MyDoctorsScreen` |
| `/medical_records` | `MedicalRecordsScreen` |
| `/add_medical_record` | `AddRecordScreen` |
| `/appointment_booking` | `PatientDetailsScreen` |
| `/payment_method` | `AppointmentConfirmationScreen` |
| `/dummy_payment` | `DummyPaymentScreen` |
| `/settings` | `SettingsScreen` |
| `/linked-accounts` | `LinkedAccountsScreen` |
| `/help-center` | `HelpCenterScreen` |
| `/terms_of_service` | `TermsOfServiceScreen` |
| `/privacy_policy` | `PrivacyPolicyScreen` |
| `/location_permission` | `EnableLocationScreen` |
| `/account_activity` | `AccountActivityScreen` |
| `/notifications` | `NotificationsScreen` |

### Parameterized routes

| Path | Screen |
|---|---|
| `/doctor_details/:id` | `DoctorDetailsScreen` |
| `/specialty_doctors/:id` | `SpecialtyDoctorsScreen` |
| `/clinic_doctors/:id` | `ClinicDoctorsScreen` |

## 4. Primary User Journeys

### Auth and recovery

- Login supports email/password and Google sign-in.
- Forgot-password is implemented as a bottom sheet with a three-step email recovery flow.
- The recovery flow uses an 8-digit email OTP and then password reset.
- MFA step-up uses `Verify2FAScreen`, which supports both authenticator codes and backup codes.

### Profile completion

- New email sign-ups go to `/profile/edit` immediately if a session is returned.
- Existing users missing DOB metadata are also redirected to `/profile/edit`.
- The profile form can request GPS permission through `/location_permission`.

### Doctor discovery

- `HomeScreen` links into global search, popular doctors, featured doctors, specialty doctor lists, clinic doctor lists, and doctor details.
- `DoctorsScreen` is the broad browsing surface with filter chips and facility grids.
- `DoctorDetailsScreen` is the bridge into booking.

### Booking and rescheduling

Current booking flow:

1. Doctor and clinic selection in doctor discovery surfaces
2. `/appointment_booking` for patient details and saved-patient selection
3. `/payment_method` for date and slot confirmation
4. `/dummy_payment` for the simulated checkout and final appointment write

Reschedules reuse step 3 and step 4 with an existing appointment id.

### Account, records, and support

- `/profile` is the tabbed profile home
- `/profile/edit` is a full-screen edit flow above the shell
- Medical records, settings, notifications, account activity, linked accounts, help, privacy, and terms are all separate root routes

## 5. `MainWrapper` Behavior

`MainWrapper` is more than a visual shell.

- Hosts the 4 `StatefulShellRoute` branches
- Renders the custom sliding/scaling drawer on top of the shell
- Starts appointment realtime and initial profile/appointment hydration in `initState()`
- Refreshes appointments and profile when the app returns to the foreground
- Shows an intro drawer hint animation on first-time startup when enabled in settings
- Intercepts back presses to close the drawer first, pop nested routes second, and exit the app when the user is already on a root tab

## 6. Route Data Conventions

Several routes rely on typed `extra` payloads rather than query parameters.

- `Verify2FAScreen` accepts `Verify2FARouteArgs`
- Booking and reschedule routes use typed booking argument objects
- `DoctorDetailsScreen` can receive a lightweight doctor map for instant handoff rendering before the full fetch completes
- `AddRecordScreen` accepts either `MedicalRecordRouteArgs` or a raw `MedicalRecord`
