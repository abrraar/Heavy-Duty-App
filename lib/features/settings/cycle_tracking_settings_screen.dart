import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:provider/provider.dart';

class CycleTrackingSettingsScreen extends StatefulWidget {
  const CycleTrackingSettingsScreen({super.key});

  @override
  State<CycleTrackingSettingsScreen> createState() => _CycleTrackingSettingsScreenState();
}

class _CycleTrackingSettingsScreenState extends State<CycleTrackingSettingsScreen> {
  late TextEditingController _intervalController;
  late bool _workoutReminders;
  late int _workoutDaysInterval;

  @override
  void initState() {
    super.initState();
    final settings = context.read<CycleProvider>().settings;
    _workoutReminders = settings.workoutRemindersEnabled;
    _workoutDaysInterval = settings.workoutReminderInterval;
    _intervalController = TextEditingController(text: _workoutDaysInterval.toString());
  }

  @override
  void dispose() {
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CycleProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const EliteSettingsAppBar(title: 'TRAINING SETTINGS'),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('WORKOUT REMINDERS'),
                          SizedBox(height: 12.h),
                          
                          _buildNotificationCard(
                            title: "Workout Schedule",
                            subtitle: "Remind me to train every",
                            value: _workoutReminders,
                            onChanged: (val) {
                              setState(() => _workoutReminders = val);
                              provider.updateSettings(provider.settings.copyWith(
                                workoutRemindersEnabled: val,
                                workoutReminderInterval: _workoutDaysInterval,
                              ));
                            },
                            child: _buildSmallTextField(
                              controller: _intervalController,
                              suffix: "Days",
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null) {
                                  setState(() => _workoutDaysInterval = parsed);
                                  provider.updateSettings(provider.settings.copyWith(
                                    workoutRemindersEnabled: _workoutReminders,
                                    workoutReminderInterval: parsed,
                                  ));
                                }
                              },
                            ),
                          ),

                          SizedBox(height: 32.h),

                          _buildSectionHeader('DISPLAY UNITS'),
                          SizedBox(height: 12.h),

                          EliteUnitToggleCard(
                            title: "Weight Unit",
                            subtitle: "Switch between LBS and KGS",
                            options: const ["LBS", "KGS"],
                            selectedIndex: provider.settings.weightUnit == WeightUnit.lbs ? 0 : 1,
                            onSelected: (index) {
                              provider.updateSettings(provider.settings.copyWith(
                                weightUnit: index == 0 ? WeightUnit.lbs : WeightUnit.kgs,
                              ));
                            },
                          ),

                          // ── NAVIGATION & SPACING FIX ──
                          SizedBox(height: MediaQuery.of(context).padding.bottom + 100.h),
                        ],
                      ),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 3.w,
          height: 12.h,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(2.r),
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.7),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard({
    required String title, 
    required String subtitle, 
    required bool value, 
    required Function(bool) onChanged,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.labelMedium),
              Switch.adaptive(
                value: value, 
                onChanged: onChanged,
                activeColor: AppColors.crimson,
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              child,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTextField({required TextEditingController controller, required String suffix, required Function(String) onChanged}) {
    return Container(
      width: 100.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(2),
              ],
              onChanged: onChanged,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            suffix,
            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}
