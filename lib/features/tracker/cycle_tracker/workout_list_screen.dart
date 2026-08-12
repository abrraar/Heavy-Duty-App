import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/exercise_list_screen.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:share_plus/share_plus.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'model/training_cycle.dart';
import 'model/workout.dart';

class WorkoutListScreen extends StatefulWidget {
  final String cycleId;
  final String cycleName;

  const WorkoutListScreen({super.key, required this.cycleId, required this.cycleName});

  @override
  State<WorkoutListScreen> createState() => _WorkoutListScreenState();
}

class _WorkoutListScreenState extends State<WorkoutListScreen> {
  final TextEditingController _cycleNoteController = TextEditingController();
  final TextEditingController _templateNameController = TextEditingController();
  Timer? _debounce;
  bool _isInitialLoad = true;
  final Set<String> _expandedWorkoutIds = {};

  @override
  void initState() {
    super.initState();
    _cycleNoteController.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cycleNoteController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  void _showSaveTemplateDialog() {
    _templateNameController.text = widget.cycleName;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("SAVE AS TEMPLATE", style: AppTextStyles.h3),
        content: TextField(
          controller: _templateNameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter template name...",
            hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.crimson),
            onPressed: () async {
              if (_templateNameController.text.trim().isNotEmpty) {
                await context.read<CycleProvider>().saveCycleAsTemplate(widget.cycleId, _templateNameController.text.trim());
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("SAVE"),
          ),
        ],
      ),
    );
  }

  void _editCycleName(String currentName) {
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
            Text("RENAME CYCLE", style: AppTextStyles.h3.copyWith(fontSize: 16.sp, letterSpacing: 1.2), textAlign: TextAlign.center),
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
                hintText: "ENTER CYCLE NAME",
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
                        await context.read<CycleProvider>().updateCycleName(widget.cycleId, titleController.text);
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

  void _onNoteChanged() {
    if (_isInitialLoad) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), _autoSaveNote);
  }

  Future<void> _autoSaveNote() async {
    final provider = context.read<CycleProvider>();
    await provider.updateCycleNote(widget.cycleId, _cycleNoteController.text.trim());
    debugPrint("Auto-saved Cycle Note");
  }

  void _onReorder(int oldIndex, int newIndex, List<Workout> pendingWorkouts, List<Workout> allWorkouts) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = pendingWorkouts.removeAt(oldIndex);
      pendingWorkouts.insert(newIndex, item);
      
      // Update full list
      final completedItems = allWorkouts.where((w) => w.status == WorkoutStatus.completed).toList();
      final updatedList = [...completedItems, ...pendingWorkouts];
      context.read<CycleProvider>().updateWorkoutOrder(widget.cycleId, updatedList);
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
              "WORKOUT CONTROLS",
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
              Icons.history_rounded,
              "Completed workouts are frozen at the top.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.drag_handle,
              "Hold and drag 'Pending' cards to reorder.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.swipe_down_rounded,
              "Pull down to sync the latest cloud data.",
            ),
            SizedBox(height: 16.h),
            _instructionRow(
              Icons.swipe_left_alt_rounded,
              "Swipe left on any workout to delete it.",
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

  void _addNewWorkout() {
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
              "NEW WORKOUT",
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
              style: AppTextStyles.h3.copyWith(color: AppColors.white, fontSize: 16.sp),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "ENTER WORKOUT TITLE",
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
                    onTap: () async {
                      if (titleController.text.isNotEmpty) {
                        final provider = context.read<CycleProvider>();
                        final allWorkouts = provider.workouts.where((w) => w.cycleId == widget.cycleId).toList();
                        
                        final newWorkout = Workout(
                          cycleId: widget.cycleId,
                          name: titleController.text.toUpperCase(),
                          order: allWorkouts.length,
                        );

                        await provider.addWorkout(newWorkout);
                        if (mounted) Navigator.pop(context);
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
                        "CREATE",
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

  void _editWorkoutName(Workout workout) {
    TextEditingController titleController = TextEditingController(text: workout.name);
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
                Icons.edit_rounded,
                color: AppColors.crimson,
                size: 28.r,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "RENAME WORKOUT",
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
              style: AppTextStyles.h3.copyWith(color: AppColors.white, fontSize: 16.sp),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "ENTER NEW TITLE",
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
                    onTap: () async {
                      if (titleController.text.isNotEmpty) {
                        await context.read<CycleProvider>().updateWorkoutName(workout.id, titleController.text);
                        if (mounted) Navigator.pop(context);
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
                        "SAVE",
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

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final allWorkoutsFlat = provider.workouts.where((w) => w.cycleId == widget.cycleId).toList();
        final completedWorkouts = allWorkoutsFlat.where((w) => w.status == WorkoutStatus.completed).toList();
        final pendingWorkouts = allWorkoutsFlat.where((w) => w.status == WorkoutStatus.pending).toList();

        // 1. Get exact cycle and its status
        CycleStatus currentCycleStatus = CycleStatus.template;
        List<Workout> nestedWorkouts = [];
        String currentCycleName = widget.cycleName;
        try {
          final cycle = provider.cycles.firstWhere((c) => c.id == widget.cycleId);
          currentCycleStatus = cycle.status;
          nestedWorkouts = cycle.workouts;
          currentCycleName = cycle.name;
          
          if (_isInitialLoad) {
            _cycleNoteController.text = cycle.note ?? "";
            _isInitialLoad = false;
          }
        } catch (_) {}

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          floatingActionButton: currentCycleStatus != CycleStatus.template
            ? FloatingActionButton.extended(
                onPressed: _addNewWorkout,
                backgroundColor: AppColors.crimson,
                icon: const Icon(Icons.add, color: AppColors.white),
                label: Text(
                  "WORKOUT",
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
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
                          currentCycleName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 3,
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

                      if (allWorkoutsFlat.isEmpty)
                        _buildEmptyState()
                      else ...[
                        // Completed
                        ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: completedWorkouts.length,
                          itemBuilder: (context, index) => _buildDismissibleWorkoutCard(index, completedWorkouts[index], provider),
                        ),

                        // Pending
                        ReorderableListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 24.w),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: pendingWorkouts.length,
                          onReorder: (oldIdx, newIdx) => _onReorder(oldIdx, newIdx, pendingWorkouts, allWorkoutsFlat),
                          proxyDecorator: (child, index, animation) => Material(color: Colors.transparent, child: child),
                          itemBuilder: (context, index) => ReorderableDelayedDragStartListener(
                            key: Key(pendingWorkouts[index].id),
                            index: index,
                            child: _buildDismissibleWorkoutCard(completedWorkouts.length + index, pendingWorkouts[index], provider),
                          ),
                        ),
                      ],

                      _buildBottomCommentSection(),
                      SizedBox(height: 32.h),
                      _buildTemplateAction(provider),
                      _buildShareAction(provider),
                      if (currentCycleStatus == CycleStatus.active)
                        Padding(
                          padding: EdgeInsets.only(top: 16.h),
                          child: _buildFinishCycleButton(nestedWorkouts, provider),
                        ),
                      SizedBox(height: 100.h),
                    ],
                  ),
                ),
              ),
              )],
          ),
        );
      },
    );
  }

  Widget _buildTemplateAction(CycleProvider provider) {
    final matchingTemplate = provider.findMatchingTemplate(widget.cycleId);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: matchingTemplate != null
          ? Container(
              height: 56.h,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.white.withOpacity(0.03)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_as_rounded, color: AppColors.textSecondary.withOpacity(0.2), size: 18.r),
                  SizedBox(width: 12.w),
                  Text(
                    "MATCHES TEMPLATE: $matchingTemplate",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withOpacity(0.3),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onTap: _showSaveTemplateDialog,
              child: Container(
                height: 56.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.crimson.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_as_rounded, color: AppColors.crimson, size: 20.r),
                    SizedBox(width: 12.w),
                    Text(
                      "SAVE AS TEMPLATE",
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.crimson,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildShareAction(CycleProvider provider) {
    final bool isDefault = provider.isUnmodifiedDefault(widget.cycleId);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 8.h),
      child: isDefault
          ? Container(
              height: 56.h,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.white.withOpacity(0.03)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.ios_share_rounded, color: AppColors.textSecondary.withOpacity(0.1), size: 18.r),
                  SizedBox(width: 12.w),
                  Text(
                    "SYSTEM DEFAULT – SHARING DISABLED",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary.withOpacity(0.3),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            )
          : GestureDetector(
              onTap: () async {
                final authProvider = context.read<AuthProvider>();
                final userName = authProvider.displayName;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("GENERATING SHAREABLE LINK..."), duration: Duration(seconds: 1)),
                );

                final link = await provider.generateShareableLink(widget.cycleId, userName);
                
                if (link != null) {
                  await Share.share(
                    "CHECK OUT THIS HIT TRAINING CYCLE SHARED BY $userName IN HEAVY DUTY:\n\n$link",
                    subject: "TRAINING CYCLE SHARED BY $userName",
                  );
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("FAILED TO GENERATE LINK. PLEASE TRY AGAIN.")),
                    );
                  }
                }
              },
              child: Container(
                height: 56.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.ios_share_rounded, color: Colors.blueAccent, size: 20.r),
                    SizedBox(width: 12.w),
                    Text(
                      "SHARE CYCLE",
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFinishCycleButton(List<Workout> allWorkouts, CycleProvider provider) {
    if (allWorkouts.isEmpty) return const SizedBox.shrink();
    
    final bool allComplete = allWorkouts.isNotEmpty && allWorkouts.every((w) => w.status == WorkoutStatus.completed);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: GestureDetector(
        onTap: allComplete ? () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
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
                      color: Colors.greenAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: Colors.greenAccent,
                      size: 28.r,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    "FINISH TRAINING CYCLE?",
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
                  Text(
                    "CONGRATULATIONS. ALL SESSIONS COMPLETED. WOULD YOU LIKE TO ARCHIVE THIS CYCLE TO HISTORY?",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.4,
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
                          onTap: () => Navigator.pop(ctx, false),
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
                          onTap: () => Navigator.pop(ctx, true),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "FINISH",
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.greenAccent,
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
          
          if (confirm == true) {
            await provider.finishCycle(widget.cycleId);
            if (mounted) Navigator.pop(context);
          }
        } : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 56.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: allComplete ? Colors.greenAccent.withOpacity(0.1) : AppColors.surfaceLight.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: allComplete ? Colors.greenAccent : AppColors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                color: allComplete ? Colors.greenAccent : AppColors.textSecondary.withOpacity(0.1), 
                size: 20.r
              ),
              SizedBox(width: 12.w),
              Text(
                allComplete ? "FINISH CYCLE" : "WORKOUTS REMAINING",
                style: AppTextStyles.labelMedium.copyWith(
                  color: allComplete ? Colors.greenAccent : AppColors.textSecondary.withOpacity(0.4),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
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
              Icons.layers_clear_rounded,
              color: AppColors.crimson.withOpacity(0.6),
              size: 40.r,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "SYSTEM IDLE",
            style: AppTextStyles.h3.copyWith(
              color: AppColors.white,
              letterSpacing: 4,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            "NO WORKOUT ARCHITECTURE DETECTED IN THIS CYCLE.",
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
            "INITIALIZE YOUR ROUTINE BY ADDING A NEW WORKOUT SESSION USING THE ACTION BUTTON BELOW.",
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

  Widget _buildHeader(CycleProvider provider) {
    String currentCycleName = widget.cycleName;
    try {
      final cycle = provider.cycles.firstWhere((c) => c.id == widget.cycleId);
      currentCycleName = cycle.name;
    } catch (_) {}

    return Padding(
      padding: EdgeInsets.fromLTRB(24.r, 2.r, 24.r, 12.r),
      child: Row(
        children: [
          _buildSectionHeader("WORKOUT LIST"),
          const Spacer(),
          IconButton(
            onPressed: () => _editCycleName(currentCycleName),
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

  Widget _buildDismissibleWorkoutCard(int index, Workout workout, CycleProvider provider) {
    final bool isExpanded = _expandedWorkoutIds.contains(workout.id);
    final progression = provider.calculateWorkoutProgression(workout, targetCycleId: widget.cycleId);
    final strength = progression['strength']!;
    final volumeChange = progression['volume']!;
    
    final List<Map<String, dynamic>> exerciseVolumes = workout.exercises.map((e) {
      final logs = provider.logs.where((l) => l.exerciseId == e.id).toList();
      double vol = 0;
      for (var l in logs) {
        vol += l.weight * l.positiveReps;
      }
      return {'name': e.name, 'volume': vol};
    }).where((element) => (element['volume'] as double) > 0).toList();

    final double totalWorkoutVolume = exerciseVolumes.fold(0, (sum, item) => sum + (item['volume'] as double));
    final bool hasPerformanceData = strength != 0 || volumeChange != 0 || totalWorkoutVolume > 0;

    return Dismissible(
      key: Key("${workout.id}_dismiss"),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog(
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
                    Icons.warning_amber_rounded,
                    color: AppColors.crimson,
                    size: 28.r,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  "CONFIRM DELETION",
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
                Text(
                  "ARE YOU SURE YOU WANT TO DELETE '${workout.name}'?",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
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
                        onTap: () => Navigator.pop(context, false),
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
                        onTap: () => Navigator.pop(context, true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          decoration: BoxDecoration(
                            color: AppColors.crimson.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: AppColors.crimson.withOpacity(0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            "DELETE",
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
      },
      onDismissed: (direction) {
        provider.deleteWorkout(workout.id);
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
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExerciseListScreen(workoutId: workout.id, workoutName: workout.name),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Index, Title, Subtitle, Badge
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
                                      workout.name,
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
                              SizedBox(height: 8.h),
                              Text(
                                workout.completedAt != null 
                                    ? DateFormat('MMM dd, yyyy').format(workout.completedAt!).toUpperCase() 
                                    : "PENDING",
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textSecondary.withOpacity(0.4),
                                  fontSize: 11.sp,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (workout.status == WorkoutStatus.completed)
                                _buildStatusBadge(),
                            ],
                          ),
                        ),
                        // Right Column: Strength Data
                        if (strength != 0) ...[
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
            if (hasPerformanceData) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Divider(color: AppColors.white.withOpacity(0.05), height: 1),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  if (isExpanded) _expandedWorkoutIds.remove(workout.id);
                  else _expandedWorkoutIds.add(workout.id);
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (volumeChange != 0) ...[
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
                                  "${volumeChange > 0 ? '+' : ''}${(volumeChange * 100).toStringAsFixed(1)}%",
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: volumeChange > 0 ? AppColors.success : AppColors.crimson,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18.sp,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                Divider(color: AppColors.white.withOpacity(0.05)),
                                SizedBox(height: 16.h),
                              ],
                              
                              if (exerciseVolumes.isNotEmpty) ...[
                                Text(
                                  "EXERCISE BREAKDOWN",
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: AppColors.white.withOpacity(0.5),
                                    fontSize: 8.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                ...exerciseVolumes.map((ev) => Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          ev['name'].toString().toUpperCase(),
                                          style: AppTextStyles.labelSmall.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 10.sp,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        ev['volume'].toStringAsFixed(1),
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                                SizedBox(height: 12.h),
                                Divider(color: AppColors.white.withOpacity(0.1)),
                                SizedBox(height: 12.h),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "TOTAL WORKOUT VOLUME",
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: AppColors.white,
                                        fontSize: 9.sp,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    Text(
                                      totalWorkoutVolume.toStringAsFixed(1),
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: AppColors.crimson,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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

  Widget _buildStatusBadge() {
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

  Widget _buildBottomCommentSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: AppColors.white.withOpacity(0.1), height: 32.h),
          _buildSectionHeader("CYCLE OBSERVATIONS"),
          SizedBox(height: 12.h),
          TextField(
            controller: _cycleNoteController,
            maxLines: 3,
            style: const TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: "NOTES ON SYSTEMIC FATIGUE...",
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
}
