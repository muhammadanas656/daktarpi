import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_failure.dart';

/// Centralised authentication repository.
///
/// Wraps all Supabase Auth calls so that no screen/service talks
/// to `Supabase.instance.client.auth` directly.
class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // ─── Current User ──────────────────────────────────────────

  /// Returns the current authenticated user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// Convenience: returns just the user ID, or null.
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Whether the user is currently signed in.
  bool get isSignedIn => _client.auth.currentUser != null;

  /// Current user profile metadata from auth.users.user_metadata.
  Map<String, dynamic>? get currentUserMetadata =>
      _client.auth.currentUser?.userMetadata;

  /// Current user app metadata from auth.users.raw_app_meta_data.
  Map<String, dynamic>? get currentAppMetadata =>
      _client.auth.currentUser?.appMetadata;

  /// Whether the account currently has 2FA enabled.
  bool get is2FAEnabled => currentAppMetadata?['is_2fa_enabled'] == true;

  /// Current assurance level string from metadata (e.g. `aal1`, `aal2`).
  String? get currentAal => currentAppMetadata?['aal'] as String?;

  /// Returns true when the current session requires step-up verification.
  bool get requiresAal2StepUp =>
      is2FAEnabled && (currentAal == null || currentAal == 'aal1');

  /// Whether current user metadata indicates profile completion.
  bool get hasCompletedProfileDob {
    final dob = currentUserMetadata?['dob'];
    return dob != null && dob.toString().isNotEmpty;
  }

  /// Whether current user metadata includes both DOB and phone.
  bool get hasCompletedProfileDobAndPhone {
    final metadata = currentUserMetadata;
    final dob = metadata?['dob'];
    final phone = metadata?['phone'];
    final hasDob = dob != null && dob.toString().isNotEmpty;
    final hasPhone = phone != null && phone.toString().isNotEmpty;
    return hasDob && hasPhone;
  }

  // ─── Auth Actions ──────────────────────────────────────────

  /// Signs up with email and password.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to create your account right now.',
      );
    }
  }

  /// Sends password reset email.
  Future<void> resetPasswordForEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to send reset email right now.',
      );
    }
  }

  /// Signs in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to sign in right now.',
      );
    }
  }

  /// Verifies an OTP recovery code.
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    try {
      return await _client.auth.verifyOTP(
        token: token,
        type: OtpType.recovery,
        email: email,
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to verify recovery code right now.',
      );
    }
  }

  /// Signs in with a Google ID token.
  Future<AuthResponse> signInWithGoogleIdToken({
    required String idToken,
  }) async {
    try {
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to sign in with Google right now.',
      );
    }
  }

  /// Signs the current user out.
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      debugPrint('AuthRepository: sign-out error: $e');
    }
  }

  /// Refreshes the current auth session.
  Future<void> refreshSession() async {
    try {
      await _client.auth.refreshSession();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to refresh your session right now.',
      );
    }
  }

  /// Returns the first verified TOTP factor id, if present.
  Future<String?> getVerifiedTotpFactorId() async {
    try {
      final factors = await _client.auth.mfa.listFactors();
      for (final factor in factors.totp) {
        if (factor.status == FactorStatus.verified) {
          return factor.id;
        }
      }
      return null;
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load authenticator settings right now.',
      );
    }
  }

  /// Returns all MFA factors for the current user.
  Future<dynamic> listMfaFactors() async {
    try {
      return await _client.auth.mfa.listFactors();
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load authenticator settings right now.',
      );
    }
  }

  /// Enrolls a new TOTP factor.
  Future<dynamic> enrollTotp({
    required String issuer,
    required String friendlyName,
  }) async {
    try {
      return await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: issuer,
        friendlyName: friendlyName,
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to enroll authenticator right now.',
      );
    }
  }

  /// Verifies a TOTP challenge for a specific factor.
  Future<void> challengeAndVerify({
    required String factorId,
    required String code,
  }) async {
    try {
      await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to verify authenticator code right now.',
      );
    }
  }

  /// Unenrolls an MFA factor.
  Future<void> unenrollFactor(String factorId) async {
    try {
      await _client.auth.mfa.unenroll(factorId);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to remove authenticator right now.',
      );
    }
  }

  /// Whether user currently has recovery codes stored.
  Future<bool> userHasRecoveryCodes() async {
    try {
      final result = await _client.rpc('user_has_recovery_codes');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Saves backup/recovery codes.
  Future<void> saveRecoveryCodes(List<String> codes) async {
    try {
      await _client.rpc('save_recovery_codes', params: {'codes': codes});
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to save recovery codes right now.',
      );
    }
  }

  /// Links Google identity.
  Future<void> linkGoogleIdentity({required String redirectTo}) async {
    try {
      await _client.auth.linkIdentity(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to link Google account right now.',
      );
    }
  }

  /// Unlinks an existing identity.
  Future<void> unlinkIdentity(UserIdentity identity) async {
    try {
      await _client.auth.unlinkIdentity(identity);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to unlink account right now.',
      );
    }
  }

  /// Updates user password.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update password right now.',
      );
    }
  }

  /// Deletes current user account via RPC.
  Future<void> deleteUserAccount() async {
    try {
      await _client.rpc('delete_user_account');
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to delete account right now.',
      );
    }
  }

  /// Lists files in a bucket under a specific path.
  Future<List<FileObject>> listFiles({
    required String bucket,
    required String path,
  }) async {
    try {
      return await _client.storage.from(bucket).list(path: path);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to load account files right now.',
      );
    }
  }

  /// Removes files from a bucket.
  Future<void> removeFiles({
    required String bucket,
    required List<String> paths,
  }) async {
    try {
      await _client.storage.from(bucket).remove(paths);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to remove account files right now.',
      );
    }
  }

  /// Verifies a TOTP challenge against the first verified TOTP factor.
  Future<void> verifyTotpCode(String code) async {
    final factorId = await getVerifiedTotpFactorId();
    if (factorId == null) {
      throw const AppFailure(
        type: AppFailureType.validation,
        userMessage:
            'No verified authenticator found. Please use a backup code.',
        technicalMessage: 'verifyTotpCode called without verified factor.',
        code: 'mfa_factor_missing',
      );
    }

    try {
      await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to verify authenticator code right now.',
      );
    }
  }

  /// Attempts one-time recovery-code verification.
  Future<bool> useRecoveryCode(String code) async {
    try {
      final result = await _client.rpc(
        'use_recovery_code',
        params: {'input_code': code},
      );
      return result == true;
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to verify backup code right now.',
      );
    }
  }

  /// Updates user metadata (e.g. full_name, dob, phone).
  Future<UserResponse> updateUser(Map<String, dynamic> data) async {
    try {
      return await _client.auth.updateUser(UserAttributes(data: data));
    } catch (error) {
      throw AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to update account details right now.',
      );
    }
  }
}
