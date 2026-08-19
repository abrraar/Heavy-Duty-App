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

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (username.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      EliteSnackbar.show(context, 'PLEASE FILL IN ALL FIELDS', isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      EliteSnackbar.show(context, 'PLEASE ENTER A VALID EMAIL ADDRESS', isError: true);
      return;
    }

    if (password != confirm) {
      EliteSnackbar.show(context, 'PASSWORDS DO NOT MATCH', isError: true);
      return;
    }

    try {
      final authProv = context.read<AuthProvider>();
      
      // 1. Check Username Availability
      final bool isAvailable = await authProv.checkUsernameAvailability(username);
      if (!isAvailable) {
        if (!mounted) return;
        EliteSnackbar.show(context, 'USERNAME IS ALREADY TAKEN', isError: true);
        return;
      }

      // 2. Proceed with Sign Up
      await authProv.signUp(email, password, username: username);
      if (!mounted) return;
      context.push(AppRoutes.otp);
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = "SIGN UP FAILED";
      if (e is AuthException) {
        final message = e.message.toLowerCase();
        if (message.contains("already registered")) {
          errorMessage = "THIS EMAIL IS ALREADY REGISTERED";
        } else if (message.contains("password")) {
          errorMessage = "PASSWORD IS TOO WEAK";
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
                  title: 'JOIN THE\nELITE',
                  subtitle: 'START YOUR HIGH INTENSITY JOURNEY',
                ),
                SizedBox(height: 40.h),
                _buildSignUpForm(isLoading),
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
                title: 'JOIN THE\nELITE',
                subtitle: 'START YOUR HIGH INTENSITY JOURNEY',
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
                child: _buildSignUpForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpForm(bool isLoading, {bool isWideLayout = false}) {
    final authProv = context.watch<AuthProvider>();
    final int cooldown = authProv.emailCooldownSeconds;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWideLayout) ...[
          Text(
            'CREATE ACCOUNT',
            style: AppTextStyles.h2.copyWith(
              color: AppColors.white,
              fontSize: 28.sp.clamp(24, 36),
            ),
          ),
          SizedBox(height: 24.h.clamp(16, 40)),
        ],
        AuthInputField(
          controller: _usernameController,
          hint: 'USERNAME',
          icon: Icons.person_outline,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 16.h.clamp(12, 24)),
        AuthInputField(
          controller: _emailController,
          hint: 'EMAIL ADDRESS',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 16.h.clamp(12, 24)),
        AuthInputField(
          controller: _passwordController,
          hint: 'PASSWORD',
          icon: Icons.lock_outline,
          obscure: _obscurePassword,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePassword = !_obscurePassword),
            child: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.inputHint,
              size: isWideLayout ? 20 : 20.r,
            ),
          ),
        ),
        SizedBox(height: 16.h.clamp(12, 24)),
        AuthInputField(
          controller: _confirmPasswordController,
          hint: 'CONFIRM PASSWORD',
          icon: Icons.lock_reset_outlined,
          obscure: _obscureConfirm,
          enabled: !isLoading,
          isWideLayout: isWideLayout,
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
            child: Icon(
              _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.inputHint,
              size: isWideLayout ? 20 : 20.r,
            ),
          ),
        ),
        SizedBox(height: 32.h.clamp(24, 48)),
        AuthPrimaryButton(
          label: cooldown > 0 ? 'WAIT ${cooldown}S' : 'CREATE ACCOUNT',
          isLoading: isLoading,
          onTap: cooldown > 0 ? () {} : _handleSignUp,
          isWideLayout: isWideLayout,
        ),
        SizedBox(height: 24.h.clamp(16, 40)),
        AuthDividerWithText(text: 'OR SIGN UP WITH', isWideLayout: isWideLayout),
        SizedBox(height: 24.h.clamp(16, 40)),
        Row(
          children: [
            Expanded(
              child: AuthSocialIconButton(
                icon: Icons.g_mobiledata_rounded,
                color: AppColors.google,
                onTap: () {},
                isWideLayout: isWideLayout,
              ),
            ),
            SizedBox(width: isWideLayout ? 16 : 16.w),
            Expanded(
              child: AuthSocialIconButton(
                icon: Icons.facebook_rounded,
                color: AppColors.facebook,
                onTap: () {},
                isWideLayout: isWideLayout,
              ),
            ),
          ],
        ),
        SizedBox(height: 48.h.clamp(32, 80)),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Already have an account? ",
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
