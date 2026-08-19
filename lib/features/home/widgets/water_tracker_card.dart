import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/hydration/widgets/water_glass_widget.dart';

class WaterTrackerCard extends StatelessWidget {
  final int currentMl;
  final int targetMl;
  final int addValueMl;
  final int minusValueMl;
  final bool useMetric;
  final Function(int) onAdjust;

  const WaterTrackerCard({
    super.key,
    required this.currentMl,
    required this.targetMl,
    required this.addValueMl,
    required this.minusValueMl,
    required this.useMetric,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    double progress = (currentMl / targetMl).clamp(0.0, 1.0);
    const double mlToOzFactor = 0.03;
    String displayCurrent = useMetric ? currentMl.toString() : (currentMl * mlToOzFactor).toStringAsFixed(1);
    String displayTarget = useMetric ? targetMl.toString() : (targetMl * mlToOzFactor).toStringAsFixed(0);
    String unit = useMetric ? "ML" : "OZ";

    return Container(
      width: double.infinity,
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.water_drop_rounded, color: Colors.blueAccent, size: 20.r),
                        SizedBox(width: 8.w),
                        Text(
                          'HYDRATION',
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 12.sp,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '$displayCurrent / $displayTarget $unit',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      progress >= 1.0 ? "GOAL REACHED" : "REMAINING: ${useMetric ? (targetMl - currentMl) : ((targetMl - currentMl) * mlToOzFactor).toStringAsFixed(1)} $unit",
                      style: AppTextStyles.labelSmall.copyWith(
                        color: progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  WaterGlassWidget(progress: progress, size: 45),
                  SizedBox(height: 4.h),
                  Text(
                    "${(progress * 100).toInt()}%",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: progress >= 1.0 ? Colors.greenAccent : Colors.blueAccent,
                      fontWeight: FontWeight.w500,
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBtn(
                useMetric ? "-${minusValueMl}ML" : "-${(minusValueMl * mlToOzFactor).toStringAsFixed(1)}OZ", 
                -minusValueMl, 
                true
              ),
              SizedBox(width: 24.w),
              _buildBtn(
                useMetric ? "+${addValueMl}ML" : "+${(addValueMl * mlToOzFactor).toStringAsFixed(1)}OZ", 
                addValueMl, 
                false
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(String label, int amountMl, bool isSub) {
    return GestureDetector(
      onTap: () => onAdjust(amountMl),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSub ? AppColors.error.withOpacity(0.5) : AppColors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSub ? AppColors.error : AppColors.white,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
