# DaktarPai - Security

## 1. Security Layers in the Current App

The implemented security model combines:
- device integrity checks at startup
- authenticated route protection
- TOTP-based MFA step-up
- trusted-device bypass for remembered devices
- biometric unlock for local step-up and inactivity lock
- online-only gates for file and signed-URL operations

## 2. Startup Device Integrity

`DeviceIntegrityService.enforceOnStartup()` runs before the main app renders.

If the device is reported as compromised:
1. secure local storage is wiped
2. the Supabase session is signed out
3. the app shows a blocked compromised-device screen instead of the normal app shell

This wipe is best-effort and currently targets `FlutterSecureStorage`.

## 3. Auth and Route Protection

`AuthRepository` centralizes Supabase auth access.

Current route protection rules:
- unauthenticated users are redirected to `/login?from=...` when they try to open protected routes
- signed-in users may still be routed to `/verify-2fa` if AAL2 step-up is required
- signed-in users without DOB metadata are routed to `/profile/edit`

`SecurityGateService` wraps the current MFA gate logic for TOTP and backup-code verification.

## 4. MFA, Backup Codes, and Trusted Devices

Current MFA behavior:
- AAL2 step-up is required when 2FA is enabled but the current session is still `aal1`.
- `Verify2FAScreen` supports TOTP codes and recovery codes.
- The screen can optionally remember the current device.

Trusted-device implementation:
- raw device token is stored locally in `FlutterSecureStorage`
- Supabase stores only the SHA-256 token hash plus expiry in `trusted_devices`
- default device trust TTL is 30 days
- a valid trusted device can bypass `/verify-2fa`

## 5. Biometrics and Session Locking

`BiometricAuthService` only enables biometric flows when:
- the device supports biometrics
- at least one biometric method is available

`InactivityLockGuard` only auto-locks the app when:
- a user session exists
- biometric unlock is available for the current trusted device
- the inactivity timeout in `SettingsNotifier` is greater than `0`

Current lock behavior:
- lock state is shown as an overlay on top of the routed app
- unlocking uses biometric authentication
- locking also sets `SettingsNotifier.medicalRecordsLocked = true`
- an absolute session timeout signs the user out and sends them to `/login`

## 6. Medical Records Protection

Medical records have an additional local protection toggle:
- the lock toggle is available only when 2FA or device biometrics are configured
- toggling the lock requires biometric confirmation
- when locked, `MedicalRecordsScreen` hides record content and shows a protected state

## 7. Sensitive and Online-Only Operations

Several security-relevant operations intentionally require a live backend:
- profile picture upload
- medical file upload
- medical file signed URL generation
- live appointment slot checks

`SensitiveActionStepUpService` is also available for trusted-device biometric verification before sensitive actions, although it is separate from the route-level MFA flow.
