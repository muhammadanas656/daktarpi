import 'package:hive_flutter/hive_flutter.dart';

class NotificationRepository {
  static const String _boxName = 'notifications_box';
  static const String _key = 'notifications_list';

  Future<Box> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final box = await _getBox();
    final List<dynamic>? rawList = box.get(_key);
    if (rawList == null) return [];
    
    // Cast dynamic JSON from Hive back to proper Map
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveNotifications(List<Map<String, dynamic>> notifications) async {
    final box = await _getBox();
    await box.put(_key, notifications);
  }
}
