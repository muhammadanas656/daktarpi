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
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return DateFormat('h:mm a').format(date);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEEE').format(date);
    return DateFormat('MMM d').format(date);
  }

  // Helper to dynamically pick the right icon
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

  @override
  Widget build(BuildContext context) {
    final notifications = NotificationNotifier.instance.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.colorTextDark,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text("Notifications", style: AppTextStyles.h2(context)),
        centerTitle: true,
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
                : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    final isRead = notif['is_read'] == true;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppStyles.cardShadow(context),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Dismissible(
                          key: Key(notif['id']),
                          direction: DismissDirection.endToStart,
                          onDismissed: (direction) {
                            NotificationNotifier.instance.deleteNotification(
                              notif['id'],
                            );
                          },
                          // PRO FIX: Added decoration and radius to the background
                          // so it remains round while the card is being moved.
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: AppColors.dangerRed,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          child: InkWell(
                            onTap:
                                () => NotificationNotifier.instance.markAsRead(
                                  notif['id'],
                                ),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isRead
                                          ? Colors.transparent
                                          : AppColors.primaryGreen.withValues(
                                            alpha: 0.3,
                                          ),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icon Box
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color:
                                          isRead
                                              ? Colors.grey.withValues(
                                                alpha: 0.1,
                                              )
                                              : AppColors.primaryGreen
                                                  .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _getIconForTitle(notif['title']),
                                      color:
                                          isRead
                                              ? Colors.grey
                                              : AppColors.primaryGreen,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Content Column
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // PRO FIX: Header Row with CrossAxisAlignment.start
                                        // This ensures the timestamp stays at the top even if the title wraps.
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                                  height:
                                                      1.2, // Tighter line height
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
                                                        : AppColors
                                                            .primaryGreen,
                                                fontWeight:
                                                    isRead
                                                        ? FontWeight.w500
                                                        : FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          notif['body'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: context.colorTextLight,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Premium Subtle Unread Dot
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(
                                        left: 12,
                                        top: 6,
                                      ),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryGreen
                                                .withValues(alpha: 0.4),
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
                    );
                  },
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
          const SizedBox(height: 60), // Visual balance
        ],
      ),
    );
  }
}
