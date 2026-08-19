import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class CycleMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? date;

  const CycleMetricTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.crimson, size: 20.r),
          SizedBox(height: 8.r), // Standardized spacing
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 9.sp,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4.r),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMedium.copyWith(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (date != null)
            Padding(
              padding: EdgeInsets.only(top: 8.r),
              child: Text(
                date!,
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 9.sp,
                  color: AppColors.textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
