import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EliteUnitToggleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> options;
  final int selectedIndex;
  final Function(int) onSelected;
  final Color selectedColor;

  const EliteUnitToggleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.selectedColor = AppColors.crimson,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  subtitle,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10.sp,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          _EliteToggle(
            options: options,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
            selectedColor: selectedColor,
          ),
        ],
      ),
    );
  }
}

class _EliteToggle extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final Function(int) onSelected;
  final Color selectedColor;

  const _EliteToggle({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A), // Deep carbon black background
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(options.length, (index) {
          final bool isSelected = index == selectedIndex;
          return GestureDetector(
            onTap: () => onSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.transparent,
                borderRadius: BorderRadius.circular(10.r),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                options[index],
                style: AppTextStyles.labelSmall.copyWith(
                  color: isSelected ? Colors.white : AppColors.textSecondary.withValues(alpha: 0.4),
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                  fontSize: 11.sp,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
