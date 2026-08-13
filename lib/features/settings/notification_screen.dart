import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:heavy_duty/features/tracker/sleep/provider/sleep_alarm_provider.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

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
            // ── HEADER ───────────────────────────────────────────────────────
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
                        "SIGNAL COMMAND",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(color: AppColors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Opacity(opacity: 0, child: IconButton(icon: Icon(Icons.close), onPressed: null)),
                  ],
                ),
              ),
            ),

            // ── CONTENT ──────────────────────────────────────────────────────
            Expanded(
              child: Consumer5<SupplementProvider, CalorieProvider, HydrationProvider, SleepAlarmProvider, CycleProvider>(
                builder: (context, suppProv, calProv, hydProv, sleepProv, cycleProv, _) {
                  
                  final activeSupps = suppProv.library.where((s) => s.isActive && s.notificationsEnabled).toList();
                  final activeStacks = suppProv.supplementStacks.where((s) => s.notificationsEnabled).toList();
                  final activeMeals = calProv.savedMeals.where((m) => m.notificationsEnabled).toList();
                  final bool workoutReminders = cycleProv.settings.workoutRemindersEnabled;
                  final bool waterReminders = hydProv.settings.remindersEnabled;
                  final bool bedtimeAlarm = sleepProv.settings.bedtimeEnabled;
                  final bool wakeUpAlarm = sleepProv.settings.wakeUpEnabled;

                  final bool hasAnySignal = activeSupps.isNotEmpty || 
                                          activeStacks.isNotEmpty || 
                                          activeMeals.isNotEmpty || 
                                          workoutReminders || 
                                          waterReminders || 
                                          bedtimeAlarm || 
                                          wakeUpAlarm;

                  if (!hasAnySignal) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 48.r, color: AppColors.textSecondary.withOpacity(0.1)),
                          SizedBox(height: 16.h),
                          Text(
                            "NO ACTIVE SIGNALS",
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary.withOpacity(0.3), letterSpacing: 2),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      // 1. RECOVERY SIGNALS
                      if (bedtimeAlarm || wakeUpAlarm) ...[
                        _buildSectionHeader("RECOVERY PROTOCOLS"),
                        if (bedtimeAlarm)
                          _buildSignalTile(
                            icon: Icons.bedtime_rounded,
                            title: "BEDTIME REMINDER",
                            subtitle: "Target: ${TimeOfDay(hour: sleepProv.settings.bedtimeHour, minute: sleepProv.settings.bedtimeMinute).format(context)}",
                            value: true,
                            onChanged: (val) => sleepProv.updateSettings(bedtimeEnabled: val),
                          ),
                        if (wakeUpAlarm)
                          _buildSignalTile(
                            icon: Icons.wb_sunny_rounded,
                            title: "WAKE-UP ALARM",
                            subtitle: "Target: ${TimeOfDay(hour: sleepProv.settings.wakeUpHour, minute: sleepProv.settings.wakeUpMinute).format(context)}",
                            value: true,
                            onChanged: (val) => sleepProv.updateSettings(wakeUpEnabled: val),
                          ),
                        SizedBox(height: 24.h),
                      ],

                      // 2. TRAINING SIGNALS
                      if (workoutReminders) ...[
                        _buildSectionHeader("TRAINING PROTOCOLS"),
                        _buildSignalTile(
                          icon: Icons.bolt_rounded,
                          title: "WORKOUT SCHEDULE",
                          subtitle: "Interval: Every ${cycleProv.settings.workoutReminderInterval} Days",
                          value: true,
                          onChanged: (val) => cycleProv.updateSettings(cycleProv.settings.copyWith(workoutRemindersEnabled: val)),
                        ),
                        SizedBox(height: 24.h),
                      ],

                      // 3. HYDRATION SIGNALS
                      if (waterReminders) ...[
                        _buildSectionHeader("HYDRATION SYSTEM"),
                        _buildSignalTile(
                          icon: Icons.water_drop_rounded,
                          title: "SYSTEMIC HYDRATION",
                          subtitle: "Active Monitoring Protocol",
                          value: true,
                          onChanged: (val) => hydProv.updateSettings(hydProv.settings.copyWith(remindersEnabled: val)),
                        ),
                        SizedBox(height: 24.h),
                      ],

                      // 4. SUPPLEMENT SIGNALS
                      if (activeSupps.isNotEmpty || activeStacks.isNotEmpty) ...[
                        _buildSectionHeader("SUPPLEMENT INTERVENTIONS"),
                        ...activeSupps.map((s) => _buildSignalTile(
                          icon: Icons.medication_rounded,
                          title: s.name.toUpperCase(),
                          subtitle: "Active Intake Reminders",
                          value: true,
                          onChanged: (val) => suppProv.updateReminders(s.id, s.reminders, val),
                        )),
                        ...activeStacks.map((st) => _buildSignalTile(
                          icon: Icons.layers_rounded,
                          title: "STACK: ${st.name.toUpperCase()}",
                          subtitle: "Protocol Bundle Active",
                          value: true,
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
                          subtitle: "Scheduled Meal Entry",
                          value: true,
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
