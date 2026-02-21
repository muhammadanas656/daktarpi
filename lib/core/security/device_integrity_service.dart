import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/auth_repository.dart';

/// Detects rooted/jailbroken devices and enforces secure wipe + logout.
class DeviceIntegrityService {
  static const MethodChannel _channel = MethodChannel(
    'com.daktarpi/device_integrity',
  );

  final AuthRepository _authRepository;
  final FlutterSecureStorage _secureStorage;

  DeviceIntegrityService({
    AuthRepository? authRepository,
    FlutterSecureStorage? secureStorage,
  }) : _authRepository = authRepository ?? AuthRepository(),
       _secureStorage =
           secureStorage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           );

  Future<bool> isDeviceCompromised() async {
    if (kIsWeb) {
      return false;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        break;
      default:
        return false;
    }

    try {
      return await _channel.invokeMethod<bool>('isDeviceCompromised') ?? false;
    } on PlatformException {
      // Fail closed only when platform explicitly reports compromise.
      return false;
    }
  }

  Future<bool> enforceOnStartup() async {
    final compromised = await isDeviceCompromised();
    if (!compromised) {
      return false;
    }

    await wipeSensitiveLocalStorage();
    await _authRepository.signOut();
    return true;
  }

  Future<void> wipeSensitiveLocalStorage() async {
    try {
      await _secureStorage.deleteAll();
    } catch (_) {
      // Best-effort local wipe; sign-out still proceeds.
    }
  }
}
