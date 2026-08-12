import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
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

  @override
  void dispose() {
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
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      _showErrorSnackBar('PLEASE ENTER THE FULL 6-DIGIT CODE');
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final email = authProvider.pendingEmail;

      if (email == null) {
        _showErrorSnackBar('SESSION EXPIRED. PLEASE SIGN UP AGAIN.');
        context.go(AppRoutes.signin);
        return;
      }

      await authProvider.verifyOTPCode(email, otp);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('VERIFICATION FAILED: ${e.toString().toUpperCase()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.bodySmall),
        backgroundColor: AppColors.error,
      ),
    );
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
                onPressed: isLoading
                    ? null
                    : () async {
                        final authProvider = context.read<AuthProvider>();
                        final email = authProvider.pendingEmail;
                        if (email != null) {
                          try {
                            await authProvider.resendOTP(email);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('CODE RESENT SUCCESSFULLY!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            _showErrorSnackBar(e.toString().toUpperCase());
                          }
                        }
                      },
                child: Text(
                  'RESEND OTP',
                  style: AppTextStyles.link.copyWith(
                    color: AppColors.crimson,
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
          color: AppColors.crimson,
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
