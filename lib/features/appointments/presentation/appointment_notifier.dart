import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/appointment.dart';
import '../data/appointment_repository.dart';
import '../data/appointment_secure_cache_repository.dart';
import '../../../core/services/appointment_notification_service.dart';
import '../../medical_records/data/medical_record_repository.dart';

class AppointmentNotifier extends ChangeNotifier {
  AppointmentNotifier._();
  static final AppointmentNotifier instance = AppointmentNotifier._();

  final _appointmentRepo = AppointmentRepository();
  final _cacheRepo = AppointmentSecureCacheRepository();
  final _notificationService = AppointmentNotificationService.instance;
  final _medicalRecordRepo = MedicalRecordRepository();
  RealtimeChannel? _appointmentsSubscription;
  StreamSubscription<AuthState>? _authStateSub;
  String? _subscribedUserId;
  bool _isRealtimeInitialized = false;

  List<Appointment> _appointments = [];
  List<Map<String, dynamic>> _pendingReviews = [];
  List<Map<String, dynamic>> _pendingComplaints = [];

  // PRO FIX: Centralized Activity Log Vault
  List<Map<String, dynamic>> _activityLog = [];
  List<Map<String, dynamic>> get activityLog => _activityLog;

  List<Map<String, dynamic>> get actionRequiredItems {
    final combined = [..._pendingReviews, ..._pendingComplaints];
    combined.sort((a, b) => b['schedule_date'].compareTo(a['schedule_date']));
    return combined;
  }

  bool _isLoading = false;
  String? _error;
  DateTime? _lastBackgroundSync; // PRO FIX: Background throttle

  List<Appointment> get appointments => _appointments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _shouldPreserveMissedStatusUpdate(Appointment appointment) {
    final scheduledEnd =
        DateTime.tryParse('${appointment.scheduleDate}T${appointment.endTime}') ??
        DateTime.tryParse('${appointment.scheduleDate} ${appointment.endTime}');
    if (scheduledEnd == null) {
      return false;
    }
    return !scheduledEnd.isAfter(DateTime.now());
  }

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
        unawaited(fetchAppointments(isBackground: true, bypassThrottle: true)); // DB updates ignore throttle
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

  Future<void> fetchAppointments({
    bool isBackground = false, 
    bool bypassThrottle = false,
  }) async {
    
    // PRO FIX: Silent Throttle for Background app-resumes (10 min)
    if (isBackground && !bypassThrottle && _lastBackgroundSync != null) {
      final diff = DateTime.now().difference(_lastBackgroundSync!);
      if (diff.inMinutes < 10 && _appointments.isNotEmpty) {
        return; // Skip silent fetch
      }
    }

    initializeRealtime();
    await _ensureRealtimeSubscription();

    final userId = _appointmentRepo.currentUserId;
    if (userId == null) {
      await clear();
      return;
    }

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
      final previousAppointmentsById = {
        for (final appointment in _appointments) appointment.id: appointment,
      };
      final previousIds = previousAppointmentsById.keys.toSet();

      // PRO FIX: Fetch ALL related data simultaneously, including the Activity Log!
      final results = await Future.wait([
        _appointmentRepo.fetchAppointments(userId),
        _appointmentRepo.fetchPendingReviews(userId),
        _appointmentRepo.fetchPendingComplaints(userId),
        _appointmentRepo.fetchActivityLog(userId),
      ]);

      final freshAppointments = results[0] as List<Appointment>;
      _pendingReviews = results[1] as List<Map<String, dynamic>>;
      _pendingComplaints = results[2] as List<Map<String, dynamic>>;
      _activityLog = results[3] as List<Map<String, dynamic>>;

      final nextIds = freshAppointments.map((a) => a.id).toSet();
      for (final removedId in previousIds.difference(nextIds)) {
        final removedAppointment = previousAppointmentsById[removedId];
        final preserveMissedStatusUpdate =
            removedAppointment != null &&
            _shouldPreserveMissedStatusUpdate(removedAppointment);
        unawaited(
          _notificationService.cancelReminder(
            removedId,
            preserveMissedStatusUpdate: preserveMissedStatusUpdate,
          ),
        );

        // PRO FIX: Unlock attached medical records when appointment is removed (canceled/missed)
        if (removedAppointment != null && removedAppointment.attachedRecordIds.isNotEmpty) {
          unawaited(_medicalRecordRepo.unlockRecords(removedAppointment.attachedRecordIds));
        }
      }

      _appointments = freshAppointments;
      await _cacheRepo.saveAppointments(_appointments);
      _lastBackgroundSync = DateTime.now(); // PRO FIX: Mark fetch as fresh
    } catch (e) {
      if (!isBackground) _error = e.toString();
      debugPrint("AppointmentNotifier Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- PRO FIX: 0ms Optimistic UI Submissions ---
  void submitComplaint(
    Map<String, dynamic> appointment,
    String description,
    String recipient,
  ) {
    final apptId = appointment['id'];

    // 1. Instantly remove from pending UI
    _pendingComplaints.removeWhere((c) => c['id'] == apptId);

    // 2. Instantly update Account Activity UI
    for (var act in _activityLog) {
      if (act['id'] == apptId) act['has_complaint'] = true;
    }
    notifyListeners();

    // 3. Silently process network/offline queue in background
    unawaited(
      _appointmentRepo.submitComplaint(
        appointmentId: apptId,
        doctorId: appointment['doctor_id'],
        description: description,
        recipient: recipient,
      ),
    );
  }

  void submitReview(
    Map<String, dynamic> appointment,
    int rating,
    String comment,
  ) {
    final apptId = appointment['id'];

    _pendingReviews.removeWhere((r) => r['id'] == apptId);
    for (var act in _activityLog) {
      if (act['id'] == apptId) act['has_review'] = true;
    }
    notifyListeners();

    unawaited(
      _appointmentRepo.submitReview(
        appointmentId: apptId,
        doctorId: appointment['doctor_id'],
        rating: rating,
        comment: comment,
      ),
    );
  }

  // --- Existing Methods ---
  void removePendingReview(int appointmentId) {
    _pendingReviews.removeWhere((appt) => appt['id'] == appointmentId);
    notifyListeners();
  }

  void removePendingComplaint(int appointmentId) {
    _pendingComplaints.removeWhere((appt) => appt['id'] == appointmentId);
    notifyListeners();
  }

  Future<void> cancelAppointment(int appointmentId, String reason) async {
    try {
      // PRO FIX: Extract attached record IDs BEFORE removing from list
      final canceledAppointment = _appointments.where((app) => app.id == appointmentId).firstOrNull;
      final attachedRecordIds = canceledAppointment?.attachedRecordIds ?? [];

      await _appointmentRepo.cancelAppointment(appointmentId, reason);
      await _notificationService.cancelReminder(appointmentId);

      // PRO FIX: Unlock attached medical records immediately on cancellation
      if (attachedRecordIds.isNotEmpty) {
        unawaited(_medicalRecordRepo.unlockRecords(attachedRecordIds));
      }

      _appointments.removeWhere((app) => app.id == appointmentId);
      await _cacheRepo.saveAppointments(_appointments);
      notifyListeners();
    } catch (e) {
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
    _activityLog = [];
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
