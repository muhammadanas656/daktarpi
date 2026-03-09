import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/appointment.dart';
import '../data/appointment_repository.dart';
import '../data/appointment_secure_cache_repository.dart';
import '../../../core/services/appointment_notification_service.dart';

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

  List<Map<String, dynamic>> _pendingReviews = [];
  List<Map<String, dynamic>> _pendingComplaints = [];

  List<Map<String, dynamic>> get actionRequiredItems {
    final combined = [..._pendingReviews, ..._pendingComplaints];
    combined.sort((a, b) => b['schedule_date'].compareTo(a['schedule_date']));
    return combined;
  }

  bool _isLoading = false;
  String? _error;

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

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
        // PRO FIX: Trigger a silent background fetch so the UI doesn't show a loading spinner!
        unawaited(fetchAppointments(isBackground: true));
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

  // PRO FIX: Added `isBackground` parameter to prevent UI flashes
  Future<void> fetchAppointments({bool isBackground = false}) async {
    initializeRealtime();
    await _ensureRealtimeSubscription();

    final userId = _appointmentRepo.currentUserId;
    if (userId == null) {
      _appointments = [];
      _pendingReviews = [];
      _pendingComplaints = [];
      _error = null;
      _isLoading = false;
      notifyListeners();
      await _removeRealtimeSubscription();
      unawaited(_cacheRepo.clear());
      return;
    }

    // PRO FIX: Only show loading spinner if it's a manual/initial fetch
    if (!isBackground) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

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

      final results = await Future.wait([
        _appointmentRepo.fetchAppointments(userId),
        _appointmentRepo.fetchPendingReviews(userId),
        _appointmentRepo.fetchPendingComplaints(userId),
      ]);

      final freshAppointments = results[0] as List<Appointment>;
      _pendingReviews = results[1] as List<Map<String, dynamic>>;
      _pendingComplaints = results[2] as List<Map<String, dynamic>>;

      final nextIds = freshAppointments.map((a) => a.id).toSet();

      for (final removedId in previousIds.difference(nextIds)) {
        unawaited(_notificationService.cancelReminder(removedId));
      }

      _appointments = freshAppointments;
      await _cacheRepo.saveAppointments(_appointments);
    } catch (e) {
      if (!isBackground) _error = e.toString();
      debugPrint("AppointmentNotifier Error: $e");
    } finally {
      // PRO FIX: Ensure loading flag is turned off, and notify the UI to update with fresh data
      _isLoading = false;
      notifyListeners();
    }
  }

  void removePendingReview(int appointmentId) {
    _pendingReviews.removeWhere((appt) => appt['id'] == appointmentId);
    notifyListeners();
  }

  void removePendingComplaint(int appointmentId) {
    _pendingComplaints.removeWhere((appt) => appt['id'] == appointmentId);
    notifyListeners();
  }

  Future<void> cancelAppointment(int appointmentId) async {
    try {
      await _appointmentRepo.cancelAppointment(appointmentId);
      await _notificationService.cancelReminder(appointmentId);

      _appointments.removeWhere((app) => app.id == appointmentId);
      await _cacheRepo.saveAppointments(_appointments);
      notifyListeners();
    } catch (e) {
      debugPrint("AppointmentNotifier Cancel Error: $e");
      rethrow;
    }
  }

  Future<void> completeAppointment(int appointmentId) async {
    try {
      await _appointmentRepo.completeAppointment(appointmentId);
      await _notificationService.cancelReminder(appointmentId);

      _appointments.removeWhere((app) => app.id == appointmentId);
      await _cacheRepo.saveAppointments(_appointments);
      notifyListeners();
    } catch (e) {
      debugPrint("AppointmentNotifier Complete Error: $e");
      rethrow;
    }
  }

  void addAppointment(Appointment appointment) {
    _appointments.add(appointment);
    _appointments.sort((a, b) => a.scheduleDate.compareTo(b.scheduleDate));
    unawaited(_cacheRepo.saveAppointments(_appointments));
    notifyListeners();
  }

  Future<void> clear() async {
    await _removeRealtimeSubscription();
    _appointments = [];
    _pendingReviews = [];
    _pendingComplaints = [];
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
