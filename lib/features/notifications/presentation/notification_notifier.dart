import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/notification_repository.dart';

class NotificationNotifier extends ChangeNotifier with WidgetsBindingObserver {
  NotificationNotifier._() {
    WidgetsBinding.instance.addObserver(this);
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      notifyListeners();
    });
  }
  static final NotificationNotifier instance = NotificationNotifier._();

  final NotificationRepository _repo = NotificationRepository();
  List<Map<String, dynamic>> _notifications = [];
  Timer? _autoRefreshTimer;
  bool _hasLoaded = false;
  Future<void>? _loadFuture;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(load(force: true));
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  List<Map<String, dynamic>> get notifications => _notifications;

  int get unreadCount {
    final now = DateTime.now();
    return _notifications.where((n) {
      final isPast = DateTime.parse(n['timestamp']).isBefore(now);
      return isPast && n['is_read'] == false;
    }).length;
  }

  void _sortNotifications(List<Map<String, dynamic>> notifications) {
    notifications.sort(
      (a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])),
    );
  }

  Future<void> load({bool force = false}) async {
    if (_hasLoaded && !force) return;
    if (_loadFuture != null) {
      await _loadFuture;
      return;
    }

    final future = () async {
      final loadedNotifications = await _repo.getNotifications();
      _sortNotifications(loadedNotifications);
      _notifications = loadedNotifications;
      _hasLoaded = true;
      notifyListeners();
    }();

    _loadFuture = future;
    try {
      await future;
    } finally {
      _loadFuture = null;
    }
  }

  Future<void> addNotification({
    required String title,
    required String body,
    DateTime? scheduledTime,
    String? payload,
    String? messageId,
  }) async {
    try {
      await load();

      if (messageId != null && messageId.isNotEmpty) {
        final alreadyExists = _notifications.any((n) => n['message_id'] == messageId);
        if (alreadyExists) return;
      }

      final newNotif = {
        'id': const Uuid().v4(),
        'title': title,
        'body': body,
        'timestamp': (scheduledTime ?? DateTime.now()).toIso8601String(),
        'is_read': false,
        'payload': payload,
        if (messageId != null) 'message_id': messageId,
      };

      _notifications.insert(0, newNotif);
      _sortNotifications(_notifications);

      // Save locally for instant UI update, then push to Supabase
      await _repo.saveLocalCache(_notifications);
      await _repo.insertRemote(newNotif);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to add notification: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    await load();
    final index = _notifications.indexWhere((n) => n['id'] == id);
    if (index != -1 && _notifications[index]['is_read'] == false) {
      _notifications[index]['is_read'] = true;
      
      await _repo.saveLocalCache(_notifications);
      await _repo.updateReadStatusRemote(id, true);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    await load();
    final now = DateTime.now();
    for (var n in _notifications) {
      if (DateTime.parse(n['timestamp']).isBefore(now)) {
        n['is_read'] = true;
      }
    }
    await _repo.saveLocalCache(_notifications);
    await _repo.markAllReadRemote();
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    await load();
    _notifications.removeWhere((n) => n['id'] == id);
    
    await _repo.saveLocalCache(_notifications);
    await _repo.deleteRemote(id);
    notifyListeners();
  }

  Future<void> deleteNotificationsByPayload(
    String payload, {
    Set<String> excludedTitles = const {},
  }) async {
    await load();
    final initialLength = _notifications.length;

    // Find the IDs we are about to delete so we can remove them from Supabase
    final toDelete = _notifications.where(
      (n) => n['payload'] == payload && !excludedTitles.contains(n['title']?.toString())
    ).toList();

    for (var n in toDelete) {
      await _repo.deleteRemote(n['id']);
    }

    _notifications.removeWhere((n) => toDelete.contains(n));

    if (_notifications.length != initialLength) {
      await _repo.saveLocalCache(_notifications);
      notifyListeners();
    }
  }
}