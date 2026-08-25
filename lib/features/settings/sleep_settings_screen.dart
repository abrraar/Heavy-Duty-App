import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';

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
                        
                        _buildSectionHeader("GLOBAL PREFERENCES"),
                        
                        EliteUnitToggleCard(
                          title: "Time Format",
                          subtitle: "Switch between 12H and 24H clock",
                          options: const ["12H", "24H"],
                          selectedIndex: settings.use24HourClock ? 1 : 0,
                          selectedColor: AppColors.crimson,
                          onSelected: (v) {
                            provider.updateSettings(settings.copyWith(
                              use24HourClock: v == 1,
                            ));
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
}
