import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class SupplementSettingsScreen extends StatefulWidget {
  const SupplementSettingsScreen({super.key});

  @override
  State<SupplementSettingsScreen> createState() => _SupplementSettingsScreenState();
}

class _SupplementSettingsScreenState extends State<SupplementSettingsScreen> {
  // Tracking Preferences
  bool _inventoryTracking = true;
  bool _stackReminders = true;
  bool _logWithTraining = true;

  // Reminders
  int _reminderInterval = 4; // Hours

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const EliteSettingsAppBar(title: "STACK SETTINGS"),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    
                    _buildSectionHeader("AUTOMATION"),
                    
                    _buildToggleCard(
                      title: "STACK REMINDERS",
                      subtitle: "NOTIFY WHEN IT'S TIME FOR INTAKE",
                      value: _stackReminders,
                      onChanged: (val) => setState(() => _stackReminders = val),
                    ),

                    if (_stackReminders)
                      _buildSettingCard(
                        title: "REMINDER INTERVAL",
                        subtitle: "EVERY $_reminderInterval HOURS",
                        trailing: _buildSmallDropdown<int>(
                          value: _reminderInterval,
                          items: [2, 4, 6, 8, 12],
                          suffix: "HRS",
                          onChanged: (val) => setState(() => _reminderInterval = val!),
                        ),
                      ),

                    SizedBox(height: 32.h),
                    _buildSectionHeader("LOGGING PROTOCOL"),

                    _buildToggleCard(
                      title: "INVENTORY TRACKING",
                      subtitle: "WARN WHEN SUPPLEMENTS ARE RUNNING LOW",
                      value: _inventoryTracking,
                      onChanged: (val) => setState(() => _inventoryTracking = val),
                    ),

                    _buildToggleCard(
                      title: "LINK TO TRAINING",
                      subtitle: "AUTO-PROMPT LOGGING ON WORKOUT DAYS",
                      value: _logWithTraining,
                      onChanged: (val) => setState(() => _logWithTraining = val),
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

  Widget _buildSettingCard({required String title, required String subtitle, required Widget trailing}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
          trailing,
        ],
      ),
    );
  }

  Widget _buildToggleCard({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
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

  Widget _buildSmallDropdown<T>({required T value, required List<T> items, required String suffix, required Function(T?) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.crimson, size: 16.r),
        items: items.map((T val) {
          return DropdownMenuItem<T>(
            value: val,
            child: Text("$val $suffix", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.white)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}