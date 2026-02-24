import 'trusted_device_repository.dart';

/// Orchestrates trusted-device operations for 2FA bypass.
///
/// Raw trust tokens are stored locally; only SHA-256 hashes are persisted
/// to the database via [TrustedDeviceRepository].
class TrustedDeviceService {
  final TrustedDeviceRepository _repository;

  TrustedDeviceService({TrustedDeviceRepository? repository})
    : _repository = repository ?? TrustedDeviceRepository();

  Future<void> trustCurrentDevice({
    Duration ttl = const Duration(days: 30),
    bool isBiometricEnabled = false,
    String? biometricPublicKey,
  }) {
    return _repository.trustCurrentDevice(
      ttl: ttl,
      isBiometricEnabled: isBiometricEnabled,
      biometricPublicKey: biometricPublicKey,
    );
  }

  Future<bool> isTrustedDeviceValid({required String userId}) {
    return _repository.isTrustedDeviceValid(userId: userId);
  }

  Future<bool> isBiometricEnabledForDevice({required String userId}) {
    return _repository.isBiometricEnabledForDevice(userId: userId);
  }

  Future<void> revokeCurrentDevice() {
    return _repository.revokeCurrentDevice();
  }

  Future<void> clearLocalToken() {
    return _repository.clearLocalToken();
  }
}
