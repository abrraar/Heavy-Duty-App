import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';

class ChangeUsernameScreen extends StatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  State<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

class _ChangeUsernameScreenState extends State<ChangeUsernameScreen> {
  final _usernameController = TextEditingController();
  bool _isChecking = false;
  bool? _isAvailable;
  String? _errorText;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _usernameController.text = context.read<AuthProvider>().username;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  void _generateSuggestions(String base) {
    _suggestions = [
      "${base}_HIT",
      "${base}_ELITE",
      "${base}7",
      "PRO_$base",
      "${base}_GAINS",
    ];
  }

  Future<void> _handleVerifyAndSave() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) return;
    if (newUsername == context.read<AuthProvider>().username) {
       context.pop();
       return;
    }

    setState(() {
      _isChecking = true;
      _isAvailable = null;
      _errorText = null;
      _suggestions = [];
    });

    final authProv = context.read<AuthProvider>();
    final available = await authProv.checkUsernameAvailability(newUsername);

    if (available) {
      try {
        await authProv.updateUserProfile(username: newUsername);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("USERNAME UPDATED SUCCESSFULLY"), backgroundColor: Colors.green),
        );
        context.pop();
      } catch (e) {
        setState(() {
          _isChecking = false;
          _errorText = "FAILED TO UPDATE: ${e.toString().toUpperCase()}";
        });
      }
    } else {
      setState(() {
        _isChecking = false;
        _isAvailable = false;
        _errorText = "USERNAME IS ALREADY TAKEN";
        _generateSuggestions(newUsername);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = context.watch<AuthProvider>();
    final isLoading = authProv.isLoading || _isChecking;
    final currentUsername = authProv.username;
    final enteredUsername = _usernameController.text.trim();
    final isChanged = enteredUsername.isNotEmpty && enteredUsername != currentUsername;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const EliteSettingsAppBar(title: "IDENTITY"),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "CHANGE USERNAME",
                      style: AppTextStyles.h1.copyWith(fontSize: 32.sp, letterSpacing: -1),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "CHOOSE YOUR UNIQUE ELITE TAG",
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.5),
                    ),
                    SizedBox(height: 40.h),

                    _buildLabel("NEW USERNAME"),
                    TextField(
                      controller: _usernameController,
                      style: AppTextStyles.inputText.copyWith(color: Colors.white),
                      onChanged: (_) => setState(() {
                        _isAvailable = null;
                        _errorText = null;
                        _suggestions = [];
                      }),
                      decoration: InputDecoration(
                        hintText: "ENTER USERNAME",
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: AppColors.surfaceLight.withOpacity(0.3),
                        prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.crimson, size: 20.r),
                        suffixIcon: _isAvailable == true 
                          ? const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent)
                          : (_isAvailable == false ? const Icon(Icons.error_outline_rounded, color: AppColors.error) : null),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_errorText != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8.h, left: 4.w),
                        child: Text(
                          _errorText!, 
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error, 
                            fontSize: 10.sp, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),

                    if (_suggestions.isNotEmpty) ...[
                      SizedBox(height: 24.h),
                      _buildLabel("SUGGESTIONS"),
                      Wrap(
                        spacing: 8.w,
                        runSpacing: 10.h,
                        children: _suggestions.map((s) => GestureDetector(
                          onTap: () {
                            _usernameController.text = s;
                            setState(() {
                              _suggestions = [];
                              _errorText = null;
                              _isAvailable = null;
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color: AppColors.crimson.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(color: AppColors.crimson.withOpacity(0.3)),
                            ),
                            child: Text(
                              s, 
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.crimson, 
                                fontWeight: FontWeight.bold,
                                fontSize: 10.sp,
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                    ],

                    SizedBox(height: 60.h),
                    _PrimaryButton(
                      label: "VERIFY & SAVE",
                      isLoading: isLoading,
                      enabled: isChanged,
                      onTap: _handleVerifyAndSave,
                    ),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            ),
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
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  const _PrimaryButton({
    required this.label, 
    required this.onTap, 
    this.isLoading = false,
    this.enabled = true,
  });

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
            boxShadow: enabled ? [BoxShadow(color: AppColors.crimson.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))] : [],
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
