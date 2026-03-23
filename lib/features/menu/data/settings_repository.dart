import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/data/auth_repository.dart';

/// Repository for destructive/high-impact settings operations.
class SettingsRepository {
  final AuthRepository _authRepository;

  SettingsRepository({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  User? get currentUser => _authRepository.currentUser;

  String? get currentUserEmail => _authRepository.currentUser?.email;

  Future<void> saveRecoveryCodes(List<String> codes) {
    return _authRepository.saveRecoveryCodes(codes);
  }

  Future<dynamic> listMfaFactors() {
    return _authRepository.listMfaFactors();
  }

  Future<bool> userHasRecoveryCodes() {
    return _authRepository.userHasRecoveryCodes();
  }

  Future<void> challengeAndVerify({
    required String factorId,
    required String code,
  }) {
    return _authRepository.challengeAndVerify(factorId: factorId, code: code);
  }

  Future<dynamic> enrollTotp({
    required String issuer,
    required String friendlyName,
  }) {
    return _authRepository.enrollTotp(
      issuer: issuer,
      friendlyName: friendlyName,
    );
  }

  Future<void> unenrollFactor(String factorId) {
    return _mapRecentMfaRequired(
      () => _authRepository.unenrollFactor(factorId),
    );
  }

  Future<bool> useRecoveryCode(String code) {
    return _authRepository.useRecoveryCode(code);
  }

  Future<void> updatePassword(String newPassword) {
    return _mapRecentMfaRequired(
      () => _authRepository.updatePassword(newPassword),
    );
  }

  Future<void> refreshSession() {
    return _authRepository.refreshSession();
  }

  Future<void> updateUserMetadata(Map<String, dynamic> metadata) async {
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(data: metadata),
    );
  }

  Future<void> linkGoogleIdentity({required String redirectTo}) {
    return _authRepository.linkGoogleIdentity(redirectTo: redirectTo);
  }

  Future<void> unlinkIdentity(UserIdentity identity) {
    return _mapRecentMfaRequired(
      () => _authRepository.unlinkIdentity(identity),
    );
  }

  /// Deletes account and attempts best-effort user storage cleanup first.
  Future<void> deleteAccount() async {
    final user = _authRepository.currentUser;
    if (user == null) {
      throw const AppFailure(
        type: AppFailureType.auth,
        userMessage: 'Please sign in to continue.',
        technicalMessage: 'deleteAccount called with no active session.',
        code: 'not_authenticated',
      );
    }

    try {
      final List<FileObject> objects = await _authRepository.listFiles(
        bucket: 'medical_docs',
        path: user.id,
      );

      if (objects.isNotEmpty) {
        final paths = objects.map((e) => '${user.id}/${e.name}').toList();
        await _authRepository.removeFiles(bucket: 'medical_docs', paths: paths);
      }
    } catch (_) {
      // Continue with account deletion even if storage cleanup partially fails.
    }

    await _authRepository.deleteUserAccount();
    await _authRepository.signOut();
  }

  Future<void> _mapRecentMfaRequired(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      final failure = AppFailure.fromError(
        error,
        fallbackUserMessage: 'Unable to complete this security action.',
      );
      if (_looksLikeAalDowngrade(failure)) {
        throw AppFailure.requiresRecentMfa(
          technicalMessage: failure.technicalMessage,
        );
      }
      throw failure;
    }
  }

  bool _looksLikeAalDowngrade(AppFailure failure) {
    final raw =
        '${failure.code ?? ''} ${failure.userMessage} ${failure.technicalMessage}'
            .toLowerCase();
    return raw.contains('requires_recent_mfa') ||
        raw.contains('aal2') ||
        raw.contains('assurance level') ||
        raw.contains('requires aal') ||
        (raw.contains('mfa') && raw.contains('required'));
  }
}
