import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_styles.dart';
import '../../features/appointments/presentation/widgets/live_countdown_badge.dart';
import 'app_network_image.dart'; // PRO FIX: Imported

class AppointmentCard extends StatelessWidget {
  final String name;
  final String specialty;
  final String date;
  final String time;
  final String imageUrl;
  final String status;
  final String scheduleDate;
  final String startTime;
  final int maxWaitTime;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const AppointmentCard({
    super.key,
    required this.name,
    required this.specialty,
    required this.date,
    required this.time,
    required this.imageUrl,
    required this.status,
    required this.scheduleDate,
    required this.startTime,
    this.maxWaitTime = 30,
    required this.onTap,
    required this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onMoreTap,
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceXl),
        decoration: AppStyles.surfaceCard(
          context,
          borderRadius: AppShapes.xl,
        ).copyWith(
          border: Border.all(
            color:
                status == 'waiting'
                    ? Colors.amber.withValues(alpha: 0.5)
                    : (isDark
                        ? AppColors.darkBorder
                        : context.colorBorder.withValues(alpha: 0.5)),
          ),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PRO FIX: Replaced NetworkImage with Offline-Ready AppNetworkImage
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: AppShapes.lg,
                    color: isDark ? AppColors.darkBorder : Colors.grey[100],
                  ),
                  child: ClipRRect(
                    borderRadius: AppShapes.lg,
                    child:
                        imageUrl.isNotEmpty
                            ? AppNetworkImage(
                              imageUrl: imageUrl,
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              fallbackIconSize: 40,
                            )
                            : Icon(
                              Icons.person,
                              size: 40,
                              color:
                                  isDark
                                      ? AppColors.darkTextSecondary
                                      : Colors.grey,
                            ),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceLg),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: AppTextStyles.h3(
                                context,
                              ).copyWith(fontSize: 18),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onMoreTap,
                              borderRadius: AppShapes.pill,
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppDimens.spaceXs,
                                ),
                                child: Icon(
                                  Icons.more_vert,
                                  color: context.colorTextLight,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        specialty,
                        style: AppTextStyles.body(
                          context,
                        ).copyWith(color: context.colorTextLight, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      LiveCountdownBadge(
                        status: status,
                        scheduleDate: scheduleDate,
                        startTime: startTime,
                        maxWaitTime: maxWaitTime,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceLg),

            // Date & Time Row
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.calendar_today_outlined,
                    date,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    context,
                    Icons.access_time_rounded,
                    time,
                    alignRight: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String text, {
    bool alignRight = false,
  }) {
    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Icon(icon, size: AppDimens.iconMd, color: context.colorTextGrey),
        const SizedBox(width: AppDimens.spaceXs),
        Flexible(
          child: Text(
            text,
            style: AppTextStyles.bodySmall(context).copyWith(
              color: context.colorTextDark,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
