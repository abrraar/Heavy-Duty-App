import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class EliteSettingsAppBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBackPressed;

  const EliteSettingsAppBar({
    super.key,
    required this.title,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.white,
              ),
              onPressed: onBackPressed ?? () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Dummy icon to perfectly center the title
            const Opacity(
              opacity: 0,
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
