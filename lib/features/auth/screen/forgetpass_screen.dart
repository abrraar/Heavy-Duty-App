import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/auth/widgets/auth_components.dart';

class ForgotPassScreen extends StatefulWidget {
  const ForgotPassScreen({super.key});

  @override
  State<ForgotPassScreen> createState() => _ForgotPassScreenState();
}

class _ForgotPassScreenState extends State<ForgotPassScreen> {
  final _emailController = TextEditingController();
  
  Timer? _resendTimer;
  int _secondsRemaining = 0;
  bool _canSend = true;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canSend = false;
      _secondsRemaining = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canSend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE ENTER YOUR EMAIL', isError: true);
      return;
    }

    try {
      await context.read<AuthProvider>().sendPasswordResetEmail(email, source: 'auth');
      
      if (!mounted) return;
      _startResendTimer();
      EliteSnackbar.show(context, 'RESET LINK SENT SUCCESSFULLY!');
    } catch (e) {
      if (!mounted) return;
      
      String errorMsg = "SEND FAILED";
      if (e is AuthException) {
        if (e.message.toLowerCase().contains("not found")) {
          errorMsg = "USER NOT FOUND";
        } else if (e.message.toLowerCase().contains("too many")) {
          errorMsg = "PLEASE WAIT BEFORE TRYING AGAIN";
        } else {
          errorMsg = e.message.toUpperCase();
        }
      } else {
        errorMsg = e.toString().toUpperCase();
      }
      
      EliteSnackbar.show(context, errorMsg, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < kMobileBreakpoint;
          final isLargeScreen = constraints.maxWidth > kTabletBreakpoint;
          final double formMaxWidth = isLargeScreen ? 480 : 420;

          if (isSmallScreen) {
            return _buildMobileLayout(isLoading);
          } else {
            return _buildWideLayout(isLoading, constraints, formMaxWidth);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(bool isLoading) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 450),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthBrandingSection(
                  title: 'RECOVER\nACCESS',
                  subtitle: 'GET BACK TO YOUR TRAINING',
                ),
                SizedBox(height: 60.h),
                _buildForgotPassForm(isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(bool isLoading, BoxConstraints constraints, double formMaxWidth) {
    return Row(
      children: [
        Expanded(
          flex: constraints.maxWidth > kTabletBreakpoint ? 4 : 3,
          child: Container(
            color: AppColors.surface.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(64),
            child: const Center(
              child: AuthBrandingSection(
                title: 'RECOVER\nACCESS',
                subtitle: 'GET BACK TO YOUR TRAINING',
                isWideLayout: true,
              ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: formMaxWidth),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: _buildForgotPassForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForgotPassForm(bool isLoading, {bool isWideLayout = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthDividerWithText(text: 'RECEIVE OTP VIA EMAIL', isWideLayout: isWideLayout),
        SizedBox(height: 28.h.clamp(20, 40)),
        AuthInputField(
          controller: _emailController,
          hint: 'EMAIL ADDRESS',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 32.h.clamp(24, 48)),
        AuthPrimaryButton(
          label: _canSend ? 'SEND RESET LINK' : 'RESEND IN ${_secondsRemaining}S',
          isLoading: isLoading,
          onTap: _canSend ? _handleSendOtp : () {},
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 48.h.clamp(32, 80)),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Remember your password? ",
                style: AppTextStyles.caption.copyWith(
                  fontSize: isWideLayout ? 14 : 13.sp,
                ),
              ),
              GestureDetector(
                onTap: isLoading ? null : () => context.go(AppRoutes.login),
                child: Text(
                  'LOG IN',
                  style: AppTextStyles.link.copyWith(
                    color: AppColors.crimson,
                    fontWeight: FontWeight.w500,
                    fontSize: isWideLayout ? 14 : 13.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
