import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/exercise/model/exercise_template.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:provider/provider.dart';

class AddCustomExerciseSheet extends StatefulWidget {
  const AddCustomExerciseSheet({super.key});

  @override
  State<AddCustomExerciseSheet> createState() => _AddCustomExerciseSheetState();
}

class _AddCustomExerciseSheetState extends State<AddCustomExerciseSheet> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  final List<String> _muscles = [
    'Chest', 'Back', 'Legs', 'Calf', 'Abdominals', 'Shoulder', 'Biceps', 'Triceps'
  ];
  final Set<String> _selectedMuscles = {};

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  void _toggleMuscle(String muscle) {
    setState(() {
      if (_selectedMuscles.contains(muscle)) {
        _selectedMuscles.remove(muscle);
      } else {
        _selectedMuscles.add(muscle);
      }
    });
  }

  // --- AUTOMATED LOGIC ---
  
  ExerciseType get _calculatedType => 
      _selectedMuscles.length > 1 ? ExerciseType.compound : ExerciseType.isolation;

  int get _calculatedIntensity {
    if (_selectedMuscles.isEmpty) return 1;
    if (_selectedMuscles.length == 1) return 2;
    if (_selectedMuscles.length == 2) return 3;
    if (_selectedMuscles.length <= 4) return 4;
    return 5;
  }

  String get _buttonText {
    if (_nameController.text.isEmpty) return "ENTER EXERCISE NAME";
    if (_selectedMuscles.isEmpty) return "SELECT TARGET MUSCLES";
    return "SAVE EXERCISE";
  }

  bool get _isReady => _nameController.text.isNotEmpty && _selectedMuscles.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 12.h, bottom: 8.h),
            child: _buildHandle(),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24.r, 0, 24.r, 24.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("NEW EXERCISE", style: AppTextStyles.h3),
                      // Cancel button removed as requested
                    ],
                  ),
                  SizedBox(height: 24.h),
                  _buildTextField("EXERCISE NAME", _nameController, "e.g. Hammer Curls"),
                  SizedBox(height: 24.h),
                  _buildTextField("ABOUT THE MOVEMENT (OPTIONAL)", _aboutController, "Describe the proper form...", maxLines: 3),
                  SizedBox(height: 24.h),
                  Text("TARGET MUSCLES", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                  SizedBox(height: 12.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: _muscles.map((m) {
                      bool isSelected = _selectedMuscles.contains(m);
                      return GestureDetector(
                        onTap: () => _toggleMuscle(m),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.05)),
                          ),
                          child: Text(m.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 9.sp)),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  SizedBox(height: 24.h),
                  _buildAutoMetricsDisplay(),
                  
                  SizedBox(height: 32.h),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoMetricsDisplay() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TYPE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: _calculatedType == ExerciseType.compound ? AppColors.crimson.withOpacity(0.1) : AppColors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(
                  _calculatedType.name.toUpperCase(),
                  style: AppTextStyles.labelSmall.copyWith(
                    color: _calculatedType == ExerciseType.compound ? AppColors.crimson : AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("DEMAND", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
              _buildFireRating(_calculatedIntensity),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFireRating(int score) {
    return Row(
      children: List.generate(5, (index) => Icon(
        Icons.local_fire_department_rounded,
        size: 16.r,
        color: index < score ? AppColors.crimson : AppColors.white.withOpacity(0.05),
      )),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.2), fontSize: 12.sp),
            filled: true,
            fillColor: AppColors.background.withValues(alpha: 0.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isReady ? _saveExercise : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54.h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isReady ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: _isReady ? [
            BoxShadow(color: AppColors.crimson.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          _buttonText,
          style: AppTextStyles.labelMedium.copyWith(
            color: _isReady ? Colors.white : AppColors.textSecondary.withOpacity(0.5),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.2), borderRadius: BorderRadius.circular(2.r)),
      ),
    );
  }

  void _saveExercise() async {
    final template = ExerciseTemplate(
      name: _nameController.text.trim(),
      targetMuscles: _selectedMuscles.join(', '),
      type: _calculatedType,
      intensity: _calculatedIntensity,
      isDefault: false,
      aboutTheMovement: _aboutController.text.trim().isEmpty ? null : _aboutController.text.trim(),
    );

    final provider = context.read<ExerciseProvider>();
    Navigator.pop(context);
    await provider.addTemplate(template);
  }
}
