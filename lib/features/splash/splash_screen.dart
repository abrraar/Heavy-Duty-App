import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class FadeSplashScreen extends StatefulWidget {
  const FadeSplashScreen({super.key});

  @override
  State<FadeSplashScreen> createState() => _FadeSplashScreenState();
}

class _FadeSplashScreenState extends State<FadeSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        debugPrint("Splash: Animation completed. Preparing Hero flight...");
        // Wait briefly so the user sees the branding clearly
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            final authProv = context.read<AuthProvider>();
            if (authProv.isAuthenticated && authProv.isProfileComplete) {
              context.go(AppRoutes.home);
            } else {
              debugPrint("Splash: Navigating to LOGIN (Hero Takeoff)");
              context.push(AppRoutes.login);
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background, // Match native #0D0D0D exactly
      body: Center(
        child: Hero(
          tag: 'branding_title',
          child: Material(
            type: MaterialType.transparency,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'HEAVY\nDUTY',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(
                  fontSize: 80.sp, 
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                  height: 0.9,
                  letterSpacing: -2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
