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
  late Animation<double> _glowAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500), 
    );

    // Subtle Glow: Pulsing the shadow blur radius
    _glowAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // Fade sequence: In quietly, then out as we transition
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          final authProv = context.read<AuthProvider>();
          if (authProv.isAuthenticated && authProv.isProfileComplete) {
            context.go(AppRoutes.home);
          } else {
            context.go(AppRoutes.login);
          }
        }
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
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: child,
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                type: MaterialType.transparency,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Text(
                        'HEAVY\nDUTY',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h1.copyWith(
                          fontSize: 80.sp, 
                          color: AppColors.white,
                          fontWeight: FontWeight.w500,
                          height: 0.9,
                          letterSpacing: -2,
                          shadows: [
                            Shadow(
                              color: Colors.white.withOpacity(0.3),
                              blurRadius: _glowAnimation.value,
                              offset: Offset.zero,
                            ),
                            Shadow(
                              color: AppColors.crimson.withOpacity(0.2),
                              blurRadius: _glowAnimation.value * 1.5,
                              offset: Offset.zero,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
