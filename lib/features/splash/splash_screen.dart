import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
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
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), 
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // SMALL PAUSE TO SHOW THE BRANDING BEFORE HERO FLIGHT
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            final authProv = context.read<AuthProvider>();
            // Direct landing logic to preserve Hero flight
            if (authProv.isAuthenticated && authProv.isProfileComplete) {
              context.go(AppRoutes.home);
            } else {
              // NAVIGATION TO LOGIN TRIGGERS HERO FLIGHT
              context.go(AppRoutes.login);
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
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeInAnimation,
          child: Hero(
            tag: 'branding_title',
            // Material wrapper is essential for Hero typography during flight
            child: Material(
              type: MaterialType.transparency,
              child: Text(
                'HEAVY\nDUTY',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(
                  fontSize: 80.sp, 
                  color: Colors.white,
                  fontWeight: FontWeight.w500, // Matched with Login weight
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
