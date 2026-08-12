import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class CycleStatusCard extends StatelessWidget {
  final String activeCycle;
  final int completedWorkouts;
  final int totalWorkouts;
  final double workOutputGrowth;

  const CycleStatusCard({
    super.key,
    required this.activeCycle,
    required this.completedWorkouts,
    required this.totalWorkouts,
    this.workOutputGrowth = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate progress fraction
    final double progress = totalWorkouts > 0 ? (completedWorkouts / totalWorkouts).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: double.infinity,
      // Increased height slightly to accommodate the progress bar while maintaining even spacing
      height: 145.h,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, color: AppColors.crimson, size: 20.r),
                  SizedBox(width: 8.w),
                  Text(
                    'CYCLE STATUS',
                    style: AppTextStyles.labelSmall.copyWith(
                      letterSpacing: 1.5,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (workOutputGrowth != 0)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: workOutputGrowth > 0 ? Colors.green.withOpacity(0.2) : AppColors.crimson.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    "${workOutputGrowth > 0 ? "+" : ""}${(workOutputGrowth * 100).toStringAsFixed(1)}% STRENGTH PROGRESS",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: workOutputGrowth > 0 ? Colors.greenAccent : AppColors.crimson,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          
          // Data Rows
          Column(
            children: [
              _buildStatusRow('Active Routine', activeCycle.toUpperCase()),
              SizedBox(height: 8.h),
              _buildStatusRow(
                'Overall Progress',
                '$completedWorkouts OF $totalWorkouts COMPLETED',
              ),
            ],
          ),

          // Progress Bar: Showing how far the user has progressed in the cycle
          ClipRRect(
            borderRadius: BorderRadius.circular(10.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.background.withOpacity(0.5),
              color: AppColors.crimson,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.white,
            fontSize: 12.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
