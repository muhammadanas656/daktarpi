import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
  RealtimeChannel? _appointmentsSubscription;
  StreamSubscription<AuthState>? _authStateSub;
  String? _subscribedUserId;
  bool _isRealtimeInitialized = false;

  List<Appointment> _appointments = [];
  // --- NEW STATE PROPERTIES ---
  List<Map<String, dynamic>> _pendingReviews = [];
  List<Map<String, dynamic>> get pendingReviews => _pendingReviews;
  // ----------------------------
  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Initializes global realtime sync for appointments.
  /// Safe to call multiple times.
  void initializeRealtime() {
    if (_isRealtimeInitialized) {
      unawaited(_ensureRealtimeSubscription());
      return;
    }

    _isRealtimeInitialized = true;
    _authStateSub = Supabase.instance.client.auth.onAuthStateChange.listen((
      authState,
    ) {
      final userId = authState.session?.user.id;

      if (userId == null) {
        unawaited(_removeRealtimeSubscription());
        unawaited(clear());
        return;
      }

      unawaited(_ensureRealtimeSubscription(userIdOverride: userId));
      unawaited(fetchAppointments());
    });

    unawaited(_ensureRealtimeSubscription());
  }

  Future<void> _ensureRealtimeSubscription({String? userIdOverride}) async {
    final userId = userIdOverride ?? _appointmentRepo.currentUserId;
    if (userId == null) {
      await _removeRealtimeSubscription();
      return;
    }

    if (_appointmentsSubscription != null && _subscribedUserId == userId) {
      return;
    }

    await _removeRealtimeSubscription();
    _subscribedUserId = userId;
    _appointmentsSubscription = _appointmentRepo.subscribeToAppointments(
      userId: userId,
      onChange: (_) {
        unawaited(fetchAppointments());
      },
    );
  }

  Future<void> _removeRealtimeSubscription() async {
    final channel = _appointmentsSubscription;
    _appointmentsSubscription = null;
    _subscribedUserId = null;

    if (channel == null) return;

    try {
      await _appointmentRepo.removeChannel(channel);
    } catch (e) {
      debugPrint('AppointmentNotifier realtime unsubscribe error: $e');
    }
  }

  /// Fetch appointments from the repository.
  Future<void> fetchAppointments() async {
    initializeRealtime();
    await _ensureRealtimeSubscription();

    final userId = _appointmentRepo.currentUserId;
    if (userId == null) {
      _appointments = [];
      _pendingReviews = []; // NEW
      _error = null;
      _isLoading = false;
      notifyListeners();
      await _removeRealtimeSubscription();
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

      // --- CHANGED: Fetch both active appointments AND pending reviews concurrently ---
      final results = await Future.wait([
        _appointmentRepo.fetchAppointments(userId),
        _appointmentRepo.fetchPendingReviews(userId),
      ]);

      final freshAppointments = results[0] as List<Appointment>;
      _pendingReviews = results[1] as List<Map<String, dynamic>>;
      // -----------------------------------------------------------------------------

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

  // --- NEW METHOD: Instantly remove a review from the carousel once submitted ---
  void removePendingReview(int appointmentId) {
    _pendingReviews.removeWhere((appt) => appt['id'] == appointmentId);
    notifyListeners();
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
    await _removeRealtimeSubscription();
    _appointments = [];
    _pendingReviews = [];
    _error = null;
    _isLoading = false;
    await _cacheRepo.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    unawaited(_removeRealtimeSubscription());
    super.dispose();
  }
}
