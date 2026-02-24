import 'dart:async';

import 'package:flutter/foundation.dart';
import '../data/appointment.dart';
import '../data/appointment_repository.dart';
import '../data/appointment_secure_cache_repository.dart';
import '../../../core/services/appointment_notification_service.dart';

/// Singleton ChangeNotifier that manages the state of user appointments.
/// Centralizes fetching and updates (cancellation) to ensure UI consistency.
class AppointmentNotifier extends ChangeNotifier {
  AppointmentNotifier._();
  static final AppointmentNotifier instance = AppointmentNotifier._();

  final _appointmentRepo = AppointmentRepository();
  final _cacheRepo = AppointmentSecureCacheRepository();
  final _notificationService = AppointmentNotificationService.instance;

  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch appointments from the repository.
  Future<void> fetchAppointments() async {
    final userId = _appointmentRepo.currentUserId;
    if (userId == null) {
      _appointments = [];
      _error = null;
      _isLoading = false;
      notifyListeners();
      unawaited(_cacheRepo.clear());
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final cached = await _cacheRepo.loadAppointments();
      if (cached.isNotEmpty) {
        _appointments = cached;
        notifyListeners();
      }
    } catch (e) {
      debugPrint("AppointmentNotifier Cache Load Error: $e");
    }

    try {
      final previousIds = _appointments.map((a) => a.id).toSet();
      final freshAppointments = await _appointmentRepo.fetchAppointments(
        userId,
      );
      final nextIds = freshAppointments.map((a) => a.id).toSet();

      for (final removedId in previousIds.difference(nextIds)) {
        unawaited(_notificationService.cancelReminder(removedId));
      }

      _appointments = freshAppointments;
      await _cacheRepo.saveAppointments(_appointments);
    } catch (e) {
      _error = e.toString();
      debugPrint("AppointmentNotifier Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel an appointment and update local state immediately.
  Future<void> cancelAppointment(int appointmentId) async {
    // Optimistic update could be implemented, but for now we'll wait for API
    // to ensure data integrity, then remove locally.

    try {
      await _appointmentRepo.cancelAppointment(appointmentId);
      await _notificationService.cancelReminder(appointmentId);

      // Remove locally to update UI instantly without full refetch
      _appointments.removeWhere((app) => app.id == appointmentId);
      await _cacheRepo.saveAppointments(_appointments);
      notifyListeners();
    } catch (e) {
      debugPrint("AppointmentNotifier Cancel Error: $e");
      rethrow; // Let UI handle error display
    }
  }

  /// Mark an appointment as completed and update local state.
  Future<void> completeAppointment(int appointmentId) async {
    try {
      await _appointmentRepo.completeAppointment(appointmentId);
      await _notificationService.cancelReminder(appointmentId);

      // Remove locally to update UI instantly
      _appointments.removeWhere((app) => app.id == appointmentId);
      await _cacheRepo.saveAppointments(_appointments);
      notifyListeners();
    } catch (e) {
      debugPrint("AppointmentNotifier Complete Error: $e");
      rethrow;
    }
  }

  /// Add a newly created appointment to the list (optional, if we want immediate feedback)
  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    // Sort by date if needed, or just notify
    _appointments.sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
    unawaited(_cacheRepo.saveAppointments(_appointments));
    notifyListeners();
  }

  Future<void> clear() async {
    _appointments = [];
    _error = null;
    _isLoading = false;
    await _cacheRepo.clear();
    notifyListeners();
  }
}
