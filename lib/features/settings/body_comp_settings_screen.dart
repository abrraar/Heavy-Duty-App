import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import 'package:heavy_duty/features/tracker/body_composition/widgets/body_comp_notification_sheet.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:heavy_duty/features/tracker/body_composition/model/body_comp_settings.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';

class BodyCompConfigScreen extends StatefulWidget {
  const BodyCompConfigScreen({super.key});

  @override
  State<BodyCompConfigScreen> createState() => _BodyCompConfigScreenState();
}

class _BodyCompConfigScreenState extends State<BodyCompConfigScreen> {
  void _showReminderSheet(String type, BodyCompProvider provider) {
    String title = "";
    List<BodyCompReminder> initialReminders = [];
    bool initialEnabled = false;

    if (type == "weight") {
      title = "Weight";
      initialReminders = provider.settings.weightReminders;
      initialEnabled = provider.settings.weightRemindersEnabled;
    } else if (type == "fat") {
      title = "Body Fat";
      initialReminders = provider.settings.fatReminders;
      initialEnabled = provider.settings.fatRemindersEnabled;
    } else if (type == "muscle") {
      title = "Muscle Mass";
      initialReminders = provider.settings.muscleReminders;
      initialEnabled = provider.settings.muscleRemindersEnabled;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BodyCompNotificationSheet(
        title: title,
        initialReminders: initialReminders,
        initialEnabled: initialEnabled,
        onSave: (enabled, reminders) {
          BodyCompSettings updatedSettings = provider.settings;
          if (type == "weight") {
            updatedSettings = provider.settings.copyWith(
              weightRemindersEnabled: enabled,
              weightReminders: reminders,
            );
          } else if (type == "fat") {
            updatedSettings = provider.settings.copyWith(
              fatRemindersEnabled: enabled,
              fatReminders: reminders,
            );
          } else if (type == "muscle") {
            updatedSettings = provider.settings.copyWith(
              muscleRemindersEnabled: enabled,
              muscleReminders: reminders,
            );
          }
          
          provider.updateSettings(updatedSettings);

          // If it was turned ON, show confirmation
          if (enabled && !initialEnabled && mounted) {
            EliteSnackbar.show(context, "${title.toUpperCase()} REMINDER ACTIVATED");
          }
        },
      ),
    );
  }

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
                        _buildReminderCard(
                          title: "Weight Reminders",
                          isEnabled: provider.settings.weightRemindersEnabled,
                          onTap: () => _showReminderSheet("weight", provider),
                        ),
                        SizedBox(height: 12.h),
                        _buildReminderCard(
                          title: "Body Fat Reminders",
                          isEnabled: provider.settings.fatRemindersEnabled,
                          onTap: () => _showReminderSheet("fat", provider),
                        ),
                        SizedBox(height: 12.h),
                        _buildReminderCard(
                          title: "Muscle Mass Reminders",
                          isEnabled: provider.settings.muscleRemindersEnabled,
                          onTap: () => _showReminderSheet("muscle", provider),
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
          fontWeight: FontWeight.w500,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildReminderCard({required String title, required bool isEnabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: isEnabled ? AppColors.crimson : AppColors.white, size: 22.r),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                  Text(
                    isEnabled ? "ACTIVE" : "DISABLED",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isEnabled ? AppColors.crimson : AppColors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 14.r),
          ],
        ),
      ),
    );
  }
}
