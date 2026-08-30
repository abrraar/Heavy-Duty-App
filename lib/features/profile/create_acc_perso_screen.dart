import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/body_composition/model/body_comp_log.dart';
import 'package:uuid/uuid.dart';

class CreateAccPersoScreen extends StatefulWidget {
  const CreateAccPersoScreen({super.key});

  @override
  State<CreateAccPersoScreen> createState() => _CreateAccPersoScreenState();
}

class _CreateAccPersoScreenState extends State<CreateAccPersoScreen> {
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  DateTime? _selectedBirthday;
  String? _selectedGender;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) => child!,
    );
    if (picked != null && picked != _selectedBirthday) {
      setState(() => _selectedBirthday = picked);
    }
  }

  Future<void> _handleCompleteProfile() async {
    if (_isSaving) return;

    final name = _nameController.text.trim();
    final height = double.tryParse(_heightController.text.trim());

    if (name.isEmpty) {
      _showErrorSnackBar('PLEASE ENTER YOUR NAME');
      return;
    }

    try {
      setState(() => _isSaving = true);
      final authProv = context.read<AuthProvider>();
      final bodyProv = context.read<BodyCompProvider>();
      
      final double? weight = double.tryParse(_weightController.text.trim());

      await authProv.updateUserProfile(
        name: name,
        height: height,
        extraMetadata: {
          'birthday': _selectedBirthday?.toIso8601String(),
          'gender': _selectedGender,
          'weight': weight,
        },
      );

      if (weight != null && weight > 0) {
        final dualValues = bodyProv.calculateDualValues(weight, BodyMetricUnit.kg);
        
        await bodyProv.addLog(BodyCompLog(
          id: const Uuid().v4(),
          valueKg: dualValues['kg'] ?? weight,
          valueLbs: dualValues['lbs'] ?? (weight * 2.20462),
          type: BodyMetricType.weight,
          unit: BodyMetricUnit.kg,
          timestamp: DateTime.now(),
        ));
      }

      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showErrorSnackBar('FAILED TO UPDATE PROFILE: ${e.toString()}');
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
    final authProv = context.watch<AuthProvider>();
    final isLoading = authProv.isLoading || _isSaving;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: IntrinsicHeight(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: isCompact ? 40.h : 40.0),
                      Text(
                        'FINAL\nSTEPS',
                        style: AppTextStyles.h1.copyWith(
                          fontSize: isCompact ? 48.sp : 42.0,
                          height: 0.9,
                          color: AppColors.white,
                          letterSpacing: -2,
                        ),
                      ),
                      SizedBox(height: isCompact ? 12.h : 12.0),
                      Text(
                        'CUSTOMIZE YOUR HIGH INTENSITY PROFILE',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                          fontSize: isCompact ? null : 11.0,
                        ),
                      ),
                      SizedBox(height: isCompact ? 32.h : 32.0),
                      _InputField(
                        controller: _nameController,
                        hint: 'YOUR NAME',
                        icon: Icons.person_outline,
                        enabled: !isLoading,
                        isCompact: isCompact,
                      ),
                      SizedBox(height: isCompact ? 16.h : 16.0),
                      _SelectorField(
                        hint: _selectedBirthday == null 
                            ? 'PICK BIRTHDAY (OPTIONAL)' 
                            : DateFormat('MMM dd, yyyy').format(_selectedBirthday!).toUpperCase(),
                        icon: Icons.cake_outlined,
                        onTap: isLoading ? null : () => _selectBirthday(context),
                        isCompact: isCompact,
                      ),
                      SizedBox(height: isCompact ? 16.h : 16.0),
                      _GenderSelector(
                        selectedGender: _selectedGender,
                        onChanged: isLoading ? null : (gender) => setState(() => _selectedGender = gender),
                        isCompact: isCompact,
                      ),
                      SizedBox(height: isCompact ? 16.h : 16.0),
                      _InputField(
                        controller: _heightController,
                        hint: 'HEIGHT IN CM (OPTIONAL)',
                        icon: Icons.height_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final regEx = RegExp(r'^\d*\.?\d*$');
                            return regEx.hasMatch(newValue.text) ? newValue : oldValue;
                          }),
                        ],
                        enabled: !isLoading,
                        isCompact: isCompact,
                      ),
                      SizedBox(height: isCompact ? 16.h : 16.0),
                      _InputField(
                        controller: _weightController,
                        hint: 'BODY WEIGHT IN KG (OPTIONAL)',
                        icon: Icons.monitor_weight_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          TextInputFormatter.withFunction((oldValue, newValue) {
                            final regEx = RegExp(r'^\d*\.?\d*$');
                            return regEx.hasMatch(newValue.text) ? newValue : oldValue;
                          }),
                        ],
                        enabled: !isLoading,
                        isCompact: isCompact,
                      ),
                      const Spacer(),
                      _PrimaryButton(
                        label: "LET'S GET WITH IT",
                        isLoading: isLoading,
                        onTap: isLoading ? () {} : _handleCompleteProfile,
                        isCompact: isCompact,
                      ),
                      SizedBox(height: isCompact ? 40.h : 40.0),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final VoidCallback? onTap;
  final bool isCompact;

  const _SelectorField({
    required this.hint,
    required this.icon,
    this.onTap,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20.w : 20.0, 
          vertical: isCompact ? 18.h : 18.0
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
            SizedBox(width: isCompact ? 12.w : 12.0),
            Text(
              hint,
              style: AppTextStyles.labelSmall.copyWith(
                color: hint.contains('PICK') ? AppColors.textSecondary : AppColors.white,
                fontSize: isCompact ? 10.sp : 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final Function(String)? onChanged;
  final bool isCompact;

  const _GenderSelector({this.selectedGender, this.onChanged, this.isCompact = true});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildGenderButton('MALE', Icons.male_rounded)),
        SizedBox(width: isCompact ? 12.w : 12.0),
        Expanded(child: _buildGenderButton('FEMALE', Icons.female_rounded)),
      ],
    );
  }

  Widget _buildGenderButton(String gender, IconData icon) {
    final bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged!(gender) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 56.h : 54.0,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(
            color: isSelected ? AppColors.crimson : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.crimson : AppColors.textSecondary,
              size: isCompact ? 20.r : 20.0,
            ),
            SizedBox(width: isCompact ? 8.w : 8.0),
            Text(
              gender,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? AppColors.white : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                letterSpacing: 1,
                fontSize: isCompact ? null : 11.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool enabled;
  final bool isCompact;

  const _InputField({
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.enabled = true,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      enabled: enabled,
      style: AppTextStyles.inputText.copyWith(
        color: AppColors.white,
        fontSize: isCompact ? null : 14.0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          fontSize: isCompact ? 10.sp : 11.0,
        ),
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isCompact ? 20.w : 20.0, 
          vertical: isCompact ? 18.h : 18.0
        ),
        prefixIcon: icon != null
            ? Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0)
            : null,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isCompact;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.isCompact = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: isCompact ? 56.h : 54.0,
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          boxShadow: [
            BoxShadow(
              color: AppColors.crimson.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? SizedBox(
                height: isCompact ? 24.r : 24.0,
                width: isCompact ? 24.r : 24.0,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: isCompact ? null : 14.0,
                ),
              ),
      ),
    );
  }
}
