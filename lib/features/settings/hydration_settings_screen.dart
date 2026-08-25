// lib/features/settings/hydration_settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';
import 'package:heavy_duty/features/tracker/hydration/widgets/sheets/hydration_notification_sheet.dart';
import 'package:provider/provider.dart';
import '../tracker/hydration/model/hydration_settings.dart';
import '../tracker/hydration/provider/hydration_provider.dart';

class HydrationSettingsScreen extends StatefulWidget {
  const HydrationSettingsScreen({super.key});

  @override
  State<HydrationSettingsScreen> createState() => _HydrationSettingsScreenState();
}

class _HydrationSettingsScreenState extends State<HydrationSettingsScreen> {
  late TextEditingController _goalController;
  late TextEditingController _addController;
  late TextEditingController _minusController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<HydrationProvider>();
    final settings = provider.settings;
    
    double goalVal = settings.unit == HydrationUnit.ml ? settings.dailyGoal.toDouble() : provider.mlToOz(settings.dailyGoal);
    double addVal = settings.unit == HydrationUnit.ml ? settings.addValue.toDouble() : provider.mlToOz(settings.addValue);
    double minusVal = settings.unit == HydrationUnit.ml ? settings.minusValue.toDouble() : provider.mlToOz(settings.minusValue);
    
    _goalController = TextEditingController(text: goalVal.toStringAsFixed(0));
    _addController = TextEditingController(text: addVal.toStringAsFixed(0));
    _minusController = TextEditingController(text: minusVal.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _goalController.dispose();
    _addController.dispose();
    _minusController.dispose();
    super.dispose();
  }

  void _openNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const HydrationNotificationSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HydrationProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const EliteSettingsAppBar(title: "HYDRATION SETTINGS"),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        _buildSectionHeader("GOALS & MEASURES"),
                        _buildManualInputTile(
                          icon: Icons.track_changes_rounded,
                          title: "DAILY GOAL",
                          subtitle: "YOUR TARGET WATER INTAKE",
                          controller: _goalController,
                          suffix: settings.unit == HydrationUnit.ml ? "ML" : "OZ",
                          onChanged: (val) {
                            int? numeric = int.tryParse(val);
                            if (numeric != null && numeric > 0) {
                              int mlValue = settings.unit == HydrationUnit.ml ? numeric : provider.ozToMl(numeric.toDouble());
                              provider.updateSettings(settings.copyWith(dailyGoal: mlValue));
                            }
                          },
                        ),
                        SizedBox(height: 12.h),
                        EliteUnitToggleCard(
                          title: "Hydration Unit",
                          subtitle: "Switch between ML and OZ",
                          options: const ["OZ", "ML"],
                          selectedIndex: settings.unit == HydrationUnit.ml ? 1 : 0,
                          selectedColor: Colors.blueAccent,
                          onSelected: (index) {
                            final HydrationUnit newUnit = index == 1 ? HydrationUnit.ml : HydrationUnit.oz;
                            // Update display controllers first
                            int currentGoalMl = settings.dailyGoal;
                            int currentAddMl = settings.addValue;
                            int currentMinusMl = settings.minusValue;
                            
                            if (newUnit == HydrationUnit.ml) { // Switched to ML
                              _goalController.text = currentGoalMl.toString();
                              _addController.text = currentAddMl.toString();
                              _minusController.text = currentMinusMl.toString();
                            } else { // Switched to OZ
                              _goalController.text = provider.mlToOz(currentGoalMl).toStringAsFixed(0);
                              _addController.text = provider.mlToOz(currentAddMl).toStringAsFixed(0);
                              _minusController.text = provider.mlToOz(currentMinusMl).toStringAsFixed(0);
                            }
                            
                            provider.updateSettings(settings.copyWith(unit: newUnit));
                          },
                        ),
                        SizedBox(height: 32.h),
                        _buildSectionHeader("QUICK LOG CALIBRATION"),
                        _buildManualInputTile(
                          icon: Icons.add_circle_outline_rounded,
                          title: "POSITIVE (+) INCREMENT",
                          subtitle: "VALUE FOR THE ADD BUTTON",
                          controller: _addController,
                          suffix: settings.unit == HydrationUnit.ml ? "ML" : "OZ",
                          onChanged: (val) {
                            int? numeric = int.tryParse(val);
                            if (numeric != null && numeric > 0) {
                              int mlValue = settings.unit == HydrationUnit.ml ? numeric : provider.ozToMl(numeric.toDouble());
                              provider.updateSettings(settings.copyWith(addValue: mlValue));
                            }
                          },
                        ),
                        SizedBox(height: 12.h),
                        _buildManualInputTile(
                          icon: Icons.remove_circle_outline_rounded,
                          title: "NEGATIVE (-) INCREMENT",
                          subtitle: "VALUE FOR THE SUBTRACT BUTTON",
                          controller: _minusController,
                          suffix: settings.unit == HydrationUnit.ml ? "ML" : "OZ",
                          onChanged: (val) {
                            int? numeric = int.tryParse(val);
                            if (numeric != null && numeric > 0) {
                              int mlValue = settings.unit == HydrationUnit.ml ? numeric : provider.ozToMl(numeric.toDouble());
                              provider.updateSettings(settings.copyWith(minusValue: mlValue));
                            }
                          },
                        ),
                        SizedBox(height: 32.h),
                        _buildSectionHeader("AUTOMATION & DISPLAY"),
                        _buildToggleCard(
                          icon: Icons.push_pin_rounded,
                          title: "PIN TO HOME SCREEN",
                          subtitle: "SHOW TRACKER ON DASHBOARD",
                          value: settings.isPinnedToHome,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(isPinnedToHome: val));
                          },
                        ),
                        SizedBox(height: 12.h),
                        _buildReminderCard(
                          title: "INTAKE REMINDERS",
                          isEnabled: settings.remindersEnabled,
                          onTap: _openNotifications,
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
          color: Colors.blueAccent, 
          fontWeight: FontWeight.w900, 
          letterSpacing: 1.5
        ),
      ),
    );
  }

  Widget _buildManualInputTile({
    required IconData icon, 
    required String title, 
    required String subtitle, 
    required TextEditingController controller, 
    required String suffix, 
    required ValueChanged<String> onChanged
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(12.r), 
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05))
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
          Container(
            width: 80.w,
            height: 36.h,
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8.r)),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, 
                LengthLimitingTextInputFormatter(4)
              ],
              decoration: InputDecoration(
                border: InputBorder.none, 
                isDense: true, 
                contentPadding: EdgeInsets.zero,
                suffixText: " $suffix",
                suffixStyle: AppTextStyles.labelSmall.copyWith(fontSize: 8.sp, color: AppColors.textSecondary),
              ),
              onChanged: (val) {
                if (val.isNotEmpty) {
                  onChanged(val);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required IconData icon,
    required String title, 
    required String subtitle, 
    required bool value, 
    required ValueChanged<bool> onChanged
  }) {
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
          Switch(
            value: value, 
            activeThumbColor: Colors.blueAccent, 
            onChanged: onChanged
          ),
        ],
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
            Icon(Icons.notifications_active_rounded, color: isEnabled ? Colors.blueAccent : AppColors.white, size: 22.r),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                  Text(
                    isEnabled ? "ACTIVE" : "DISABLED",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isEnabled ? Colors.blueAccent : AppColors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
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
