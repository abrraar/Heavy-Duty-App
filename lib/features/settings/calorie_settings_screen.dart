import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../tracker/calorie/provider/calorie_provider.dart';

class CalorieSettingsScreen extends StatefulWidget {
  const CalorieSettingsScreen({super.key});

  @override
  State<CalorieSettingsScreen> createState() => _CalorieSettingsScreenState();
}

class _CalorieSettingsScreenState extends State<CalorieSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Header (Heavy Duty Protocol)
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
                            "CALORIE SETTINGS",
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
                        
                        _buildSectionHeader("NUTRITIONAL TARGETS"),
                        
                        // Daily Calorie Goal
                        _buildSettingCard(
                          title: "DAILY CALORIE GOAL",
                          subtitle: "TOTAL ENERGY INTAKE TARGET",
                          trailing: _buildSmallDropdown<int>(
                            value: settings.dailyCalorieGoal,
                            items: [2000, 2200, 2500, 2800, 3000, 3500],
                            suffix: "KCAL",
                            onChanged: (val) {
                              provider.updateSettings(settings.copyWith(dailyCalorieGoal: val));
                            },
                          ),
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader("MACRO RATIOS (%)"),

                        // Protein Ratio
                        _buildSettingCard(
                          title: "PROTEIN TARGET",
                          subtitle: "PERCENTAGE OF TOTAL CALORIES",
                          trailing: _buildSmallDropdown<int>(
                            value: settings.proteinPercent,
                            items: [20, 25, 30, 35, 40],
                            suffix: "%",
                            onChanged: (val) {
                               provider.updateSettings(settings.copyWith(proteinPercent: val));
                            },
                          ),
                        ),

                        // Carb Ratio
                        _buildSettingCard(
                          title: "CARBOHYDRATE TARGET",
                          subtitle: "PERCENTAGE OF TOTAL CALORIES",
                          trailing: _buildSmallDropdown<int>(
                            value: settings.carbPercent,
                            items: [30, 40, 50, 60],
                            suffix: "%",
                            onChanged: (val) {
                              provider.updateSettings(settings.copyWith(carbPercent: val));
                            },
                          ),
                        ),

                        // Fat Ratio
                        _buildSettingCard(
                          title: "FAT TARGET",
                          subtitle: "PERCENTAGE OF TOTAL CALORIES",
                          trailing: _buildSmallDropdown<int>(
                            value: settings.fatPercent,
                            items: [10, 15, 20, 25, 30],
                            suffix: "%",
                            onChanged: (val) {
                              provider.updateSettings(settings.copyWith(fatPercent: val));
                            },
                          ),
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader("DISPLAY PREFERENCES"),

                        _buildToggleCard(
                          title: "TRACK MACRONUTRIENTS",
                          subtitle: "SHOW PROTEIN, CARBS, AND FATS",
                          value: settings.trackMacros,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(trackMacros: val));
                          },
                        ),

                        _buildToggleCard(
                          title: "SHOW REMAINING",
                          subtitle: "DISPLAY CALORIES LEFT FOR THE DAY",
                          value: settings.showRemaining,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(showRemaining: val));
                          },
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

  // ─── REUSABLE COMPONENTS (Matches Notification/Sleep Settings) ─────────────

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