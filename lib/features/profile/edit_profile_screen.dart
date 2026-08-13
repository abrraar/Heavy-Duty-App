import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  DateTime? _selectedBirthday;
  String? _selectedGender;
  
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    final authProv = context.read<AuthProvider>();
    _nameController = TextEditingController(text: authProv.displayName);
    _heightController = TextEditingController(text: authProv.height?.toStringAsFixed(0) ?? "");
    
    final metadata = authProv.currentUser?.userMetadata ?? {};
    if (metadata['birthday'] != null) {
      _selectedBirthday = DateTime.tryParse(metadata['birthday'].toString());
    }
    _selectedGender = metadata['gender']?.toString();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _nameController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _triggerAutoSave() {
    if (_autoSaveTimer?.isActive ?? false) _autoSaveTimer!.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 500), () {
      _handleSave();
    });
  }

  Future<void> _selectBirthday(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.crimson,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedBirthday = picked);
      _handleSave(); // Save immediately on selection
    }
  }

  Future<void> _handleSave() async {
    final authProv = context.read<AuthProvider>();
    
    try {
      final Map<String, dynamic> extraMetadata = {
        'gender': _selectedGender,
        'birthday': _selectedBirthday?.toIso8601String(),
      };

      await authProv.updateUserProfile(
        name: _nameController.text.trim(),
        height: double.tryParse(_heightController.text.trim()),
        extraMetadata: extraMetadata,
      );
      // Auto-save logic: silence is golden. No success snackbar needed.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("AUTO-SAVE FAILED: ${e.toString()}"), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const EliteSettingsAppBar(title: "EDIT PROFILE"),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("NAME"),
                    _buildTextField(_nameController, "YOUR NAME", Icons.person_outline, onChanged: (_) => _triggerAutoSave()),
                    SizedBox(height: 20.h),
                    
                    _buildLabel("GENDER"),
                    _GenderSelector(
                      selectedGender: _selectedGender,
                      onChanged: (val) {
                        setState(() => _selectedGender = val);
                        _handleSave(); // Save immediately
                      },
                    ),
                    SizedBox(height: 20.h),
                    
                    _buildLabel("BIRTHDAY"),
                    _SelectorField(
                      hint: _selectedBirthday == null 
                          ? 'PICK BIRTHDAY' 
                          : DateFormat('MMM dd, yyyy').format(_selectedBirthday!).toUpperCase(),
                      icon: Icons.cake_outlined,
                      onTap: () => _selectBirthday(context),
                    ),
                    SizedBox(height: 20.h),
                    
                    _buildLabel("HEIGHT (CM)"),
                    _buildTextField(_heightController, "180", Icons.height_outlined, isNumber: true, onChanged: (_) => _triggerAutoSave()),
                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationRow({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.crimson, size: 16.r),
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
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false, bool obscure = false, Function(String)? onChanged}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: AppTextStyles.inputText.copyWith(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: AppColors.surfaceLight.withOpacity(0.3),
        prefixIcon: Icon(icon, color: AppColors.crimson, size: 20.r),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
      ),
    );
  }
}

// Reuse components from CreateAccPersoScreen logic style
class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final Function(String) onChanged;
  const _GenderSelector({required this.selectedGender, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _buildGenderButton('MALE', Icons.male_rounded)),
        SizedBox(width: 12.w),
        Expanded(child: _buildGenderButton('FEMALE', Icons.female_rounded)),
      ],
    );
  }

  Widget _buildGenderButton(String gender, IconData icon) {
    final bool isSelected = selectedGender == gender;
    return GestureDetector(
      onTap: () => onChanged(gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56.h,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withOpacity(0.1) : AppColors.surfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: isSelected ? AppColors.crimson : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.crimson : AppColors.textSecondary, size: 20.r),
            SizedBox(width: 8.w),
            Text(gender, style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SelectorField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  const _SelectorField({required this.hint, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.crimson, size: 20.r),
            SizedBox(width: 12.w),
            Text(hint, style: AppTextStyles.labelSmall.copyWith(color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}
