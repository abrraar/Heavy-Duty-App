import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/widgets/exercise_picker_sheet.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';
import 'model/exercise.dart';

class CreateCycleScreen extends StatefulWidget {
  final TrainingCycle? existingCycle;
  const CreateCycleScreen({super.key, this.existingCycle});

  @override
  State<CreateCycleScreen> createState() => _CreateCycleScreenState();
}

class _CreateCycleScreenState extends State<CreateCycleScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<Map<String, dynamic>> _workouts = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingCycle != null) {
      _nameController.text = widget.existingCycle!.name;
      _descriptionController.text = widget.existingCycle!.description;
      for (var w in widget.existingCycle!.workouts) {
        _workouts.add({
          "id": w.id,
          "name": w.name,
          "exercises": w.exercises.map((e) => e.name).toList(),
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _addWorkout() {
    TextEditingController titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28.r),
        ),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "WORKOUT NAME",
              style: AppTextStyles.h3.copyWith(
                fontSize: 16.sp,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              textAlign: TextAlign.center,
              style: AppTextStyles.h3.copyWith(color: AppColors.white, fontSize: 16.sp),
              decoration: InputDecoration(
                hintText: "e.g. CHEST & BACK",
                hintStyle: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.crimson, width: 2),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.crimson, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.white.withOpacity(0.1)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "CANCEL",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (titleController.text.isNotEmpty) {
                        setState(() {
                          _workouts.add({
                            "name": titleController.text.toUpperCase(),
                            "exercises": <String>[],
                          });
                        });
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(
                        color: AppColors.crimson.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "ADD",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.crimson,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addExerciseToWorkout(Map<String, dynamic> workout) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExercisePickerSheet(
        onSelected: (name) {
          setState(() {
            workout['exercises'].add(name);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: AppColors.white,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'CREATE CUSTOM CYCLE',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h2.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const Opacity(
                    opacity: 0,
                    child: IconButton(
                      icon: Icon(Icons.info_outline_rounded),
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader("CYCLE IDENTITY"),
                  SizedBox(height: 16.h),
                  _buildTextField("CYCLE NAME", _nameController),
                  SizedBox(height: 16.h),
                  _buildTextField(
                    "DESCRIPTION (OPTIONAL)", 
                    _descriptionController, 
                    maxLines: 2,
                    hint: "e.g. FOCUS ON PROGRESSIVE OVERLOAD AND RECOVERY",
                  ),
                  SizedBox(height: 32.h),
                  _buildSectionHeader("WORKOUT ARCHITECTURE"),
                  SizedBox(height: 16.h),
                  ..._workouts.map((w) => _buildWorkoutFormCard(w)),
                  _buildAddWorkoutButton(),
                  SizedBox(height: 40.h),
                  _buildSaveButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutFormCard(Map<String, dynamic> workout) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(workout['name'], style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => setState(() => _workouts.remove(workout)), icon: const Icon(Icons.delete_outline, color: AppColors.crimson, size: 20)),
            ],
          ),
          ...List.generate(workout['exercises'].length, (i) => Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: Row(
              children: [
                const Icon(Icons.circle, size: 6, color: AppColors.crimson),
                SizedBox(width: 12.w),
                Expanded(child: Text(workout['exercises'][i], style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary))),
                IconButton(
                  onPressed: () => setState(() => workout['exercises'].removeAt(i)),
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.textSecondary, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          )),
          SizedBox(height: 12.h),
          GestureDetector(
            onTap: () => _addExerciseToWorkout(workout),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.crimson.withOpacity(0.3), style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: AppColors.crimson, size: 14),
                    SizedBox(width: 8.w),
                    Text("ADD EXERCISE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: 9.sp)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddWorkoutButton() {
    return GestureDetector(
      onTap: _addWorkout,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.white.withOpacity(0.1), style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: const Center(child: Icon(Icons.add, color: AppColors.textSecondary)),
      ),
    );
  }

  bool get _isCycleValid {
    if (_nameController.text.trim().isEmpty) return false;
    if (_workouts.isEmpty) return false;
    // Check if every workout has at least one exercise
    return _workouts.every((w) => (w['exercises'] as List).isNotEmpty);
  }

  String get _validationText {
    if (_nameController.text.trim().isEmpty) return "ENTER CYCLE NAME";
    if (_workouts.isEmpty) return "ADD A WORKOUT";
    bool allWorkoutsHaveExercises = _workouts.every((w) => (w['exercises'] as List).isNotEmpty);
    if (!allWorkoutsHaveExercises) return "ADD EXERCISES TO WORKOUTS";
    return "";
  }

  Widget _buildSaveButton() {
    final bool isValid = _isCycleValid;
    final String valText = _validationText;

    return Column(
      children: [
        GestureDetector(
          onTap: isValid ? () => _handleSave(shouldInitialize: false) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isValid ? AppColors.white.withOpacity(0.1) : AppColors.white.withOpacity(0.03),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              isValid ? "SAVE TO LIBRARY" : valText,
              style: AppTextStyles.buttonPrimary.copyWith(
                color: isValid ? AppColors.white : AppColors.textSecondary.withOpacity(0.3),
                fontSize: 12.sp,
              ),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        GestureDetector(
          onTap: isValid ? () => _handleSave(shouldInitialize: true) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 54.h,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isValid ? AppColors.crimson : AppColors.surfaceLight.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: isValid ? [
                BoxShadow(
                  color: AppColors.crimson.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ] : [],
            ),
            alignment: Alignment.center,
            child: Text(
              isValid ? "SAVE AND INITIALIZE" : valText,
              style: AppTextStyles.buttonPrimary.copyWith(
                color: isValid ? Colors.white : AppColors.textSecondary.withOpacity(0.3),
                fontSize: 12.sp,
                fontWeight: isValid ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleSave({required bool shouldInitialize}) async {
    if (_nameController.text.isEmpty || _workouts.isEmpty) {
      EliteSnackbar.show(context, "Please provide a name and at least one workout.", isError: true);
      return;
    }

    final provider = context.read<CycleProvider>();

    final active = provider.activeCycle;

    // If initializing, check if we need to replace an existing cycle
    if (shouldInitialize && active != null) {
      if (widget.existingCycle != null && active.id == widget.existingCycle!.id) {
        // We are editing the active cycle and want to re-initialize? 
        // Actually, normally editing a template shouldn't affect the active cycle unless explicitly activated.
      } else if (!active.isReadyToFinish) {
        // Warning for incomplete cycle
        final confirm = await EliteConfirmDialog.show(
          context,
          title: "INCOMPLETE CYCLE",
          message: "YOUR CURRENT CYCLE '${active.name.toUpperCase()}' IS NOT YET COMPLETE. ACTIVATING THIS NEW ONE WILL MOVE THE INCOMPLETE PROTOCOL TO YOUR HISTORY. PROCEED?",
          confirmText: "PROCEED",
        );
        if (confirm != true) return;
      } else {
        // Confirmation for finished cycle
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
            title: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.bolt_rounded, color: Colors.greenAccent, size: 28),
                ),
                SizedBox(height: 16.h),
                Text("ACTIVATE PROTOCOL", style: AppTextStyles.h3.copyWith(fontSize: 16.sp, letterSpacing: 1.2), textAlign: TextAlign.center),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "DO YOU WANT TO INITIALIZE THIS NEW TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withOpacity(0.1))),
                          alignment: Alignment.center,
                          child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: Colors.greenAccent.withOpacity(0.5))),
                          alignment: Alignment.center,
                          child: Text("ACTIVATE", style: AppTextStyles.labelSmall.copyWith(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        if (confirm != true) return;
      }
    } else if (shouldInitialize) {
      // Confirmation for no active cycle
      final confirm = await EliteConfirmDialog.show(
        context,
        title: "ACTIVATE PROTOCOL",
        message: "DO YOU WANT TO INITIALIZE THIS NEW TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
        confirmText: "ACTIVATE",
        confirmColor: Colors.greenAccent,
        icon: Icons.bolt_rounded,
      );
      if (confirm != true) return;
    }

    final String templateId = widget.existingCycle?.id ?? const Uuid().v4();
    final template = TrainingCycle(
      id: templateId,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      status: widget.existingCycle?.status ?? CycleStatus.template,
      isDefault: widget.existingCycle?.isDefault ?? false,
      workouts: List.generate(_workouts.length, (i) {
        final wData = _workouts[i];
        final workoutId = wData['id'] ?? const Uuid().v4();
        return Workout(
          id: workoutId,
          cycleId: templateId,
          name: wData['name'],
          order: i,
          status: WorkoutStatus.pending,
          exercises: List.generate(wData['exercises'].length, (j) {
            return Exercise(
              workoutId: workoutId,
              name: wData['exercises'][j],
              order: j,
            );
          }),
        );
      }),
    );

    if (widget.existingCycle != null) {
      // Delete old cycle first or use an update method if available
      // addCycle actually uses insertCycle with replace if we have it
      // Actually addCycle in provider just does list.add and localRepo.insertCycle
      // I should probably delete the old one or make sure addCycle handles updates correctly.
      // In CycleProvider, addCycle adds to the list: _cycles.add(localCycle);
      // If we are editing, we should replace it.
      await provider.deleteCycle(widget.existingCycle!.id);
    }
    
    await provider.addCycle(template);

    if (shouldInitialize) {
      // Activate the newly saved template
      await provider.activateCycle(template.id);
    }

    if (mounted) {
      Navigator.pop(context, true);
      EliteSnackbar.show(
        context, 
        shouldInitialize
            ? "Cycle '${template.name}' Initialized & Saved!"
            : "Cycle '${template.name}' saved to Library"
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 2.5.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int? maxLines, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
        SizedBox(height: 8.h),
        TextField(
          controller: controller,
          maxLines: maxLines ?? 1,
          onChanged: (val) {
            if (maxLines == 2) {
              final lines = val.split('\n');
              if (lines.length > 2) {
                // Prevent adding more lines
                controller.text = lines.sublist(0, 2).join('\n');
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
                );
              }
            }
            setState(() {});
          },
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), fontSize: 10.sp),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
