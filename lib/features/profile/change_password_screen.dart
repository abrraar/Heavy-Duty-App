import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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
      context.pop();
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
      EliteSnackbar.show(context, "RESET EMAIL SENT SUCCESSFULLY");
    } catch (e) {
      if (!mounted) return;
      EliteSnackbar.show(context, "ERROR: ${e.toString().toUpperCase()}", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("SECURITY", style: AppTextStyles.h3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "CHANGE PASSWORD",
              style: AppTextStyles.h1.copyWith(fontSize: 32.sp, letterSpacing: -1),
            ),
            SizedBox(height: 8.h),
            Text(
              "PROTECT YOUR HIGH INTENSITY DATA",
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5),
            ),
            SizedBox(height: 40.h),

            if (!_isCurrentVerified) ...[
              _buildLabel("CURRENT PASSWORD"),
              _buildTextField(
                controller: _currentPasswordController,
                hint: "ENTER CURRENT PASSWORD",
                icon: Icons.lock_outline,
                obscure: _obscureCurrent,
                toggleObscure: () => setState(() => _obscureCurrent = !_obscureCurrent),
              ),
              SizedBox(height: 24.h),
              _PrimaryButton(
                label: "VERIFY PASSWORD",
                isLoading: isLoading,
                onTap: _verifyCurrent,
              ),
              SizedBox(height: 32.h),
              Center(
                child: TextButton(
                  onPressed: isLoading ? null : _sendResetEmail,
                  child: Text(
                    "FORGOT CURRENT PASSWORD?",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.crimson,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
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
              _PrimaryButton(
                label: "UPDATE PASSWORD",
                isLoading: isLoading,
                onTap: _canSave ? _handleChangePassword : () {},
                enabled: _canSave,
              ),
            ],
          ],
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
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  const _PrimaryButton({required this.label, required this.onTap, this.isLoading = false, this.enabled = true});

  @override
  Widget build(BuildContext context) {
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
