import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BookingDraftRepository {
  static const _storageKey = 'appointment_booking_draft_v1';
  final FlutterSecureStorage _storage;

  BookingDraftRepository({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  Future<Map<String, dynamic>?> loadDraft() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Future<void> saveDraft(Map<String, dynamic> draft) async {
    await _storage.write(key: _storageKey, value: jsonEncode(draft));
  }

  Future<void> clearDraft() async {
    await _storage.delete(key: _storageKey);
  }
}
