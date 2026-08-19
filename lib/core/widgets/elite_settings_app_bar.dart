import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/provider/auth_provider.dart';
import '../navigation/app_routes.dart';
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
              onPressed: onBackPressed ?? () {
                final authProv = context.read<AuthProvider>();

                // If we are currently in recovery mode, ensure we cancel it on back
                // to prevent any potential redirection issues.
                if (authProv.isPasswordRecoveryMode) {
                  authProv.cancelPasswordRecovery();
                }

                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
            ),
            Expanded(
              child: Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
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
