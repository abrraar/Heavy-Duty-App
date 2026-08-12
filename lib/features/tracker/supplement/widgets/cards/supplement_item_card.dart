import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement_item.dart';
import 'package:intl/intl.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class SupplementItemCard extends StatelessWidget {
  final SupplementItem entry;

  const SupplementItemCard({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;

    if (entry.type == "Restock") {
      iconColor = Colors.green;
      iconData = Icons.inventory_2_outlined;
    } else if (entry.type == "Both") {
      iconColor = Colors.blueAccent;
      iconData = Icons.published_with_changes_rounded;
    } else {
      iconColor = AppColors.crimson;
      iconData = Icons.timer_outlined;
    }

    String? badgeText;
    Color? badgeColor;

    final String details = entry.details.toUpperCase();
    
    if (details.startsWith("MEAL LOG:")) {
      badgeText = "MEAL";
      badgeColor = Colors.orangeAccent;
    } else if (details.contains("NOTIFICATION")) {
      badgeText = "NOTIF";
      badgeColor = Colors.tealAccent;
    } else if (details.contains("QUICK LOG") || details.contains("QUICK RESTOCK")) {
      badgeText = "QUICK";
      badgeColor = Colors.blueAccent;
    } else if (details.contains("STACK LOG")) {
      badgeText = "STACK";
      badgeColor = AppColors.crimson;
    } else if (details.startsWith("INTAKE:") || details.startsWith("RESTOCK:")) {
      badgeText = "MANUAL";
      badgeColor = Colors.grey;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withOpacity(0.02)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(iconData, color: iconColor, size: 18.r),
          ),
          SizedBox(width: 15.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.supplementName.toUpperCase(),
                              style: AppTextStyles.labelMedium.copyWith(
                                fontSize: 14.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: badgeColor!.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4.r),
                                border: Border.all(color: badgeColor.withOpacity(0.2)),
                              ),
                              child: Text(
                                badgeText,
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: badgeColor,
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm | MMM d').format(entry.timestamp),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  entry.details,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white70,
                    fontSize: 10.sp,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
