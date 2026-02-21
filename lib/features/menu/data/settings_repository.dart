import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../auth/data/auth_repository.dart';

/// Repository for destructive/high-impact settings operations.
class SettingsRepository {
  final AuthRepository _authRepository;

  SettingsRepository({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository();

  Future<void> saveRecoveryCodes(List<String> codes) {
    return _authRepository.saveRecoveryCodes(codes);
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
}
