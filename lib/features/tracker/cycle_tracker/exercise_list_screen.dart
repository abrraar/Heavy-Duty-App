import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/cycle_exercise_detail_screen.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'dart:async';
import 'package:heavy_duty/features/tracker/cycle_tracker/widgets/exercise_picker_sheet.dart';
import 'package:provider/provider.dart';
import 'model/exercise.dart';

class ExerciseListScreen extends StatefulWidget {
  final String workoutId;
  final String workoutName;

  const ExerciseListScreen({super.key, required this.workoutId, required this.workoutName});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  final TextEditingController _workoutNoteController = TextEditingController();
  Timer? _debounce;
  bool _isInitialLoad = true;
  final Set<String> _expandedExerciseIds = {}; // Track expanded exercise cards

  @override
  void initState() {
    super.initState();
    _workoutNoteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _workoutNoteController.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    if (_isInitialLoad) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), _autoSaveNote);
  }

  Future<void> _autoSaveNote() async {
    final provider = context.read<CycleProvider>();
    await provider.updateWorkoutNote(widget.workoutId, _workoutNoteController.text.trim());
    debugPrint("Auto-saved Workout Note");
  }

  void _onReorder(int oldIndex, int newIndex, List<Exercise> exercises) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = exercises.removeAt(oldIndex);
      exercises.insert(newIndex, item);
      context.read<CycleProvider>().updateExerciseOrder(widget.workoutId, exercises);
    });
  }

  void _showInstructions() {
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
                Icons.info_outline_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "EXERCISE CONTROLS",
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
            _instructionRow(
              Icons.drag_handle,
              "Hold and drag cards to reorder your workout sequence.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.swipe_down_rounded,
              "Pull down to sync the latest cloud data.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.swipe_left_alt_rounded,
              "Swipe left on any exercise to remove it.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.bolt_rounded,
              "Progression is tracked globally across all cycles.",
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
                        color: AppColors.crimson.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "DISMISS",
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

  Widget _instructionRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.crimson, size: 20.r),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _addNewExercise() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ExercisePickerSheet(
        onSelected: (name) async {
          final provider = context.read<CycleProvider>();
          final currentExercises = provider.exercises.where((e) => e.workoutId == widget.workoutId).toList();
          
          final newExercise = Exercise(
            workoutId: widget.workoutId,
            name: name,
            order: currentExercises.length,
          );
          
          await provider.addExercise(newExercise);
        },
      ),
    );
  }

  void _renameExercise(Exercise exercise) {
    TextEditingController titleController = TextEditingController(text: exercise.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.edit_rounded, color: AppColors.crimson, size: 28.r),
            ),
            SizedBox(height: 16.h),
            Text("RENAME EXERCISE", style: AppTextStyles.h3.copyWith(fontSize: 16.sp, letterSpacing: 1.2), textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: AppTextStyles.h3.copyWith(color: AppColors.white, fontSize: 16.sp),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "ENTER NEW TITLE",
                hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson, width: 2)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson, width: 2)),
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
                      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withOpacity(0.1))),
                      alignment: Alignment.center,
                      child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (titleController.text.isNotEmpty) {
                        await context.read<CycleProvider>().renameExerciseGlobally(exercise.name, titleController.text);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.crimson.withOpacity(0.5))),
                      alignment: Alignment.center,
                      child: Text("SAVE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold)),
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

  void _editWorkoutHeaderName(String currentName) {
    TextEditingController titleController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        title: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.edit_rounded, color: AppColors.crimson, size: 28.r),
            ),
            SizedBox(height: 16.h),
            Text("RENAME WORKOUT", style: AppTextStyles.h3.copyWith(fontSize: 16.sp, letterSpacing: 1.2), textAlign: TextAlign.center),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: AppTextStyles.h3.copyWith(color: AppColors.white, fontSize: 16.sp),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "ENTER WORKOUT NAME",
                hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson, width: 2)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson, width: 2)),
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
                      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withOpacity(0.1))),
                      alignment: Alignment.center,
                      child: Text("CANCEL", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      if (titleController.text.isNotEmpty) {
                        await context.read<CycleProvider>().updateWorkoutName(widget.workoutId, titleController.text);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.crimson.withOpacity(0.5))),
                      alignment: Alignment.center,
                      child: Text("SAVE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final exercises = provider.exercises.where((e) => e.workoutId == widget.workoutId).toList();
        String currentWorkoutName = widget.workoutName;
        try {
          final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
          currentWorkoutName = workout.name;
          if (_isInitialLoad) {
            _workoutNoteController.text = workout.note ?? "";
            _isInitialLoad = false;
          }
        } catch (_) {}

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _addNewExercise,
            backgroundColor: AppColors.crimson,
            icon: const Icon(Icons.add, color: AppColors.white),
            label: Text(
              "EXERCISE",
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h, horizontal: 8.w),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          currentWorkoutName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      const Opacity(
                        opacity: 0,
                        child: IconButton(icon: Icon(Icons.arrow_back_ios_new_rounded), onPressed: null),
                      ),
                    ],
                  ),
                ),
              ),

              // Content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.forceRefresh(),
                  color: AppColors.crimson,
                  backgroundColor: AppColors.surface,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(provider),

                        if (exercises.isEmpty)
                          _buildEmptyState()
                        else
                          ReorderableListView.builder(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: exercises.length,
                            onReorder: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx, exercises),
                            proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                            itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
                              key: Key(exercises[index].id),
                              index: index,
                              child: _buildDismissibleExerciseCard(index, exercises[index], provider),
                            ),
                          ),

                        _buildWorkoutCommentSection(),
                        SizedBox(height: 100.h),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
      padding: EdgeInsets.all(32.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: AppColors.crimson.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.reorder_rounded,
              color: AppColors.crimson.withOpacity(0.6),
              size: 40.r,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "NULL DATA",
            style: AppTextStyles.h3.copyWith(
              color: AppColors.white,
              letterSpacing: 4,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "THIS WORKOUT HAS NO DEFINED EXERCISE SEQUENCES.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
              height: 1.5,
            ),
          ),
          SizedBox(height: 16.h),
          Container(
            height: 1,
            width: 40.w,
            color: AppColors.crimson.withOpacity(0.3),
          ),
          SizedBox(height: 16.h),
          Text(
            "SELECT 'ADD EXERCISE' BELOW TO CONSTRUCT YOUR TARGETED HIT MOVEMENTS FOR THIS SESSION.",
            textAlign: TextAlign.center,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary.withOpacity(0.5),
              fontSize: 10.sp,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCommentSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.white.withOpacity(0.1), height: 32.h),
          _buildSectionHeader("WORKOUT OBSERVATIONS"),
          SizedBox(height: 12.h),
          TextField(
            controller: _workoutNoteController,
            minLines: 3,
            maxLines: null,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: "NOTES ON PERFORMANCE, RECOVERY, OR INTENSITY...",
              hintStyle: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide(color: AppColors.white.withOpacity(0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: const BorderSide(color: AppColors.crimson)),
            ),
          ),
          SizedBox(height: 8.h),
          Center(
            child: Text(
              "AUTOSAVES AS YOU TYPE",
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary.withOpacity(0.3),
                fontSize: 8.sp,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(CycleProvider provider) {
    String currentWorkoutName = widget.workoutName;
    try {
      final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
      currentWorkoutName = workout.name;
    } catch (_) {}

    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 2.r, 24.r, 12.r),
      child: Row(
        children: [
          _buildSectionHeader("EXERCISE SEQUENCE"),
          const Spacer(),
          IconButton(
            onPressed: () => _editWorkoutHeaderName(currentWorkoutName),
            icon: Icon(
              Icons.edit_rounded,
              color: AppColors.textSecondary,
              size: 22.r,
            ),
          ),
          IconButton(
            onPressed: _showInstructions,
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
              size: 24.r,
            ),
          ),
        ],
      ),
    );
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

  Widget _buildDismissibleExerciseCard(int index, Exercise exercise, CycleProvider provider) {
    final bool isExpanded = _expandedExerciseIds.contains(exercise.id);
    String? currentCycleId;
    try {
      final workout = provider.workouts.firstWhere((w) => w.id == widget.workoutId);
      currentCycleId = workout.cycleId;
    } catch (_) {}

    final progression = provider.calculateExerciseProgression(exercise.name, targetCycleId: currentCycleId);
    final strength = progression['strength']!;
    final volume = progression['volume']!;
    final bool hasProgression = strength != 0 || volume != 0;

    return Dismissible(
      key: Key("${exercise.id}_dismiss"),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await EliteConfirmDialog.show(
          context,
          title: "REMOVE EXERCISE",
          message: "ARE YOU SURE YOU WANT TO REMOVE '${exercise.name}' FROM THIS WORKOUT?",
          confirmText: "REMOVE",
        );
      },
      onDismissed: (direction) {
        provider.deleteExercise(exercise.id);
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24.w),
        margin: EdgeInsets.only(bottom: 20.h),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 28),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 20.h),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24.r),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CycleExerciseDetailScreen(
                          exerciseId: exercise.id,
                          exerciseName: exercise.name,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Index, Title, Muscles, Badge
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 24.r,
                                    height: 24.r,
                                    margin: EdgeInsets.only(right: 12.w),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.crimson, width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      "${index + 1}",
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10.sp,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      exercise.name.toUpperCase(),
                                      style: AppTextStyles.h3.copyWith(
                                        fontSize: 18.sp,
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (exercise.targetMuscles != null) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  exercise.targetMuscles!.toUpperCase(),
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.textSecondary.withOpacity(0.4),
                                    fontSize: 11.sp,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                              _buildExerciseStatusBadge(exercise, provider),
                            ],
                          ),
                        ),
                        // Right Column: Strength Data
                        if (hasProgression && strength != 0) ...[
                          SizedBox(width: 16.w),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "STRENGTH",
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary.withOpacity(0.4),
                                  fontSize: 7.sp,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                "${strength > 0 ? '+' : ''}${(strength * 100).toStringAsFixed(1)}%",
                                style: AppTextStyles.h2.copyWith(
                                  color: strength > 0 ? AppColors.success : Colors.redAccent,
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(width: 12.w),
                        Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary.withOpacity(0.3), size: 14.r),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Expansion Logic for Volume
            if (hasProgression && volume != 0) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Divider(color: AppColors.white.withOpacity(0.05), height: 1),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  if (isExpanded) _expandedExerciseIds.remove(exercise.id);
                  else _expandedExerciseIds.add(exercise.id);
                }),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  color: Colors.transparent,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isExpanded ? "COLLAPSE DATA" : "SHOW PERFORMANCE DATA",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.4),
                          fontSize: 9.sp,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary.withOpacity(0.4),
                          size: 16.r,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.topCenter,
                child: isExpanded
                    ? Container(
                        padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 24.h),
                        child: Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "VOLUME CHANGE",
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.white,
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    "${volume > 0 ? '+' : ''}${(volume * 100).toStringAsFixed(1)}%",
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: volume > 0 ? AppColors.success : AppColors.crimson,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity, height: 0),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseStatusBadge(Exercise exercise, CycleProvider provider) {
    final exLogs = provider.logs.where((l) => l.exerciseId == exercise.id).toList();
    exLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    bool isCompleted = false;
    if (exLogs.isNotEmpty) {
      final l = exLogs.first;
      final hasBaseLoad = l.weight > 0;
      final hasIntensifier = l.positiveReps > 0 || l.staticHoldSeconds > 0 || l.negativeReps > 0 || l.forcedReps > 0;
      if (hasBaseLoad && hasIntensifier) {
        isCompleted = true;
      }
    }

    if (!isCompleted) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: IntrinsicWidth(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4.r),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Text(
            "COMPLETED",
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.success,
              fontSize: 8.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}
