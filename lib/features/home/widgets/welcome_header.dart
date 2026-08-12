import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class WelcomeHeader extends StatelessWidget {
  const WelcomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final String name = authProvider.displayName.toUpperCase();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WELCOME BACK, $name',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.crimson,
                letterSpacing: 2,
                fontSize: 12.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'READY FOR INTENSITY?',
              style: AppTextStyles.h1.copyWith(
                fontSize: 32.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        );
      },
    );
  }
}
