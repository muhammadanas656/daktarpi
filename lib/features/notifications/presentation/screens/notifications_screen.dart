import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../notification_notifier.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    NotificationNotifier.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    NotificationNotifier.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  String _formatTime(String timestamp) {
    final date = DateTime.parse(timestamp);
    return DateFormat('h:mm a').format(date);
  }

  IconData _getIconForTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('booking') || lower.contains('appointment')) {
      return Icons.calendar_month_rounded;
    }
    if (lower.contains('security') || lower.contains('login')) {
      return Icons.shield_rounded;
    }
    if (lower.contains('payment') || lower.contains('fee')) {
      return Icons.receipt_long_rounded;
    }
    return Icons.notifications_active_rounded;
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications(
    List<Map<String, dynamic>> notifications,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var notif in notifications) {
      final date = DateTime.parse(notif['timestamp']);
      final notifDate = DateTime(date.year, date.month, date.day);

      if (notifDate == today) {
        grouped['Today']!.add(notif);
      } else if (notifDate == yesterday) {
        grouped['Yesterday']!.add(notif);
      } else {
        grouped['Older']!.add(notif);
      }
    }

    grouped.removeWhere((key, value) => value.isEmpty);
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final notifications =
        NotificationNotifier.instance.notifications.where((n) {
          return DateTime.parse(n['timestamp']).isBefore(now);
        }).toList();

    final groupedNotifications = _groupNotifications(notifications);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colorTextDark,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text("Notifications", style: AppTextStyles.h2(context)),
        actions: [
          if (notifications.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: () => NotificationNotifier.instance.markAllAsRead(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Mark all read",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppStyles.pageGradient(context)),
        child:
            notifications.isEmpty
                ? _buildPremiumEmptyState(isDark)
                : ListView.builder(
                  // Restored the exact original padding dimensions
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  itemCount: groupedNotifications.length,
                  itemBuilder: (context, sectionIndex) {
                    final sectionKey = groupedNotifications.keys.elementAt(
                      sectionIndex,
                    );
                    final sectionItems = groupedNotifications[sectionKey]!;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 16),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                sectionKey,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: context.colorTextLight,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        ...sectionItems.map(
                          (notif) => _buildNotificationCard(notif, isDark),
                        ),
                      ],
                    );
                  },
                ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, bool isDark) {
    final isRead = notif['is_read'] == true;

    // We pre-calculate a 100% solid color so the red background physically cannot bleed through
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final unreadTint = AppColors.primaryGreen.withValues(
      alpha: isDark ? 0.08 : 0.04,
    );
    final solidCardColor =
        isRead ? surfaceColor : Color.alphaBlend(unreadTint, surfaceColor);

    return Container(
      // EXACT ORIGINAL MARGIN: Restored to purely bottom: 16. No extra bulk.
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppStyles.cardShadow(
          context,
        ), // Shadow is static and safe outside the clip
      ),
      // MASTER MASK: Forces perfectly rounded corners on both the background and sliding card
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Dismissible(
          key: Key(notif['id']),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) {
            NotificationNotifier.instance.deleteNotification(notif['id']);
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppColors.dangerRed,
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: solidCardColor, // Uses the solid blended color
              border: Border.all(
                color:
                    isRead
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.transparent)
                        : AppColors.primaryGreen.withValues(alpha: 0.4),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap:
                    () => NotificationNotifier.instance.markAsRead(notif['id']),
                // EXACT ORIGINAL PADDING: 16 all around
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              isRead
                                  ? Colors.grey.withValues(alpha: 0.1)
                                  : AppColors.primaryGreen.withValues(
                                    alpha: 0.15,
                                  ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIconForTitle(notif['title']),
                          color: isRead ? Colors.grey : AppColors.primaryGreen,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif['title'],
                                    style: TextStyle(
                                      fontWeight:
                                          isRead
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                      fontSize: 16,
                                      color: context.colorTextDark,
                                      letterSpacing: -0.2,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatTime(notif['timestamp']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        isRead
                                            ? Colors.grey
                                            : AppColors.primaryGreen,
                                    fontWeight:
                                        isRead
                                            ? FontWeight.w500
                                            : FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notif['body'],
                              style: TextStyle(
                                fontSize: 14,
                                color:
                                    isRead
                                        ? context.colorTextLight
                                        : context.colorTextDark.withValues(
                                          alpha: 0.8,
                                        ),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          margin: const EdgeInsets.only(left: 12, top: 6),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGreen.withValues(
                                  alpha: 0.4,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 54,
              color: AppColors.primaryGreen.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "You're all caught up",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: context.colorTextDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "When you get updates, alerts, or\nreminders, they'll show up here.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: context.colorTextLight,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
