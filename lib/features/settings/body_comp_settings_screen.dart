import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class BodyCompSettingsScreen extends StatefulWidget {
  const BodyCompSettingsScreen({super.key});

  @override
  State<BodyCompSettingsScreen> createState() => _BodyCompSettingsScreenState();
}

class _BodyCompSettingsScreenState extends State<BodyCompSettingsScreen> {
  // Units
  bool _useMetricWeight = true; // KG vs LBS
  bool _useMetricHeight = true; // CM vs FT/IN

  // Reminders
  bool _weightReminders = true;
  int _weightDaysInterval = 7;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null, // Manual Header Protocol
      body: SafeArea(
        child: Column(
          children: [
            // Standard Heavy Duty Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        "BODY COMP SETTINGS",
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

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),
                    
                    _buildSectionHeader("MEASUREMENT UNITS"),
                    _buildToggleTile(
                      icon: Icons.scale_rounded,
                      title: _useMetricWeight ? "WEIGHT: KILOGRAMS (KG)" : "WEIGHT: POUNDS (LBS)",
                      value: _useMetricWeight,
                      onChanged: (val) => setState(() => _useMetricWeight = val),
                    ),
                    _buildToggleTile(
                      icon: Icons.height_rounded,
                      title: _useMetricHeight ? "HEIGHT: CENTIMETERS (CM)" : "HEIGHT: FEET/INCHES (FT)",
                      value: _useMetricHeight,
                      onChanged: (val) => setState(() => _useMetricHeight = val),
                    ),

                    SizedBox(height: 32.h),
                    _buildSectionHeader("TRACKING REMINDERS"),
                    _buildReminderTile(),
                    
                    SizedBox(height: 32.h),
                    _buildSectionHeader("DATA VISUALIZATION"),
                    _buildSimpleTile(
                      icon: Icons.show_chart_rounded,
                      title: "SHOW GOAL TRENDLINE",
                      subtitle: "VISUALIZE PROGRESS TOWARDS TARGET WEIGHT",
                      trailing: Switch(
                        value: true, 
                        activeColor: AppColors.crimson, 
                        onChanged: (val) {}
                      ),
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

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
          Icon(icon, color: AppColors.white, size: 22.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Switch(value: value, activeColor: AppColors.crimson, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildReminderTile() {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: AppColors.white, size: 22.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Text("WEIGH-IN REMINDERS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
              ),
              Switch(
                value: _weightReminders,
                activeColor: AppColors.crimson,
                onChanged: (val) => setState(() => _weightReminders = val),
              ),
            ],
          ),
          if (_weightReminders) ...[
            const Divider(color: Colors.white10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("REMIND ME EVERY", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.textSecondary)),
                _buildSmallDropdown(
                  value: _weightDaysInterval,
                  items: [1, 3, 7, 14, 30],
                  suffix: "DAYS",
                  onChanged: (val) => setState(() => _weightDaysInterval = val!),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildSimpleTile({required IconData icon, required String title, required String subtitle, required Widget trailing}) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: 22.r),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSmallDropdown({required int value, required List<int> items, required String suffix, required Function(int?) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r)),
      child: DropdownButton<int>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        items: items.map((val) => DropdownMenuItem(
          value: val,
          child: Text("$val $suffix", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.white)),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}