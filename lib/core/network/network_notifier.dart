import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../features/appointments/data/appointment_repository.dart';
import '../../features/medical_records/data/medical_record_repository.dart';
import '../../features/profile/data/profile_repository.dart';
// PRO FIX 1: Import the Doctor Repo and Appointment Notifier
import '../../features/doctors/data/doctor_repository.dart';
import '../../features/appointments/presentation/appointment_notifier.dart';

class NetworkNotifier extends ChangeNotifier {
  static final NetworkNotifier instance = NetworkNotifier._internal();

  NetworkNotifier._internal();

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  bool _isSyncing = false;
  Completer<void>? _syncCompleter;

  bool get isSyncing => _isSyncing;

  Future<void> waitForSync() async {
    if (_syncCompleter != null) {
      await _syncCompleter!.future;
    }
  }

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

  Future<void> _syncOfflineQueues() async {
    if (_isSyncing) return;

    _isSyncing = true;
    _syncCompleter = Completer<void>();
    notifyListeners();

    try {
      debugPrint(
        '🌐 [NetworkNotifier] Internet restored. Syncing offline queues...',
      );

      // PRO FIX 2: Await ALL repository syncs, including the missing Doctor favorites
      await Future.wait([
        AppointmentRepository().syncOfflineQueue(),
        ProfileRepository().syncOfflineQueue(),
        MedicalRecordRepository().syncOfflineQueue(),
        DoctorRepository().syncOfflineQueue(),
      ]);

      // PRO FIX 3: Silently refresh the appointments UI to clear any 'pending' states
      // that were just synced to the server, without showing a loading spinner.
      unawaited(
        AppointmentNotifier.instance.fetchAppointments(isBackground: true),
      );
    } catch (e) {
      debugPrint('❌ [NetworkNotifier] Error syncing offline queues: $e');
    } finally {
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
