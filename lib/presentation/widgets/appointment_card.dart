import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/theme/app_shapes.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_styles.dart';
import '../../features/appointments/presentation/widgets/live_countdown_badge.dart';
import 'app_network_image.dart';

class AppointmentCard extends StatelessWidget {
  final String bookingId;
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
  final VoidCallback onReceiptTap;

  const AppointmentCard({
    super.key,
    required this.bookingId,
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
    required this.onReceiptTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        status == 'waiting'
            ? Colors.amber.withValues(alpha: 0.5)
            : (isDark
                ? AppColors.darkBorder
                : context.colorBorder.withValues(alpha: 0.5));

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceLg),
      decoration: AppStyles.surfaceCard(
        context,
        borderRadius: AppShapes.xl,
      ).copyWith(border: Border.all(color: borderColor)),
      // PRO FIX: ClipRRect ensures the bottom InkWell perfectly hugs the card corners
      child: ClipRRect(
        borderRadius: AppShapes.xl,
        child: Column(
          children: [
            // --- TOP SECTION: Medical Info (Padded) ---
            Padding(
              padding: const EdgeInsets.all(AppDimens.spaceXl),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: AppShapes.lg,
                          color:
                              isDark ? AppColors.darkBorder : Colors.grey[100],
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: AppTextStyles.h3(
                                          context,
                                        ).copyWith(fontSize: 18),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        specialty,
                                        style: AppTextStyles.body(
                                          context,
                                        ).copyWith(
                                          color: context.colorTextLight,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
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
                            const SizedBox(height: 12),
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

            // --- SEPARATOR: Ticket Tear-Off Dashed Line ---
            SizedBox(
              width: double.infinity,
              height: 1,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dashCount = (constraints.constrainWidth() / 8).floor();
                  return Flex(
                    direction: Axis.horizontal,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(dashCount, (_) {
                      return SizedBox(
                        width: 4,
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.colorBorder.withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

            // --- BOTTOM SECTION: Integrated Action Stub ---
            Material(
              color:
                  isDark
                      ? Colors.white.withValues(alpha: 0.02)
                      : AppColors.primaryGreen.withValues(alpha: 0.03),
              child: InkWell(
                onTap: onReceiptTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceXl,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          "View Digital Receipt",
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.colorTextLight,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
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
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
