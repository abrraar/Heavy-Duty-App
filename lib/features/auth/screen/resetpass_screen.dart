import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/constants/dimensions.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/auth/widgets/auth_components.dart';

class ResetPassScreen extends StatefulWidget {
  const ResetPassScreen({super.key});

  @override
  State<ResetPassScreen> createState() => _ResetPassScreenState();
}

class _ResetPassScreenState extends State<ResetPassScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    final pass = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (pass.isEmpty || confirm.isEmpty) {
      _showSnackBar('PLEASE FILL IN BOTH FIELDS', isError: true);
      return;
    }
    if (pass != confirm) {
      _showSnackBar('PASSWORDS DO NOT MATCH', isError: true);
      return;
    }

    try {
      if (!mounted) return;
      _showSnackBar('PASSWORD UPDATED SUCCESSFULLY!', isError: false);
      context.go(AppRoutes.login);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('UPDATE FAILED: ${e.toString().toUpperCase()}', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTextStyles.bodySmall),
        backgroundColor: isError ? AppColors.error : Colors.green,
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
                  title: 'NEW\nSTRENGTH',
                  subtitle: 'SET YOUR NEW SECURE PASSWORD',
                ),
                SizedBox(height: 60.h),
                _buildResetPassForm(isLoading),
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
                title: 'NEW\nSTRENGTH',
                subtitle: 'SET YOUR NEW SECURE PASSWORD',
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
                child: _buildResetPassForm(isLoading, isWideLayout: true),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResetPassForm(bool isLoading, {bool isWideLayout = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuthInputField(
          controller: _passwordController,
          hint: 'NEW PASSWORD',
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
          hint: 'CONFIRM NEW PASSWORD',
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
        SizedBox(height: 40.h.clamp(24, 64)),
        AuthPrimaryButton(
          label: 'UPDATE PASSWORD',
          isLoading: isLoading,
          onTap: _handleReset,
          isWideLayout: isWideLayout,
        ),
      ],
    );
  }
}
