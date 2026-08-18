import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isCurrentVerified = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  Timer? _resendTimer;
  int _secondsRemaining = 0;
  bool _canSendReset = true;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _canSendReset = false;
      _secondsRemaining = 60;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        setState(() {
          _canSendReset = true;
          timer.cancel();
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  bool get _canSave =>
      _newPasswordController.text.isNotEmpty &&
          _newPasswordController.text == _confirmPasswordController.text &&
          _newPasswordController.text.length >= 6;

  Future<void> _verifyCurrent() async {
    final password = _currentPasswordController.text;
    if (password.isEmpty) return;

    final authProv = context.read<AuthProvider>();
    final success = await authProv.verifyCurrentPassword(password);

    if (success) {
      setState(() => _isCurrentVerified = true);
    } else {
      if (!mounted) return;
      EliteSnackbar.show(context, "INVALID CURRENT PASSWORD", isError: true);
    }
  }

  Future<void> _handleChangePassword() async {
    final authProv = context.read<AuthProvider>();
    try {
      await authProv.updateUserPassword(_newPasswordController.text.trim());
      if (!mounted) return;

      EliteSnackbar.show(context, "PASSWORD CHANGED SUCCESSFULLY");

      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (!mounted) return;
      EliteSnackbar.show(context, "ERROR: ${e.toString().toUpperCase()}", isError: true);
    }
  }

  Future<void> _sendResetEmail() async {
    final authProv = context.read<AuthProvider>();
    final email = authProv.currentUser?.email;
    if (email == null) return;

    try {
      await authProv.sendPasswordResetEmail(email);
      if (!mounted) return;
      _startResendTimer();
      EliteSnackbar.show(context, "RESET EMAIL SENT SUCCESSFULLY");
    } catch (e) {
      if (!mounted) return;
      EliteSnackbar.show(context, "ERROR: ${e.toString().toUpperCase()}", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final isLoading = authProv.isLoading;
    final bool bypassVerification = authProv.isPasswordRecoveryMode;

    return PopScope(
      canPop: Navigator.of(context).canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && bypassVerification) {
          // If the user exits recovery mode without finishing, cancel the state
          // to prevent being trapped in the recovery redirect loop.
          context.read<AuthProvider>().cancelPasswordRecovery();
        }
        
        if (!didPop) {
          // Fallback for Cold Start: go to home if no stack
          context.go(AppRoutes.home);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              const EliteSettingsAppBar(title: "SECURITY"),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bypassVerification ? "RECOVER PASSWORD" : "CHANGE PASSWORD",
                        style: AppTextStyles.h1.copyWith(fontSize: 32.sp, letterSpacing: -1),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        bypassVerification ? "RESTORING AUTHENTICATION ACCESS" : "PROTECT YOUR HIGH INTENSITY DATA",
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5),
                      ),
                      SizedBox(height: 40.h),

                      if (!_isCurrentVerified && !bypassVerification) ...[
                        _buildLabel("CURRENT PASSWORD"),
                        _buildTextField(
                          controller: _currentPasswordController,
                          hint: "ENTER CURRENT PASSWORD",
                          icon: Icons.lock_outline,
                          obscure: _obscureCurrent,
                          toggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
                        ),
                        SizedBox(height: 24.h),
                        _buildPrimaryButton(
                          label: "VERIFY PASSWORD",
                          isLoading: isLoading,
                          onTap: _verifyCurrent,
                        ),
                        SizedBox(height: 32.h),
                        Center(
                          child: TextButton(
                            onPressed: (isLoading || !_canSendReset) ? null : _sendResetEmail,
                            child: Text(
                              _canSendReset ? "FORGOT CURRENT PASSWORD?" : "RESEND RESET LINK IN ${_secondsRemaining}S",
                              style: AppTextStyles.labelSmall.copyWith(
                                color: _canSendReset ? AppColors.crimson : AppColors.textSecondary.withOpacity(0.5),
                                fontWeight: FontWeight.bold,
                                decoration: _canSendReset ? TextDecoration.underline : TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        _buildLabel("NEW PASSWORD"),
                        _buildTextField(
                          controller: _newPasswordController,
                          hint: "ENTER NEW PASSWORD",
                          icon: Icons.vpn_key_outlined,
                          obscure: _obscureNew,
                          toggleObscure: () => setState(() => _obscureNew = !_obscureNew),
                          onChanged: (_) => setState(() {}),
                        ),
                        SizedBox(height: 20.h),
                        _buildLabel("CONFIRM NEW PASSWORD"),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          hint: "RE-TYPE NEW PASSWORD",
                          icon: Icons.check_circle_outline_rounded,
                          obscure: _obscureConfirm,
                          toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          onChanged: (_) => setState(() {}),
                        ),
                        if (_newPasswordController.text.isNotEmpty &&
                            _confirmPasswordController.text.isNotEmpty &&
                            _newPasswordController.text != _confirmPasswordController.text)
                          Padding(
                            padding: EdgeInsets.only(top: 8.h, left: 4.w),
                            child: Text("PASSWORDS DO NOT MATCH", style: TextStyle(color: AppColors.error, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                          ),
                        SizedBox(height: 40.h),
                        _buildPrimaryButton(
                          label: "UPDATE PASSWORD",
                          isLoading: isLoading,
                          onTap: _canSave ? _handleChangePassword : () {},
                          enabled: _canSave,
                        ),
                        if (bypassVerification) ...[
                          SizedBox(height: 16.h),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                authProv.cancelPasswordRecovery();
                                if (authProv.isAuthenticated) {
                                  context.go(AppRoutes.home);
                                } else {
                                  context.go(AppRoutes.login);
                                }
                              },
                              child: Text(
                                "CANCEL RECOVERY",
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white38,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h, left: 4.w),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? toggleObscure,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      style: AppTextStyles.inputText.copyWith(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: AppColors.surfaceLight.withOpacity(0.3),
        prefixIcon: Icon(icon, color: AppColors.crimson, size: 20.r),
        suffixIcon: toggleObscure != null
            ? IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.white24, size: 18.r),
          onPressed: toggleObscure,
        )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onTap, bool isLoading = false, bool enabled = true}) {
    return GestureDetector(
      onTap: (isLoading || !enabled) ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          width: double.infinity,
          height: 56.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: enabled ? [BoxShadow(color: AppColors.crimson.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : null,
          ),
          alignment: Alignment.center,
          child: isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : Text(label, style: AppTextStyles.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}
