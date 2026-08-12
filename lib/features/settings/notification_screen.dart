import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  // Tracker Notifications
  bool _workoutReminders = true;
  int _workoutDaysInterval = 2;

  bool _waterIntake = true;
  int _waterMinutesInterval = 60;

  bool _weightMeasurement = true;
  int _weightDaysInterval = 7;

  bool _sleepReminders = false;
  int _sleepHoursPrior = 1;

  // System
  bool _appUpdates = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null, // Heavy Duty Header Protocol
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
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
                        "NOTIFICATIONS",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Opacity(
                      opacity: 0,
                      child: IconButton(icon: Icon(Icons.close), onPressed: null),
                    ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    
                    _buildSectionHeader("TRACKER NOTIFICATIONS"),
                    
                    // Workout Reminders
                    _buildToggleWithDropdown(
                      title: "WORKOUT REMINDERS",
                      subtitle: "REMIND ME EVERY $_workoutDaysInterval DAYS",
                      value: _workoutReminders,
                      onToggle: (val) => setState(() => _workoutReminders = val),
                      dropdown: _buildSmallDropdown(
                        value: _workoutDaysInterval,
                        items: [1, 2, 3, 4, 5, 7],
                        suffix: "DAYS",
                        onChanged: (val) => setState(() => _workoutDaysInterval = val!),
                      ),
                    ),

                    // Water Intake
                    _buildToggleWithDropdown(
                      title: "WATER INTAKE",
                      subtitle: "NOTIFY EVERY $_waterMinutesInterval MINUTES",
                      value: _waterIntake,
                      onToggle: (val) => setState(() => _waterIntake = val),
                      dropdown: _buildSmallDropdown(
                        value: _waterMinutesInterval,
                        items: [30, 60, 90, 120, 180],
                        suffix: "MINS",
                        onChanged: (val) => setState(() => _waterMinutesInterval = val!),
                      ),
                    ),

                    // Weight Measurement
                    _buildToggleWithDropdown(
                      title: "WEIGHT MEASUREMENT",
                      subtitle: "REMIND ME EVERY $_weightDaysInterval DAYS",
                      value: _weightMeasurement,
                      onToggle: (val) => setState(() => _weightMeasurement = val),
                      dropdown: _buildSmallDropdown(
                        value: _weightDaysInterval,
                        items: [1, 7, 14, 30],
                        suffix: "DAYS",
                        onChanged: (val) => setState(() => _weightDaysInterval = val!),
                      ),
                    ),

                    // Sleep Reminders
                    _buildToggleWithDropdown(
                      title: "SLEEP REMINDERS",
                      subtitle: "REMIND ME $_sleepHoursPrior HR PRIOR TO BEDTIME",
                      value: _sleepReminders,
                      onToggle: (val) => setState(() => _sleepReminders = val),
                      dropdown: _buildSmallDropdown(
                        value: _sleepHoursPrior,
                        items: [1, 2, 3],
                        suffix: "HRS",
                        onChanged: (val) => setState(() => _sleepHoursPrior = val!),
                      ),
                    ),

                    SizedBox(height: 32.h),
                    _buildSectionHeader("SYSTEM"),
                    _buildSimpleToggle(
                      title: "APP UPDATES",
                      subtitle: "NEW FEATURES AND SYSTEM IMPROVEMENTS",
                      value: _appUpdates,
                      onChanged: (val) => setState(() => _appUpdates = val),
                    ),
                    
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

  // ─── REUSABLE COMPONENTS ──────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.crimson,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildToggleWithDropdown({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onToggle,
    required Widget dropdown,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                    Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp, letterSpacing: 0)),
                  ],
                ),
              ),
              Switch(
                value: value,
                activeColor: AppColors.crimson,
                onChanged: onToggle,
              ),
            ],
          ),
          if (value) ...[
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("REPETITION INTERVAL", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.textSecondary)),
                dropdown,
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSimpleToggle({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp, letterSpacing: 0)),
              ],
            ),
          ),
          Switch(value: value, activeColor: AppColors.crimson, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown({required int value, required List<int> items, required String suffix, required Function(int?) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.crimson, size: 16.r),
        items: items.map((int val) {
          return DropdownMenuItem<int>(
            value: val,
            child: Text("$val $suffix", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.white)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}