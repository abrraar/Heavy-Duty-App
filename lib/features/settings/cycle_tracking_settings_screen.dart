import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';

class CycleTrackingSettingsScreen extends StatefulWidget {
  const CycleTrackingSettingsScreen({super.key});

  @override
  State<CycleTrackingSettingsScreen> createState() => _CycleTrackingSettingsScreenState();
}

class _CycleTrackingSettingsScreenState extends State<CycleTrackingSettingsScreen> {
  // Notification States
  bool _workoutReminders = true;
  int _workoutDaysInterval = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'HIT TRACKER SETTINGS',
          style: AppTextStyles.labelMedium.copyWith(letterSpacing: 2),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('WORKOUT REMINDERS'),
              SizedBox(height: 12.h),
              
              _buildNotificationCard(
                title: "Workout Schedule",
                subtitle: "Remind me to train every",
                value: _workoutReminders,
                onChanged: (val) => setState(() => _workoutReminders = val),
                child: _buildSmallDropdown(
                  value: _workoutDaysInterval,
                  items: [2, 3, 4, 5, 7, 10, 14],
                  suffix: "Days",
                  onChanged: (val) => setState(() => _workoutDaysInterval = val!),
                ),
              ),

              SizedBox(height: 32.h),

              _buildSectionHeader('CYCLE EVOLUTION'),
              SizedBox(height: 12.h),
              
              _buildProgressionCard(),

              SizedBox(height: 32.h),

              _buildSectionHeader('DISPLAY UNITS'),
              SizedBox(height: 12.h),

              _buildUnitToggleCard(context),

              // ── NAVIGATION & SPACING FIX ──
              SizedBox(height: MediaQuery.of(context).padding.bottom + 100.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnitToggleCard(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Weight Unit", style: AppTextStyles.labelMedium),
                  SizedBox(height: 4.h),
                  Text(
                    "Switch between LBS and KGS",
                    style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    _buildUnitButton(
                      label: "LBS",
                      isSelected: provider.settings.weightUnit == WeightUnit.lbs,
                      onTap: () => provider.updateSettings(provider.settings.copyWith(weightUnit: WeightUnit.lbs)),
                    ),
                    _buildUnitButton(
                      label: "KGS",
                      isSelected: provider.settings.weightUnit == WeightUnit.kgs,
                      onTap: () => provider.updateSettings(provider.settings.copyWith(weightUnit: WeightUnit.kgs)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnitButton({required String label, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson : Colors.transparent,
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isSelected ? AppColors.white : AppColors.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.w,
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
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard({
    required String title, 
    required String subtitle, 
    required bool value, 
    required Function(bool) onChanged,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              Switch.adaptive(
                value: value, 
                onChanged: onChanged,
                activeColor: AppColors.crimson,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              child,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown({required int value, required List<int> items, required String suffix, required Function(int?) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          dropdownColor: AppColors.surfaceLight,
          icon: Icon(Icons.keyboard_arrow_down, color: AppColors.crimson, size: 16.r),
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
          items: items.map((int val) => DropdownMenuItem(value: val, child: Text("$val $suffix"))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildProgressionCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.crimson.withValues(alpha: 0.1), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded, color: AppColors.crimson, size: 24.r),
              SizedBox(width: 10.w),
              Text('NEXT PHASE PROTOCOL', style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson)),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            "Upon completion of your current cycle, the system will automatically archive your intensity data and generate a new Evolution List.",
            style: AppTextStyles.bodySmall.copyWith(height: 1.5, color: AppColors.textSecondary),
          ),
          SizedBox(height: 20.h),
          
          // ── UPDATED STATUS / ACTION BUTTON ──
          GestureDetector(
            onTap: () {
              // Action for new archive
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Status: Ready for next archive",
                    style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.white),
                  ),
                  Row(
                    children: [
                      Text(
                        "NEW ARCHIVE",
                        style: AppTextStyles.labelSmall.copyWith(
                          fontSize: 10.sp, 
                          color: AppColors.crimson,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Icon(Icons.arrow_forward_ios_rounded, color: AppColors.crimson, size: 12.r),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}