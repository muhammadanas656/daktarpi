import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/notification_repository.dart';

class NotificationNotifier extends ChangeNotifier {
  NotificationNotifier._();
  static final NotificationNotifier instance = NotificationNotifier._();

  final NotificationRepository _repo = NotificationRepository();
  List<Map<String, dynamic>> _notifications = [];

  // PRO FIX: Getter now filters out future notifications for the unread count!
  List<Map<String, dynamic>> get notifications => _notifications;

  int get unreadCount {
    final now = DateTime.now();
    return _notifications.where((n) {
      final isPast = DateTime.parse(n['timestamp']).isBefore(now);
      return isPast && n['is_read'] == false;
    }).length;
  }

  Future<void> load() async {
    _notifications = await _repo.getNotifications();
    _notifications.sort(
      (a, b) => DateTime.parse(
        b['timestamp'],
      ).compareTo(DateTime.parse(a['timestamp'])),
    );
    notifyListeners();
  }

  // PRO FIX: Added optional scheduledTime parameter
  Future<void> addNotification({
    required String title,
    required String body,
    DateTime? scheduledTime,
  }) async {
    final newNotif = {
      'id': const Uuid().v4(),
      'title': title,
      'body': body,
      // Use the scheduled time if provided, otherwise use now
      'timestamp': (scheduledTime ?? DateTime.now()).toIso8601String(),
      'is_read': false,
    };

    _notifications.insert(0, newNotif);
    // Re-sort so future ones stay at the top of the raw list until they unlock
    _notifications.sort(
      (a, b) => DateTime.parse(
        b['timestamp'],
      ).compareTo(DateTime.parse(a['timestamp'])),
    );

    await _repo.saveNotifications(_notifications);
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n['id'] == id);
    if (index != -1 && _notifications[index]['is_read'] == false) {
      _notifications[index]['is_read'] = true;
      await _repo.saveNotifications(_notifications);
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    final now = DateTime.now();
    for (var n in _notifications) {
      // Only mark visible ones as read
      if (DateTime.parse(n['timestamp']).isBefore(now)) {
        n['is_read'] = true;
      }
    }
    await _repo.saveNotifications(_notifications);
    notifyListeners();
  }

  Future<void> deleteNotification(String id) async {
    _notifications.removeWhere((n) => n['id'] == id);
    await _repo.saveNotifications(_notifications);
    notifyListeners();
  }
}
