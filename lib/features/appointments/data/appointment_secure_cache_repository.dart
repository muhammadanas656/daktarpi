import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'appointment.dart';

class AppointmentSecureCacheRepository {
  static const String _storageKey = 'appointments_cache_v1';

  final FlutterSecureStorage _storage;

  AppointmentSecureCacheRepository({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  Future<List<Appointment>> loadAppointments() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Appointment.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> saveAppointments(List<Appointment> appointments) {
    final payload = appointments.map((item) => item.toJson()).toList();
    return _storage.write(key: _storageKey, value: jsonEncode(payload));
  }

  Future<void> clear() => _storage.delete(key: _storageKey);
}
