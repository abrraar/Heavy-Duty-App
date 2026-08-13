import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:heavy_duty/features/tracker/sleep/provider/sleep_alarm_provider.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../tracker/supplement/model/supplement.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const EliteSettingsAppBar(title: "SIGNAL COMMAND"),

            // ── CONTENT ──────────────────────────────────────────────────────
            Expanded(
              child: Consumer5<SupplementProvider, CalorieProvider, HydrationProvider, SleepAlarmProvider, CycleProvider>(
                builder: (context, suppProv, calProv, hydProv, sleepProv, cycleProv, _) {
                  final activeSupps = suppProv.library.where((s) => s.isActive && s.reminders.any((r) => r.type == ReminderType.intake)).toList();
                  final activeStacks = suppProv.supplementStacks.where((s) => s.reminders.any((r) => r.type == ReminderType.intake)).toList();
                  final activeMeals = calProv.savedMeals.where((m) => m.reminders.isNotEmpty).toList();
                  final bool workoutReminders = cycleProv.settings.workoutRemindersEnabled;
                  final bool waterReminders = hydProv.settings.remindersEnabled;
                  final bool bedtimeAlarm = sleepProv.settings.bedtimeEnabled;
                  final bool wakeUpAlarm = sleepProv.settings.wakeUpEnabled;

                  return ListView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. RECOVERY SIGNALS
                      _buildSectionHeader("RECOVERY PROTOCOLS"),
                      _buildSignalTile(
                        icon: Icons.bedtime_rounded,
                        title: "BEDTIME REMINDER",
                        subtitle: bedtimeAlarm 
                            ? "Target: ${TimeOfDay(hour: sleepProv.settings.bedtimeHour, minute: sleepProv.settings.bedtimeMinute).format(context)}"
                            : "Protocol Offline",
                        value: bedtimeAlarm,
                        onChanged: (val) => sleepProv.updateSettings(bedtimeEnabled: val),
                      ),
                      _buildSignalTile(
                        icon: Icons.wb_sunny_rounded,
                        title: "WAKE-UP ALARM",
                        subtitle: wakeUpAlarm
                            ? "Target: ${TimeOfDay(hour: sleepProv.settings.wakeUpHour, minute: sleepProv.settings.wakeUpMinute).format(context)}"
                            : "Protocol Offline",
                        value: wakeUpAlarm,
                        onChanged: (val) => sleepProv.updateSettings(wakeUpEnabled: val),
                      ),
                      SizedBox(height: 24.h),

                      // 2. TRAINING SIGNALS
                      _buildSectionHeader("TRAINING PROTOCOLS"),
                      _buildSignalTile(
                        icon: Icons.bolt_rounded,
                        title: "WORKOUT SCHEDULE",
                        subtitle: workoutReminders 
                            ? "Interval: Every ${cycleProv.settings.workoutReminderInterval} Days"
                            : "Protocol Offline",
                        value: workoutReminders,
                        onChanged: (val) => cycleProv.updateSettings(cycleProv.settings.copyWith(workoutRemindersEnabled: val)),
                      ),
                      SizedBox(height: 24.h),

                      // 3. HYDRATION SIGNALS
                      _buildSectionHeader("HYDRATION SYSTEM"),
                      _buildSignalTile(
                        icon: Icons.water_drop_rounded,
                        title: "SYSTEMIC HYDRATION",
                        subtitle: waterReminders ? "Active Monitoring Protocol" : "Protocol Offline",
                        value: waterReminders,
                        onChanged: (val) => hydProv.updateSettings(hydProv.settings.copyWith(remindersEnabled: val)),
                      ),
                      SizedBox(height: 24.h),

                      // 4. SUPPLEMENT SIGNALS
                      if (activeSupps.isNotEmpty || activeStacks.isNotEmpty) ...[
                        _buildSectionHeader("SUPPLEMENT INTERVENTIONS"),
                        ...activeSupps.map((s) => _buildSignalTile(
                          icon: Icons.medication_rounded,
                          title: s.name.toUpperCase(),
                          subtitle: s.notificationsEnabled ? "Active Intake Reminders" : "Reminders Paused",
                          value: s.notificationsEnabled,
                          onChanged: (val) => suppProv.updateReminders(s.id, s.reminders, val),
                        )),
                        ...activeStacks.map((st) => _buildSignalTile(
                          icon: Icons.layers_rounded,
                          title: "STACK: ${st.name.toUpperCase()}",
                          subtitle: st.notificationsEnabled ? "Protocol Bundle Active" : "Bundle Paused",
                          value: st.notificationsEnabled,
                          onChanged: (val) => suppProv.updateStackNotifications(st.id, st.reminders, val),
                        )),
                        SizedBox(height: 24.h),
                      ],

                      // 5. NUTRITION SIGNALS
                      if (activeMeals.isNotEmpty) ...[
                        _buildSectionHeader("NUTRITION LEDGER"),
                        ...activeMeals.map((m) => _buildSignalTile(
                          icon: Icons.restaurant_rounded,
                          title: m.name.toUpperCase(),
                          subtitle: m.notificationsEnabled ? "Scheduled Meal Entry" : "Schedule Paused",
                          value: m.notificationsEnabled,
                          onChanged: (val) => calProv.updateSavedMeal(m.copyWith(notificationsEnabled: val)),
                        )),
                        SizedBox(height: 24.h),
                      ],

                      SizedBox(height: 40.h),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── UI COMPONENTS ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildSignalTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.r),
            decoration: BoxDecoration(color: AppColors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12.r)),
            child: Icon(icon, color: AppColors.white, size: 20.r),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp, letterSpacing: 0)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value, 
            onChanged: onChanged,
            activeColor: AppColors.crimson,
          ),
        ],
      ),
    );
  }
}
