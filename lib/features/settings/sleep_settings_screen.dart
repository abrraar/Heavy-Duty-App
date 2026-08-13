import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class SleepSettingsScreen extends StatefulWidget {
  const SleepSettingsScreen({super.key});

  @override
  State<SleepSettingsScreen> createState() => _SleepSettingsScreenState();
}

class _SleepSettingsScreenState extends State<SleepSettingsScreen> {
  // Sleep Targets
  double _sleepGoalHours = 8.0;
  TimeOfDay _targetBedtime = const TimeOfDay(hour: 22, minute: 0);
  
  // Tracking Preferences
  bool _trackRemCycles = true;
  bool _autoLogSleep = false;
  bool _recoveryCorrelation = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const EliteSettingsAppBar(title: "SLEEP SETTINGS"),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    
                    _buildSectionHeader("RECOVERY TARGETS"),
                    
                    // Sleep Goal Duration
                    _buildSettingCard(
                      title: "DAILY SLEEP GOAL",
                      subtitle: "CURRENT TARGET: ${_sleepGoalHours.toStringAsFixed(1)} HRS",
                      trailing: _buildSmallDropdown<double>(
                        value: _sleepGoalHours,
                        items: [6.0, 7.0, 7.5, 8.0, 8.5, 9.0],
                        suffix: "HRS",
                        onChanged: (val) => setState(() => _sleepGoalHours = val!),
                      ),
                    ),

                    // Target Bedtime
                    _buildSettingCard(
                      title: "TARGET BEDTIME",
                      subtitle: "IDEAL TIME TO START RECOVERY",
                      trailing: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context, 
                            initialTime: _targetBedtime,
                          );
                          if (picked != null) setState(() => _targetBedtime = picked);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            _targetBedtime.format(context),
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 32.h),
                    _buildSectionHeader("TRACKING PREFERENCES"),

                    _buildToggleCard(
                      title: "DETAILED CYCLES",
                      subtitle: "LOG REM AND DEEP SLEEP PHASES",
                      value: _trackRemCycles,
                      onChanged: (val) => setState(() => _trackRemCycles = val),
                    ),

                    _buildToggleCard(
                      title: "AUTO-LOGGING",
                      subtitle: "SYNC FROM HEALTH KIT OR WEARABLES",
                      value: _autoLogSleep,
                      onChanged: (val) => setState(() => _autoLogSleep = val),
                    ),

                    _buildToggleCard(
                      title: "RECOVERY CORRELATION",
                      subtitle: "LINK SLEEP QUALITY TO TRAINING OUTPUT",
                      value: _recoveryCorrelation,
                      onChanged: (val) => setState(() => _recoveryCorrelation = val),
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