import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

// PRO FIX: Import the repository to trigger the sync engine
import '../../features/appointments/data/appointment_repository.dart';
import '../../features/medical_records/data/medical_record_repository.dart';
import '../../features/profile/data/profile_repository.dart';

class NetworkNotifier extends ChangeNotifier {
  static final NetworkNotifier instance = NetworkNotifier._internal();

  NetworkNotifier._internal();

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  late StreamSubscription<List<ConnectivityResult>> _subscription;

  void initialize() {
    _checkInitialStatus();
    _subscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isCurrentlyOffline = results.every(
        (result) => result == ConnectivityResult.none,
      );

      if (_isOffline != isCurrentlyOffline) {
        _isOffline = isCurrentlyOffline;
        notifyListeners();

        // ─── PHASE 3 MAGIC: Auto-Sync on Reconnect ───
        if (!_isOffline) {
          _syncOfflineQueues();
        }
      }
    });
  }

  Future<void> _checkInitialStatus() async {
    final results = await Connectivity().checkConnectivity();
    _isOffline = results.every((result) => result == ConnectivityResult.none);
    notifyListeners();

    // Also try to sync on app startup if we launch with internet
    if (!_isOffline) {
      _syncOfflineQueues();
    }
  }

  /// The global engine that fires off all repository sync methods
  Future<void> _syncOfflineQueues() async {
    try {
      debugPrint(
        '🌐 [NetworkNotifier] Internet restored. Syncing offline queues...',
      );

      // 1. Sync Appointments
      final appointmentRepo = AppointmentRepository();
      await appointmentRepo.syncOfflineQueue();

      final profileRepo = ProfileRepository();
      await profileRepo.syncOfflineQueue();

      final medicalRepo = MedicalRecordRepository();
      await medicalRepo.syncOfflineQueue();
    } catch (e) {
      debugPrint('❌ [NetworkNotifier] Error syncing offline queues: $e');
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
