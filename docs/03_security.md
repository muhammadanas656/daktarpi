# DaktarPai - Security

## 1. Current Security Layers

The implemented security model combines:

- device integrity checks before normal app startup
- authenticated route protection through `GoRouter`
- TOTP-based MFA step-up with backup-code fallback
- trusted-device bypass for remembered devices
- trusted-device biometrics for sensitive actions and inactivity unlock
- secure local caches for selected sensitive data
- online-only restrictions for uploads, signed URLs, and live slot checks

## 2. Device Integrity on Startup

`DeviceIntegrityService.enforceOnStartup()` runs before `MyApp` is shown.

- The service uses the platform method channel `com.daktarpi/device_integrity`
- If a device is reported as compromised, `FlutterSecureStorage` is wiped on a best-effort basis
- The current Supabase session is signed out
- The user is shown a blocked compromised-device shell instead of the normal app

This startup path is fail-open on platform exceptions and unsupported platforms, but fail-closed when the native layer explicitly reports compromise.

## 3. Session and Route Protection

Security-relevant auth state is centralized in `AuthRepository`.

Current route enforcement rules:

- Unauthenticated users are redirected to `/login?from=...` when opening protected routes
- Signed-in users can still be routed to `/verify-2fa` when the session is `aal1` but 2FA is enabled
- Signed-in users without DOB metadata are forced through `/profile/edit`

`SecurityGateService` wraps the AAL2 step-up decision and the TOTP / backup-code verification calls used across the app.

## 4. MFA, Backup Codes, and Trusted Devices

### MFA

- `SettingsScreen` contains the current TOTP enrollment and removal flow
- Authenticator verification uses Supabase MFA factors
- Backup codes are stored and consumed through Supabase RPCs rather than local files
- `Verify2FAScreen` supports both 6-digit authenticator codes and 8-character backup codes

### Trusted devices

Trusted-device state lives in `TrustedDeviceRepository`.

- The raw trust token is stored only on-device in `FlutterSecureStorage`
- Supabase stores only a SHA-256 hash plus expiry in `trusted_devices`
- Default trust TTL is 30 days
- A valid trusted device can bypass `/verify-2fa`
- The trusted-device row can also store whether biometric login is enabled for that device

## 5. Biometrics and Session Locking

Two biometric services exist for different jobs:

- `BiometricAuthService`
  Lightweight biometric availability and unlock prompts used by inactivity locking and trusted-device flows
- `BiometricSecurityService`
  Higher-level biometric verification that throws `AppFailure` on denial or missing capability

Current biometric behavior:

- Biometric login is only exposed in Settings when hardware is available and 2FA is already enabled
- Enabling biometric login re-trusts the current device with `is_biometric_enabled = true`
- Sensitive account actions can use trusted-device biometrics as a shortcut before falling back to TOTP or backup-code entry

`InactivityLockGuard` auto-locks the app only when all of the following are true:

- a user session exists
- trusted-device biometrics are available for the current user on the current device
- the inactivity timeout is greater than `0`

Current inactivity-lock behavior:

- the routed app is covered by a lock overlay rather than a separate route
- unlock requires biometric authentication
- locking also forces `SettingsNotifier.medicalRecordsLocked = true`
- an absolute session timeout signs the user out and sends them to `/login`

## 6. Medical Records Protection

Medical records have a second local protection layer beyond auth.

- The lock/unlock control lives on `MedicalRecordsScreen`, not in Settings
- The control is available only when either 2FA or device biometrics are configured
- Toggling the lock requires biometric verification
- When locked, the records screen hides list content and disables the add-record bottom bar

This protection is a UI/data-access gate inside the app. It does not replace backend authorization.

## 7. Sensitive Actions and AAL2 Step-Up

`SettingsScreen` and `LinkedAccountsScreen` both enforce step-up before destructive or high-impact actions.

Actions currently gated this way include:

- enabling or disabling biometrics
- enabling or disabling 2FA
- changing password
- linking or unlinking email / Google identities
- deleting the account

The step-up path is:

1. evaluate AAL2 gate
2. attempt trusted-device biometric shortcut
3. if needed, show TOTP / backup-code modal

## 8. Local Data Protection

The app uses secure local storage for selected sensitive caches:

- appointment cache
- profile cache
- booking draft
- trusted-device token

Other local data is less sensitive or less strictly protected:

- notifications, repository caches, and offline queues live in Hive
- settings and recent searches live in `SharedPreferences`
- opened medical-record attachments are cached in the app documents directory after first download

That last point matters: in-app record locking hides records in the UI, but previously downloaded attachment files can still exist locally inside the app sandbox.

## 9. Online-Only Security Boundaries

These operations intentionally require a live backend today:

- profile picture upload
- medical file upload
- medical signed URL generation
- live appointment slot checks
- global route-proxy fallback calls for in-app driving directions

The app also sends client error payloads to the `client-error-log` edge function and stores the FCM token on the user profile once push permission is granted.
