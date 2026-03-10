# DaktarPai - App Flow and Navigation

## 1. Startup and Entry Routing

Startup currently works like this:
1. `main.dart` initializes app services.
2. The router opens `/`, which renders `SplashScreen`.
3. `SplashScreen` waits 2 seconds, then asks `AuthEntryRouteService` for the next route.

`AuthRouteResolver` and `AuthEntryRouteService` currently resolve post-auth navigation as follows:

| Condition | Route |
|---|---|
| No session | `/login` |
| Signed in, AAL2 step-up required | `/verify-2fa` |
| Signed in, no DOB in user metadata | `/profile/edit` |
| Signed in, auth and profile checks passed | `/home` |

Trusted-device behavior:
- If the resolved route is `/verify-2fa` and the current device is still trusted, the app skips the TOTP screen.
- After that bypass, the next route is `/home` or `/profile/edit` depending on profile completion.
- An intended route from the login redirect is reused only when the final destination would otherwise be `/home`.

## 2. Router Guard

`GoRouter` has a top-level redirect for authenticated access:
- unauthenticated users can visit `/`, `/login`, `/signup`, and `/verify-2fa`
- any other route redirects to `/login?from=...`

This means deep links into protected screens preserve the original target path for reuse after login.

## 3. Route Map

Current route constants live in `lib/core/constants/app_routes.dart`.

### Public and auth

| Path | Screen |
|---|---|
| `/` | `SplashScreen` |
| `/login` | `LoginScreen` |
| `/signup` | `SignUpScreen` |
| `/verify-2fa` | `Verify2FAScreen` |

### Shell tabs

These are hosted inside `MainWrapper`:

| Path | Screen |
|---|---|
| `/home` | `HomeScreen` |
| `/doctors` | `DoctorsScreen` |
| `/appointments` | `MyAppointmentsScreen` |
| `/profile` | `ProfileViewScreen` |

### Standalone routes

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

## 4. Main User Flows

### Auth flow

- Login supports email/password and Google sign-in.
- Forgot-password is handled from a bottom sheet and uses an 8-digit recovery OTP flow.
- If MFA step-up is required, the app routes to `Verify2FAScreen`.

### Doctor discovery flow

- Home can send users to global search, popular doctors, featured doctors, specialty lists, clinic lists, and doctor details.
- The doctors tab is the main list-first browsing surface.

### Booking and reschedule flow

The current booking path is:
1. doctor/clinic selection
2. `/appointment_booking` for patient details
3. `/payment_method` for date and slot selection
4. `/dummy_payment` for the final simulated checkout and appointment write

Reschedules reuse the same latter steps with an existing appointment id.

### Profile and account flow

- `/profile` is the shell tab.
- `/profile/edit` is pushed as a full-screen edit flow.
- Settings, account activity, notifications, linked accounts, help, privacy policy, and terms are separate root-level routes.

## 5. MainWrapper Behavior

`MainWrapper` is more than a tab scaffold:
- it hosts the 4 shell branches
- it renders the custom drawer and drawer animation
- it starts appointment realtime initialization
- it refreshes appointments and profile data on app resume
