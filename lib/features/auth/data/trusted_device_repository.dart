import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Persists and validates "trusted device" tokens used to bypass TOTP prompts.
///
/// Raw tokens are stored only on-device in secure storage. Supabase stores
/// token hashes plus expiration for server-side validation/revocation.
class TrustedDeviceRepository {
  static const _storageKey = 'trusted_device_token_v1';

  final SupabaseClient _client;
  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  TrustedDeviceRepository({
    SupabaseClient? client,
    FlutterSecureStorage? storage,
    Uuid? uuid,
  }) : _client = client ?? Supabase.instance.client,
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
           ),
       _uuid = uuid ?? const Uuid();

  Future<void> trustCurrentDevice({
    Duration ttl = const Duration(days: 30),
    bool isBiometricEnabled = false,
    String? biometricPublicKey,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return;
    }
    await trustDevice(
      userId: userId,
      ttl: ttl,
      isBiometricEnabled: isBiometricEnabled,
      biometricPublicKey: biometricPublicKey,
    );
  }

  Future<void> trustDevice({
    required String userId,
    Duration ttl = const Duration(days: 30),
    bool isBiometricEnabled = false,
    String? biometricPublicKey,
  }) async {
    final token = _uuid.v4();
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(ttl);
    final tokenHash = _hashToken(token);

    await _client.from('trusted_devices').insert({
      'user_id': userId,
      'device_hash': tokenHash,
      'expires_at': expiresAt.toIso8601String(),
      'is_biometric_enabled': isBiometricEnabled,
      if (biometricPublicKey != null)
        'biometric_public_key': biometricPublicKey,
    });

    await _writeLocalToken(
      _TrustedDeviceToken(userId: userId, token: token, expiresAt: expiresAt),
    );
  }

  Future<bool> isTrustedDeviceValid({
    required String userId,
    bool skipServerValidation = false,
  }) async {
    final local = await _readLocalToken();
    if (local == null) {
      return false;
    }

    final now = DateTime.now().toUtc();
    if (local.userId != userId || local.expiresAt.isBefore(now)) {
      await clearLocalToken();
      return false;
    }

    // --- PRO FIX: Zero-Network Startup ---
    // If we're booting the app and just need to route the user gracefully,
    // we bypass the 30-second offline timeout hazard completely.
    if (skipServerValidation) {
      return true;
    }

    final tokenHash = _hashToken(local.token);
    try {
      final row =
          await _client
              .from('trusted_devices')
              .select('id, expires_at')
              .eq('user_id', userId)
              .eq('device_hash', tokenHash)
              .gt('expires_at', now.toIso8601String())
              .maybeSingle();

      if (row == null) {
        await clearLocalToken();
        return false;
      }

      return true;
    } catch (_) {
      // Fail closed: if server validation cannot complete, do not bypass MFA.
      return false;
    }
  }

  Future<bool> isBiometricEnabledForDevice({required String userId}) async {
    final local = await _readLocalToken();
    if (local == null) {
      return false;
    }

    final now = DateTime.now().toUtc();
    if (local.userId != userId || local.expiresAt.isBefore(now)) {
      return false;
    }

    final tokenHash = _hashToken(local.token);
    try {
      final row =
          await _client
              .from('trusted_devices')
              .select('is_biometric_enabled')
              .eq('user_id', userId)
              .eq('device_hash', tokenHash)
              .gt('expires_at', now.toIso8601String())
              .maybeSingle();

      if (row == null) {
        return false;
      }

      return row['is_biometric_enabled'] == true;
    } catch (_) {
      // PRO FIX: Allow timeout exceptions to bubble up so UI can fallback to local cache
      rethrow;
    }
  }

  Future<void> revokeCurrentDevice() async {
    final local = await _readLocalToken();
    if (local != null) {
      try {
        await _client
            .from('trusted_devices')
            .delete()
            .eq('user_id', local.userId)
            .eq('device_hash', _hashToken(local.token));
      } catch (_) {}
    }

    await clearLocalToken();
  }

  Future<void> clearLocalToken() {
    return _storage.delete(key: _storageKey);
  }

  // `_touchLastUsed` removed to match schema constraints

  Future<_TrustedDeviceToken?> _readLocalToken() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await clearLocalToken();
        return null;
      }
      return _TrustedDeviceToken.fromJson(decoded);
    } catch (_) {
      await clearLocalToken();
      return null;
    }
  }

  Future<void> _writeLocalToken(_TrustedDeviceToken token) {
    return _storage.write(key: _storageKey, value: jsonEncode(token.toJson()));
  }

  String _hashToken(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }
}

class _TrustedDeviceToken {
  final String userId;
  final String token;
  final DateTime expiresAt;

  const _TrustedDeviceToken({
    required this.userId,
    required this.token,
    required this.expiresAt,
  });

  factory _TrustedDeviceToken.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id']?.toString();
    final token = json['token']?.toString();
    final expiresAtRaw = json['expires_at']?.toString();
    final expiresAt = DateTime.tryParse(expiresAtRaw ?? '');

    if (userId == null ||
        userId.isEmpty ||
        token == null ||
        token.isEmpty ||
        expiresAt == null) {
      throw const FormatException('Invalid trusted device token payload');
    }

    return _TrustedDeviceToken(
      userId: userId,
      token: token,
      expiresAt: expiresAt.toUtc(),
    );
  }

  Map<String, String> toJson() => {
    'user_id': userId,
    'token': token,
    'expires_at': expiresAt.toIso8601String(),
  };
}
