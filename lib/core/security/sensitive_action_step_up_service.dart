import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/trusted_device_repository.dart';
import 'biometric_auth_service.dart';

/// Handles biometric step-up for trusted devices before sensitive actions.
class SensitiveActionStepUpService {
  final AuthRepository _authRepository;
  final TrustedDeviceRepository _trustedDeviceRepository;
  final BiometricAuthService _biometricAuthService;

  SensitiveActionStepUpService({
    AuthRepository? authRepository,
    TrustedDeviceRepository? trustedDeviceRepository,
    BiometricAuthService? biometricAuthService,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _trustedDeviceRepository =
           trustedDeviceRepository ?? TrustedDeviceRepository(),
       _biometricAuthService = biometricAuthService ?? BiometricAuthService();

  Future<bool> canUseTrustedBiometricStepUp() async {
    final userId = _authRepository.currentUserId;
    if (userId == null) {
      return false;
    }

    final biometricEnabled = await _trustedDeviceRepository
        .isBiometricEnabledForDevice(userId: userId);
    if (!biometricEnabled) {
      return false;
    }

    return _biometricAuthService.canUseBiometricUnlock();
  }

  Future<bool> authenticateIfTrusted({
    String localizedReason = 'Verify your identity to continue',
  }) async {
    final canUseBiometric = await canUseTrustedBiometricStepUp();
    if (!canUseBiometric) {
      return false;
    }

    try {
      return await _biometricAuthService.authenticate(
        localizedReason: localizedReason,
      );
    } catch (_) {
      return false;
    }
  }
}
