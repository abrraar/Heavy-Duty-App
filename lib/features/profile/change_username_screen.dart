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

    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;
            final bool isWideLandscape = isLargeScreen && MediaQuery.of(context).orientation == Orientation.landscape;

            return Column(
              children: [
                EliteSettingsAppBar(
                  title: "IDENTITY", 
                  isCompact: isCompact,
                  showBackButton: !isWideLandscape,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLargeScreen ? 24.0 : 24.w, 
                      vertical: isLargeScreen ? 24.0 : 24.r
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "CHANGE USERNAME",
                          style: AppTextStyles.h1.copyWith(
                            fontSize: isLargeScreen ? 28.0 : 32.sp, 
                            letterSpacing: -1
                          ),
                        ),
                        SizedBox(height: isLargeScreen ? 8.0 : 8.h),
                        Text(
                          "CHOOSE YOUR UNIQUE ELITE TAG",
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary, 
                            letterSpacing: 1.5,
                            fontSize: isLargeScreen ? 11.0 : null,
                          ),
                        ),
                        SizedBox(height: isLargeScreen ? 40.0 : 40.h),

                        _buildLabel("NEW USERNAME", isCompact, isLargeScreen),
                        TextField(
                          controller: _usernameController,
                          style: AppTextStyles.inputText.copyWith(
                            color: Colors.white,
                            fontSize: isLargeScreen ? 14.0 : null,
                          ),
                          onChanged: (_) => setState(() {
                            _isAvailable = null;
                            _errorText = null;
                            _suggestions = [];
                          }),
                          decoration: InputDecoration(
                            hintText: "ENTER USERNAME",
                            hintStyle: TextStyle(
                              color: Colors.white24,
                              fontSize: isLargeScreen ? 14.0 : null,
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded, 
                              color: AppColors.crimson, 
                              size: isLargeScreen ? 20.0 : 20.r
                            ),
                            suffixIcon: _isAvailable == true 
                              ? const Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent)
                              : (_isAvailable == false ? const Icon(Icons.error_outline_rounded, color: AppColors.error) : null),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r), 
                              borderSide: BorderSide.none
                            ),
                          ),
                        ),
                        if (_errorText != null)
                          Padding(
                            padding: EdgeInsets.only(
                              top: isLargeScreen ? 8.0 : 8.h, 
                              left: isLargeScreen ? 4.0 : 4.w
                            ),
                            child: Text(
                              _errorText!, 
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.error, 
                                fontSize: isLargeScreen ? 10.0 : 10.sp,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),

                        if (_suggestions.isNotEmpty) ...[
                          SizedBox(height: isLargeScreen ? 24.0 : 24.h),
                          _buildLabel("SUGGESTIONS", isCompact, isLargeScreen),
                          Wrap(
                            spacing: isLargeScreen ? 8.0 : 8.w,
                            runSpacing: isLargeScreen ? 10.0 : 10.h,
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: isLargeScreen ? 12.0 : 12.w, 
                                  vertical: isLargeScreen ? 8.0 : 8.h
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.crimson.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(isLargeScreen ? 6.0 : 8.r),
                                  border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  s, 
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.crimson, 
                                    fontWeight: FontWeight.w500,
                                    fontSize: isLargeScreen ? 10.0 : 10.sp,
                                  ),
                                ),
                              ),
                            )).toList(),
                          ),
                        ],

                        SizedBox(height: isLargeScreen ? 60.0 : 60.h),
                        _PrimaryButton(
                          label: "VERIFY & SAVE",
                          isLoading: isLoading,
                          enabled: isChanged,
                          onTap: _handleVerifyAndSave,
                          isLargeScreen: isLargeScreen,
                        ),
                        SizedBox(height: isLargeScreen ? 20.0 : 20.h),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isCompact, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLargeScreen ? 8.0 : 8.h, 
        left: isLargeScreen ? 4.0 : 4.w
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary, 
          letterSpacing: 1.5, 
          fontWeight: FontWeight.w500,
          fontSize: isLargeScreen ? 11.0 : null,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool enabled;
  final bool isLargeScreen;
  const _PrimaryButton({
    required this.label, 
    required this.onTap, 
    this.isLoading = false, 
    this.enabled = true,
    this.isLargeScreen = false,
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
          height: isLargeScreen ? 54.0 : 56.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r),
            boxShadow: enabled ? [
              BoxShadow(
                color: AppColors.crimson.withValues(alpha: 0.3), 
                blurRadius: 15, 
                offset: const Offset(0, 8)
              )
            ] : [],
          ),
          alignment: Alignment.center,
          child: isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                label, 
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white, 
                  fontWeight: FontWeight.w500,
                  fontSize: isLargeScreen ? 14.0 : null,
                ),
              ),
        ),
      ),
    );
  }
}
