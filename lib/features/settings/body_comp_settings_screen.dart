import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:heavy_duty/features/tracker/body_composition/model/body_comp_settings.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';

class BodyCompSettingsScreen extends StatefulWidget {
  const BodyCompSettingsScreen({super.key});

  @override
  State<BodyCompSettingsScreen> createState() => _BodyCompSettingsScreenState();
}

class _BodyCompSettingsScreenState extends State<BodyCompSettingsScreen> {
  // Reminders
  bool _weightReminders = true;
  int _weightDaysInterval = 7;

  @override
  Widget build(BuildContext context) {
    return Consumer<BodyCompProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const EliteSettingsAppBar(title: "BODY COMP SETTINGS"),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        
                        _buildSectionHeader("MEASUREMENT UNITS"),
                        EliteUnitToggleCard(
                          title: "Body Comp Weight Unit",
                          subtitle: "Switch between LBS and KGS",
                          options: const ["LBS", "KGS"],
                          selectedIndex: provider.settings.weightUnit == WeightUnit.kgs ? 1 : 0,
                          onSelected: (index) {
                            provider.updateSettings(provider.settings.copyWith(
                              weightUnit: index == 1 ? WeightUnit.kgs : WeightUnit.lbs,
                            ));
                          },
                        ),
                        SizedBox(height: 12.h),
                        EliteUnitToggleCard(
                          title: "Height Unit",
                          subtitle: "Switch between CM and FT/IN",
                          options: const ["FT", "CM"],
                          selectedIndex: provider.settings.heightUnit == HeightUnit.cm ? 1 : 0,
                          onSelected: (index) {
                            provider.updateSettings(provider.settings.copyWith(
                              heightUnit: index == 1 ? HeightUnit.cm : HeightUnit.ftIn,
                            ));
                          },
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
      },
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
