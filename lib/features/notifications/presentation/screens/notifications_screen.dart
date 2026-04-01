import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
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
    final date = DateTime.parse(timestamp).toLocal();
    return DateFormat('h:mm a').format(date);
  }

  // --- 🎨 Contextual Color Intelligence ---
  Color _getContextColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('payment') || lower.contains('fee') || lower.contains('invoice')) {
      return const Color(0xFF0077B6); // Professional Ocean Blue for Financials
    }
    if (lower.contains('security') || lower.contains('login') || lower.contains('alert')) {
      return const Color(0xFFE07A5F); // Warm Amber for Security/Alerts
    }
    // Default Brand Green for Bookings & System
    return AppColors.primaryGreen;
  }

  IconData _getIconForTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('booking') || lower.contains('appointment')) return Icons.calendar_month_rounded;
    if (lower.contains('security') || lower.contains('login')) return Icons.shield_rounded;
    if (lower.contains('payment') || lower.contains('fee')) return Icons.receipt_long_rounded;
    return Icons.notifications_active_rounded;
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications(List<Map<String, dynamic>> notifications) {
    final grouped = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var notif in notifications) {
      final date = DateTime.parse(notif['timestamp']).toLocal();
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
    final notifications = NotificationNotifier.instance.notifications.where((n) {
      final notifDate = DateTime.parse(n['timestamp']).toLocal();
      return notifDate.isBefore(now) || notifDate.isAtSameMomentAs(now);
    }).toList();

    final unreadCount = NotificationNotifier.instance.unreadCount;
    final groupedNotifications = _groupNotifications(notifications);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        displacement: kToolbarHeight + 20, // Perfectly clears the frosted app bar
        onRefresh: () => NotificationNotifier.instance.load(force: true),
        child: CustomScrollView(
          clipBehavior: Clip.none, // Protects shadows from clipping
          slivers: [
            // --- 📌 NEW: Sleek, Minimalist Frosted Glass App Bar ---
            SliverAppBar(
              pinned: true,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent, // Prevents Material 3 color shifting
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.transparent),
                ),
              ),
              leadingWidth: 64,
              leading: Center(
                child: InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, color: context.colorTextDark, size: 18),
                  ),
                ),
              ),
              centerTitle: true,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Notifications",
                    style: AppTextStyles.h3(context).copyWith(
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.dangerRed,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "$unreadCount",
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ]
                ],
              ),
              actions: [
                if (unreadCount > 0)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: InkWell(
                        onTap: () => NotificationNotifier.instance.markAllAsRead(),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.done_all_rounded, color: isDark ? Colors.white : AppColors.primaryGreen, size: 18),
                        ),
                      ),
                    ),
                  )
              ],
            ),

            // --- 📌 Content Area ---
            if (notifications.isEmpty)
              SliverFillRemaining(
                child: _buildPremiumEmptyState(isDark),
              )
            else ...[
              const SliverPadding(padding: EdgeInsets.only(top: 12)),
              
              ...groupedNotifications.entries.map((entry) {
                return SliverMainAxisGroup(
                  slivers: [
                    // 1. The Sticky Header
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyDateHeaderDelegate(
                        title: entry.key,
                        isDark: isDark,
                      ),
                    ),
                    // 2. The Scrolling List for this specific date
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return _buildNotificationCard(entry.value[index], isDark);
                          },
                          childCount: entry.value.length,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],

            // Bottom padding for comfortable scrolling
            const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif, bool isDark) {
    final isRead = notif['is_read'] == true;
    final contextColor = _getContextColor(notif['title']);
    final surfaceColor = Theme.of(context).colorScheme.surface;
    
    // The entire card's subtle tint is derived from its contextual color!
    final unreadColor = contextColor.withValues(alpha: isDark ? 0.12 : 0.04);
    final cardColor = isRead ? surfaceColor : unreadColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Dismissible(
          key: Key(notif['id']),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => NotificationNotifier.instance.deleteNotification(notif['id']),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            color: AppColors.dangerRed,
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
          ),
          child: Material(
            color: cardColor,
            child: InkWell(
              splashColor: contextColor.withValues(alpha: 0.1),
              highlightColor: contextColor.withValues(alpha: 0.05),
              onTap: () => NotificationNotifier.instance.markAsRead(notif['id']),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isRead ? Colors.grey.withValues(alpha: 0.1) : contextColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForTitle(notif['title']),
                        color: isRead ? Colors.grey : contextColor,
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
                                  style: GoogleFonts.poppins(
                                    fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
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
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isRead ? Colors.grey : contextColor,
                                  fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notif['body'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isRead ? context.colorTextLight : context.colorTextDark.withValues(alpha: 0.85),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isRead)
                      Container(
                        margin: const EdgeInsets.only(left: 12, top: 6),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: contextColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: contextColor.withValues(alpha: 0.4),
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
    );
  }

  Widget _buildPremiumEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 64, color: AppColors.primaryGreen.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 24),
          Text(
            "You're all caught up",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: context.colorTextDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "When you get updates, alerts, or\nreminders, they'll show up here.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: context.colorTextLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 📌 NEW: Frosted Glass Sticky Header Delegate ---
class _StickyDateHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final bool isDark;

  _StickyDateHeaderDelegate({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ClipRRect(
      child: BackdropFilter(
        // Beautiful multi-tiered blur effect
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : context.colorTextDark,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 50.0;

  @override
  double get minExtent => 50.0;

  @override
  bool shouldRebuild(covariant _StickyDateHeaderDelegate oldDelegate) {
    return title != oldDelegate.title || isDark != oldDelegate.isDark;
  }
}