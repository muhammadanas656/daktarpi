import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../features/appointments/data/appointment_repository.dart';
import '../../features/medical_records/data/medical_record_repository.dart';
import '../../features/profile/data/profile_repository.dart';

class NetworkNotifier extends ChangeNotifier {
  static final NetworkNotifier instance = NetworkNotifier._internal();

  NetworkNotifier._internal();

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  // --- PRO FIX: The Sync Lock Mechanism ---
  bool _isSyncing = false;
  Completer<void>? _syncCompleter;

  bool get isSyncing => _isSyncing;

  /// Allows repositories to pause their fetching until the queue is completely uploaded!
  Future<void> waitForSync() async {
    if (_syncCompleter != null) {
      await _syncCompleter!.future;
    }
  }
  // ----------------------------------------

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

    if (!_isOffline) {
      _syncOfflineQueues();
    }
  }

  /// The global engine that fires off all repository sync methods
  Future<void> _syncOfflineQueues() async {
    if (_isSyncing) return; // Prevent overlapping syncs

    // 1. Turn the traffic light RED
    _isSyncing = true;
    _syncCompleter = Completer<void>();
    notifyListeners();

    try {
      debugPrint(
        '🌐 [NetworkNotifier] Internet restored. Syncing offline queues...',
      );

      final appointmentRepo = AppointmentRepository();
      await appointmentRepo.syncOfflineQueue();

      final profileRepo = ProfileRepository();
      await profileRepo.syncOfflineQueue();

      final medicalRepo = MedicalRecordRepository();
      await medicalRepo.syncOfflineQueue();
    } catch (e) {
      debugPrint('❌ [NetworkNotifier] Error syncing offline queues: $e');
    } finally {
      // 2. Turn the traffic light GREEN, allowing all paused fetches to resume!
      _isSyncing = false;
      if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
        _syncCompleter!.complete();
      }
      _syncCompleter = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
