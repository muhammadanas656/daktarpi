import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/notification_repository.dart';

class NotificationNotifier extends ChangeNotifier {
  NotificationNotifier._();
  static final NotificationNotifier instance = NotificationNotifier._();

  final NotificationRepository _repo = NotificationRepository();
  List<Map<String, dynamic>> _notifications = [];

  List<Map<String, dynamic>> get notifications => _notifications;
  
  int get unreadCount => _notifications.where((n) => n['is_read'] == false).length;

  Future<void> load() async {
    _notifications = await _repo.getNotifications();
    // Sort newest first
    _notifications.sort((a, b) => DateTime.parse(b['timestamp']).compareTo(DateTime.parse(a['timestamp'])));
    notifyListeners();
  }

  Future<void> addNotification({required String title, required String body}) async {
    final newNotif = {
      'id': const Uuid().v4(),
      'title': title,
      'body': body,
      'timestamp': DateTime.now().toIso8601String(),
      'is_read': false,
    };
    _notifications.insert(0, newNotif); // Add to top
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
    for (var n in _notifications) {
      n['is_read'] = true;
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
