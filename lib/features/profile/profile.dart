// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../tracker/body_composition/model/body_comp_log.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _editField(BuildContext context, String title, String initialValue, Function(String) onSave) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("EDIT $title", style: AppTextStyles.h3),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "ENTER $title",
            hintStyle: AppTextStyles.labelSmall.copyWith(color: Colors.white38),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.crimson)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              onSave(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text("SAVE", style: TextStyle(color: AppColors.crimson)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<AuthProvider, BodyCompProvider, CycleProvider>(
      builder: (context, authProv, bodyProv, cycleProv, _) {
        final lastWeightLog = bodyProv.logs.where((l) => l.type == BodyMetricType.weight).firstOrNull;
        final lastFatLog = bodyProv.logs.where((l) => l.type == BodyMetricType.fat).firstOrNull;
        
        final height = authProv.height ?? 170.0;
        final weight = lastWeightLog?.value ?? 0.0;
        final bodyFat = lastFatLog?.value ?? 0.0;
        
        double bmi = 0;
        if (height > 0 && weight > 0) {
          bmi = weight / ((height / 100) * (height / 100));
        }

        // Calculate Records
        double heaviestWeight = 0;
        String heaviestExercise = "N/A";
        double bestGain = 0;
        String bestGainExercise = "N/A";

        for (var log in cycleProv.logs) {
          if (log.weight > heaviestWeight) {
            heaviestWeight = log.weight;
            heaviestExercise = cycleProv.getExerciseName(log.exerciseId) ?? "Unknown";
          }
        }

        for (var workout in cycleProv.workouts) {
          for (var exercise in workout.exercises) {
            final prog = cycleProv.calculateExerciseProgress(exercise.name);
            if (prog > bestGain) {
              bestGain = prog;
              bestGainExercise = exercise.name;
            }
          }
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
          child: Column(
            children: [
              // 1. Sleek Profile Info Card (Glassmorphism style)
              _buildGlassCard(
                title: 'PROFILE INFORMATION',
                icon: Icons.person_rounded,
                child: Column(
                  children: [
                    _buildInfoTile(
                      'Name', 
                      authProv.displayName,
                      onTap: () => _editField(context, "NAME", authProv.displayName, (val) => authProv.updateUserProfile(name: val)),
                    ),
                    _buildInfoTile(
                      'Username', 
                      authProv.username,
                      onTap: () => _editField(context, "USERNAME", authProv.username, (val) => authProv.updateUserProfile(username: val)),
                    ),
                    _buildInfoTile('Email', authProv.currentUser?.email ?? "N/A"),
                    _buildInfoTile(
                      'Height', 
                      "${height.toStringAsFixed(0)} cm",
                      onTap: () => _editField(context, "HEIGHT", height.toStringAsFixed(0), (val) {
                        final h = double.tryParse(val);
                        if (h != null) authProv.updateUserProfile(height: h);
                      }),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // 2. Body Metrics Grid (More visual than a list)
              _buildGlassCard(
                title: 'BODY COMPOSITION',
                icon: Icons.analytics_outlined,
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12.h,
                  crossAxisSpacing: 12.w,
                  childAspectRatio: 2.2,
                  children: [
                    _buildMetricBox('Height', height.toStringAsFixed(0), 'cm'),
                    _buildMetricBox('Weight', weight > 0 ? weight.toStringAsFixed(1) : '--', 'kg'),
                    _buildMetricBox('Body Fat', bodyFat > 0 ? bodyFat.toStringAsFixed(1) : '--', '%'),
                    _buildMetricBox('BMI', bmi > 0 ? bmi.toStringAsFixed(1) : '--', 'pts'),
                  ],
                ),
              ),
              SizedBox(height: 20.h),

              // 3. Strength Records (Premium Tier List)
              _buildGlassCard(
                title: 'ELITE RECORDS',
                icon: Icons.emoji_events_rounded,
                child: Column(
                  children: [
                    _buildRecordTile(
                      label: 'Heaviest Lift',
                      exercise: heaviestExercise.toUpperCase(),
                      value: '${heaviestWeight.toStringAsFixed(1)} KG',
                      isHot: heaviestWeight > 0,
                    ),
                    _buildRecordTile(
                      label: 'Best Strength Gain',
                      exercise: bestGainExercise.toUpperCase(),
                      value: '+${(bestGain * 100).toStringAsFixed(1)}%',
                      isHot: bestGain > 0,
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 30.h),
              
              // Sign Out Button
              GestureDetector(
                onTap: () {
                  context.push(AppRoutes.createProfilePersonal);
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.crimson.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      "VIEW CREATE PROFILE",
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.crimson,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 50.h),
            ],
          ),
        );
      },
    );
  }

  // --- UI Components ---

  Widget _buildGlassCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 10.h),
            child: Row(
              children: [
                Icon(icon, color: AppColors.crimson, size: 20.r),
                SizedBox(width: 10.w),
                Text(title, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.2)),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(16.r), child: child),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, {bool isLast = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.labelSmall.copyWith(color: Colors.white38)),
            Row(
              children: [
                Text(value, style: AppTextStyles.labelMedium.copyWith(color: Colors.white)),
                if (onTap != null) ...[
                  SizedBox(width: 8.w),
                  Icon(Icons.edit_rounded, color: Colors.white24, size: 14.r),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, String unit) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: Colors.white38)),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: value, style: AppTextStyles.h3.copyWith(fontSize: 18.sp)),
                TextSpan(text: ' $unit', style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile({required String label, required String exercise, required String value, bool isHot = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: isHot 
          ? LinearGradient(colors: [AppColors.crimson.withOpacity(0.2), Colors.transparent])
          : null,
        color: isHot ? null : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16.r),
        border: isHot ? Border.all(color: AppColors.crimson.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall.copyWith(color: isHot ? AppColors.crimson : Colors.white38)),
                Text(exercise, style: AppTextStyles.labelMedium),
              ],
            ),
          ),
          Text(value, style: AppTextStyles.h3.copyWith(color: isHot ? AppColors.crimson : Colors.white)),
        ],
      ),
    );
  }
}
