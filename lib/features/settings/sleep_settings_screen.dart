import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

import 'package:heavy_duty/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:provider/provider.dart';

class SleepSettingsScreen extends StatefulWidget {
  const SleepSettingsScreen({super.key});

  @override
  State<SleepSettingsScreen> createState() => _SleepSettingsScreenState();
}

class _SleepSettingsScreenState extends State<SleepSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SleepProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

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
                        
                        _buildSectionHeader("TIME FORMAT"),
                        
                        _buildToggleCard(
                          title: "USE 24-HOUR CLOCK",
                          subtitle: "SWITCH BETWEEN 12H AND 24H FORMAT",
                          value: settings.use24HourClock,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(use24HourClock: val));
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
}
