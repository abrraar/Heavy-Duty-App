// lib/core/widgets/app_search_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class AppSearchBar extends StatelessWidget {
  final TextEditingController? controller;
  final String hintText;
  final bool showAdd;
  final bool showFilter;
  final int? maxLength;
  final VoidCallback? onAddTap;
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;

  const AppSearchBar({
    super.key,
    this.controller,
    this.hintText = 'Search...',
    this.showAdd = true,
    this.showFilter = true,
    this.maxLength,
    this.onAddTap,
    this.onFilterTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44.h,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.white.withOpacity(0.05),
                  width: 0.8,
                ),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                maxLength: maxLength,
                inputFormatters: [
                  if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
                ],
                style: AppTextStyles.inputText.copyWith(
                  color: AppColors.white,
                  fontSize: 14.sp,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  hintText: hintText,
                  hintStyle: AppTextStyles.inputHint.copyWith(
                    color: AppColors.textSecondary.withOpacity(0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.crimson,
                    size: 18.r,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 8.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedButton(showFilter, Icons.tune_rounded, onFilterTap),
                _buildAnimatedButton(showAdd, Icons.add_rounded, onAddTap),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedButton(bool show, IconData icon, VoidCallback? onTap) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: ScaleTransition(scale: animation, child: child));
      },
      child: show
          ? _buildCompactIconButton(icon, onTap, key: ValueKey(icon))
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }

  Widget _buildCompactIconButton(IconData icon, VoidCallback? onTap, {Key? key}) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: 6.w),
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          icon,
          color: AppColors.white.withOpacity(0.9),
          size: 20.r,
        ),
      ),
    );
  }
}
