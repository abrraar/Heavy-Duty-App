import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement_stack.dart';

class StackQuickLogCard extends StatelessWidget {
  final SupplementStack stack;
  final VoidCallback onTap;

  const StackQuickLogCard({
    super.key,
    required this.stack,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 145.w,
        margin: EdgeInsets.only(right: 16.w),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withOpacity(0.6),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                "STACK",
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10.sp,
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              stack.name.toUpperCase(),
              maxLines: 2,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Container(
              padding: EdgeInsets.only(top: 8.h),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "${stack.items.length} ITEMS",
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 10.sp,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12.r,
                    color: AppColors.crimson,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
