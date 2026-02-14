import 'package:flutter/foundation.dart';
import '../data/appointment.dart';
import '../data/appointment_repository.dart';

/// Singleton ChangeNotifier that manages the state of user appointments.
/// Centralizes fetching and updates (cancellation) to ensure UI consistency.
class AppointmentNotifier extends ChangeNotifier {
  AppointmentNotifier._();
  static final AppointmentNotifier instance = AppointmentNotifier._();

  final _appointmentRepo = AppointmentRepository();
  
  List<Appointment> _appointments = [];
  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch appointments from the repository.
  Future<void> fetchAppointments() async {
    final userId = _appointmentRepo.currentUserId;
    if (userId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _appointments = await _appointmentRepo.fetchAppointments(userId);
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
      
      // Remove locally to update UI instantly without full refetch
      _appointments.removeWhere((app) => app.id == appointmentId);
      notifyListeners();
      
    } catch (e) {
      debugPrint("AppointmentNotifier Cancel Error: $e");
      rethrow; // Let UI handle error display
    }
  }

  /// Add a newly created appointment to the list (optional, if we want immediate feedback)
  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    // Sort by date if needed, or just notify
    _appointments.sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
    notifyListeners();
  }
}
