import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_confirm_dialog.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/create_cycle_screen.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'model/workout.dart';

class CycleDetailViewScreen extends StatelessWidget {
  final String cycleId;
  final String cycleName;
  final bool isModifiable;

  const CycleDetailViewScreen({
    super.key,
    required this.cycleId,
    required this.cycleName,
    required this.isModifiable,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        final cycle = provider.cycles.firstWhere((c) => c.id == cycleId);
        final cycleWorkouts = cycle.workouts;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: null,
          body: Column(
            children: [
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
                          cycleName.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.h2.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      if (isModifiable)
                        IconButton(
                          icon: const Icon(Icons.edit_note_rounded, color: AppColors.white),
                          onPressed: () async {
                            final cycle = provider.cycles.firstWhere((c) => c.id == cycleId);
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateCycleScreen(existingCycle: cycle),
                              ),
                            );
                            if (result == true && context.mounted) {
                              Navigator.pop(context, true);
                            }
                          },
                        )
                      else
                        const Opacity(
                          opacity: 0,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded),
                            onPressed: null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Scrollable content area
              Expanded(
                child: ListView(
                  padding: EdgeInsets.all(24.r),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildInfoTile("STRUCTURE", "${cycleWorkouts.length} SESSIONS"),
                    SizedBox(height: 24.h),
                    _buildSectionHeader("WORKOUT ARCHITECTURE"),
                    SizedBox(height: 16.h),
                    ...cycleWorkouts.map((workout) => _buildWorkoutSummaryCard(workout, provider)),
                  ],
                ),
              ),

              // Fixed Action Area at the bottom
              Padding(
                padding: EdgeInsets.all(24.r),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!cycle.isDefault) ...[
                      _buildShareButton(context, provider),
                      SizedBox(height: 16.h),
                    ],
                    _buildActivateButton(context, provider),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildShareButton(BuildContext context, CycleProvider provider) {
    return GestureDetector(
      onTap: () async {
        final authProvider = context.read<AuthProvider>();
        final userName = authProvider.displayName;
        
        EliteSnackbar.show(context, "GENERATING SHAREABLE LINK...");

        final link = await provider.generateShareableLink(cycleId, userName);
        
        if (link != null) {
          await Share.share(
            "CHECK OUT THIS HIT TRAINING CYCLE SHARED BY $userName IN HEAVY DUTY:\n\n$link",
            subject: "TRAINING CYCLE SHARED BY $userName",
          );
        } else {
          if (context.mounted) {
            EliteSnackbar.show(context, "FAILED TO GENERATE LINK. PLEASE TRY AGAIN.", isError: true);
          }
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18.h),
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
    );
  }

  Widget _buildActivateButton(BuildContext context, CycleProvider provider) {
    return GestureDetector(
      onTap: () async {
        final active = provider.activeCycle;
        bool activated = false;

        if (active != null) {
          if (!active.isReadyToFinish) {
            // Warning for incomplete cycle
            final confirm = await EliteConfirmDialog.show(
              context,
              title: "INCOMPLETE CYCLE",
              message: "YOUR CURRENT CYCLE '${active.name.toUpperCase()}' IS NOT YET COMPLETE. ACTIVATING '${cycleName.toUpperCase()}' WILL MOVE THE INCOMPLETE PROTOCOL TO YOUR HISTORY. PROCEED?",
              confirmText: "PROCEED",
            );
            activated = confirm ?? false;
          }
else {
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
                      "DO YOU WANT TO INITIALIZE THE '${cycleName.toUpperCase()}' TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
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
            activated = confirm ?? false;
          }
        } else {
          // Confirmation for no active cycle
          final confirm = await EliteConfirmDialog.show(
            context,
            title: "ACTIVATE PROTOCOL",
            message: "DO YOU WANT TO INITIALIZE THE '${cycleName.toUpperCase()}' TEMPLATE AS YOUR ACTIVE TRAINING CYCLE?",
            confirmText: "ACTIVATE",
            confirmColor: Colors.greenAccent,
            icon: Icons.bolt_rounded,
          );
          activated = confirm ?? false;
        }

        if (activated) {
          await provider.activateCycle(cycleId);
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 18.h),
        decoration: BoxDecoration(
          color: AppColors.crimson,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(color: AppColors.crimson.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
          ],
        ),
        child: Center(
          child: Text(
            "ACTIVATE THIS CYCLE",
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildWorkoutSummaryCard(Workout workout, CycleProvider provider) {
    final workoutExercises = workout.exercises;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(workout.name, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 12.h),
          const Divider(color: Colors.white10),
          SizedBox(height: 8.h),
          ...workoutExercises.map((exercise) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 6.r, color: AppColors.crimson),
                  SizedBox(width: 12.w),
                  Text(
                    exercise.name,
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
