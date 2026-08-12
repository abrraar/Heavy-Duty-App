import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart'; // Ensure correct path to app_routes.dart

class FadeSplashScreen extends StatefulWidget {
  const FadeSplashScreen({super.key});

  @override
  State<FadeSplashScreen> createState() => _FadeSplashScreenState();
}

class _FadeSplashScreenState extends State<FadeSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _fadeOutAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000), // Clean 2-second splash
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _fadeOutAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          // After splash, go to root. The router will then decide
          // based on auth state if we should go to Home or Login.
          context.go(AppRoutes.root);
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
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final combinedOpacity =
                _fadeInAnimation.value * _fadeOutAnimation.value;
            return Opacity(opacity: combinedOpacity, child: child);
          },
          child: Text(
            'HEAVY\nDUTY',
            textAlign: TextAlign.center,
            style: AppTextStyles.displayLarge.copyWith(
              fontSize: 100,
              color: Colors.white,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
