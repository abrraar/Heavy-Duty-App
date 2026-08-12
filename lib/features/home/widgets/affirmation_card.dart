import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/affirmation/affirmation_screen.dart';
import 'package:heavy_duty/features/affirmation/provider/affirmation_provider.dart';
import 'package:provider/provider.dart';

class AffirmationCard extends StatelessWidget {
  const AffirmationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AffirmationProvider>(
      builder: (context, provider, _) {
        final current = provider.currentAffirmation;
        if (current == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AffirmationScreen()),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16.w, 4.h, 0, 4.h),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.crimson,
                  width: 3,
                ),
              ),
            ),
            child: Text(
              '"${current.text}"',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.5,
                fontSize: 14.sp,
              ),
            ),
          ),
        );
      },
    );
  }
}
