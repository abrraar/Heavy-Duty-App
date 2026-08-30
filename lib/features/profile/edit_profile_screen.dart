import 'dart:async';
import 'package:flutter/material.dart';
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
    _selectedBirthday = authProv.birthday;
    _selectedGender = authProv.gender;
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
      builder: (context, child) => child!,
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
      // In an offline-first app, we suppress network-related auto-save errors.
      // The provider will handle background synchronization silently.
      final errorStr = e.toString().toLowerCase();
      final isNetworkError = errorStr.contains('socketexception') || 
                             errorStr.contains('clientexception') ||
                             errorStr.contains('failed host lookup') ||
                             errorStr.contains('errno = 7');
      
      if (!isNetworkError) {
        debugPrint("EditProfile: Non-network auto-save error: $e");
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "AUTO-SAVE FAILED: ${e.toString().toUpperCase()}",
              style: AppTextStyles.labelSmall.copyWith(color: Colors.white),
            ), 
            backgroundColor: AppColors.error
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600;
            return Column(
              children: [
                EliteSettingsAppBar(title: "EDIT PROFILE", isCompact: isCompact),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0, vertical: isCompact ? 24.r : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                            _buildLabel("NAME", isCompact),
                            _buildTextField(
                              _nameController, 
                              "YOUR NAME", 
                              Icons.person_outline, 
                              onChanged: (_) => _triggerAutoSave(),
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20.h : 20.0),
                            
                            _buildLabel("GENDER", isCompact),
                            _GenderSelector(
                              selectedGender: _selectedGender,
                              onChanged: (val) {
                                setState(() => _selectedGender = val);
                                _handleSave(); // Save immediately
                              },
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20.h : 20.0),
                            
                            _buildLabel("BIRTHDAY", isCompact),
                            _SelectorField(
                              hint: _selectedBirthday == null 
                                  ? 'PICK BIRTHDAY' 
                                  : DateFormat('MMM dd, yyyy').format(_selectedBirthday!).toUpperCase(),
                              icon: Icons.cake_outlined,
                              onTap: () => _selectBirthday(context),
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 20.h : 20.0),
                            
                            _buildLabel("HEIGHT (CM)", isCompact),
                            _buildTextField(
                              _heightController, 
                              "180", 
                              Icons.height_outlined, 
                              isNumber: true, 
                              onChanged: (_) => _triggerAutoSave(),
                              isCompact: isCompact,
                            ),
                            SizedBox(height: isCompact ? 40.h : 40.0),
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

  Widget _buildNavigationRow({required String label, required VoidCallback onTap, required bool isCompact}) {
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.0,
                fontSize: isCompact ? 15.sp : 12.0,
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.crimson, size: isCompact ? 16.r : 16.0),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isCompact ? 8.h : 8.0, 
        left: isCompact ? 4.w : 4.0
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w500,
          fontSize: isCompact ? 14.sp : 11.0,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hint, 
    IconData icon, 
    {bool isNumber = false, bool obscure = false, Function(String)? onChanged, required bool isCompact}
  ) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: AppTextStyles.inputText.copyWith(
        color: Colors.white,
        fontSize: isCompact ? 16.sp : 14.0,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.white24,
          fontSize: isCompact ? 16.sp : 14.0,
        ),
        filled: true,
        fillColor: AppColors.surfaceLight.withValues(alpha: 0.3),
        prefixIcon: Icon(icon, color: AppColors.crimson, size: isCompact ? 20.r : 20.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0), 
          borderSide: BorderSide.none
        ),
      ),
    );
  }
}

// Reuse components from CreateAccPersoScreen logic style
class _GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final Function(String) onChanged;
  final bool isCompact;
  const _GenderSelector({required this.selectedGender, required this.onChanged, this.isCompact = true});

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
      onTap: () => onChanged(gender),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isCompact ? 56.h : 54.0,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surfaceLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0),
          border: Border.all(color: isSelected ? AppColors.crimson : Colors.transparent, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? AppColors.crimson : AppColors.textSecondary, size: isCompact ? 20.r : 20.0),
            SizedBox(width: isCompact ? 8.w : 8.0),
            Text(
              gender, 
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary, 
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                fontSize: isCompact ? 14.sp : 11.0,
              )
            ),
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
  final bool isCompact;
  const _SelectorField({required this.hint, required this.icon, required this.onTap, this.isCompact = true});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 16.w : 16.0, 
          vertical: isCompact ? 16.h : 16.0
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
                color: Colors.white70,
                fontSize: isCompact ? 15.sp : 12.0,
              )
            ),
          ],
        ),
      ),
    );
  }
}
