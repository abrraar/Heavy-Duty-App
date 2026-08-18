import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  
  Timer? _resendTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    setState(() {
      _canResend = false;
      _secondsRemaining = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _verifyOtp() async {
    if (_isVerifying) return;

    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      EliteSnackbar.show(context, 'PLEASE ENTER THE FULL 6-DIGIT CODE', isError: true);
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final email = authProvider.pendingEmail;

      if (email == null) {
        // If we are already verifying, don't show session expired as we're likely transitioning
        if (!_isVerifying) {
          EliteSnackbar.show(context, 'SESSION EXPIRED. PLEASE SIGN UP AGAIN.', isError: true);
          context.go(AppRoutes.signin);
        }
        return;
      }

      setState(() => _isVerifying = true);
      await authProvider.verifyOTPCode(email, otp);
      
      // Explicit navigation safety: The router SHOULD handle this via redirect, 
      // but adding a guard to prevent further interaction on this screen.
    } catch (e) {
      if (!mounted) return;
      setState(() => _isVerifying = false);
      
      String errorMessage = "VERIFICATION FAILED";
      if (e is AuthException) {
        final message = e.message.toLowerCase();
        if (message.contains("invalid") || message.contains("token")) {
          errorMessage = "INVALID OR EXPIRED VERIFICATION CODE";
        } else if (message.contains("too many")) {
          errorMessage = "TOO MANY ATTEMPTS. PLEASE WAIT.";
        } else {
          errorMessage = e.message.toUpperCase();
        }
      } else {
        errorMessage = e.toString().toUpperCase();
      }

      EliteSnackbar.show(context, errorMessage, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.isLoading || _isVerifying;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < kMobileBreakpoint;
          final isLargeScreen = constraints.maxWidth > kTabletBreakpoint;
          final double formMaxWidth = isLargeScreen ? 600 : 500;

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
                  title: 'VERIFY\nIDENTITY',
                  subtitle: 'ENTER THE 6-DIGIT CODE SENT TO YOUR EMAIL',
                ),
                SizedBox(height: 60.h),
                _buildOtpForm(isLoading),
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
                title: 'VERIFY\nIDENTITY',
                subtitle: 'ENTER THE 6-DIGIT CODE SENT TO YOUR EMAIL',
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
                padding: const EdgeInsets.all(48),
                child: _buildOtpForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpForm(bool isLoading, {bool isWideLayout = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            6,
            (index) => _buildOtpBox(index, !isLoading, isWideLayout),
          ),
        ),
        SizedBox(height: 40.h.clamp(32, 64)),
        AuthPrimaryButton(
          label: 'VERIFY CODE',
          isLoading: isLoading,
          onTap: _verifyOtp,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 48.h.clamp(32, 80)),
        Center(
          child: Column(
            children: [
              Text(
                "Didn't receive the code?",
                style: AppTextStyles.caption.copyWith(fontSize: isWideLayout ? 14 : 13.sp),
              ),
              TextButton(
                onPressed: (isLoading || !_canResend)
                    ? null
                    : () async {
                        final authProvider = context.read<AuthProvider>();
                        final email = authProvider.pendingEmail;
                        if (email != null) {
                          try {
                            await authProvider.resendOTP(email);
                            if (!mounted) return;
                            _startResendTimer();
                            EliteSnackbar.show(context, 'CODE RESENT SUCCESSFULLY!');
                          } catch (e) {
                            if (!mounted) return;
                            String error = "RESEND FAILED";
                            if (e is AuthException) {
                              if (e.message.toLowerCase().contains("too many")) {
                                error = "PLEASE WAIT BEFORE REQUESTING A NEW CODE";
                              } else {
                                error = e.message.toUpperCase();
                              }
                            }
                            EliteSnackbar.show(context, error, isError: true);
                          }
                        }
                      },
                child: Text(
                  _canResend ? 'RESEND OTP' : 'RESEND OTP IN ${_secondsRemaining}S',
                  style: AppTextStyles.link.copyWith(
                    color: _canResend ? AppColors.crimson : AppColors.textSecondary.withOpacity(0.5),
                    fontWeight: FontWeight.bold,
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

  Widget _buildOtpBox(int index, bool enabled, bool isWideLayout) {
    return SizedBox(
      width: isWideLayout ? 60 : 45.w,
      height: isWideLayout ? 70 : 56.h,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        onChanged: (v) => _onChanged(v, index),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        enabled: enabled,
        style: AppTextStyles.h3.copyWith(
          color: Colors.white,
          fontSize: isWideLayout ? 24 : 20.sp,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          filled: true,
          fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
          ),
        ),
      ),
    );
  }
}
