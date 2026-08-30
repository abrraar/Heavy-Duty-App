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

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isCompact = constraints.maxWidth < 600 && !isLargeScreen;
            final bool isWideLandscape = isLargeScreen && MediaQuery.of(context).orientation == Orientation.landscape;

            return Column(
              children: [
                EliteSettingsAppBar(
                  title: "SIGNAL COMMAND", 
                  isCompact: isCompact,
                  showBackButton: !isWideLandscape,
                ),

                // ── CONTENT ──────────────────────────────────────────────────────
                Expanded(
                  child: Consumer5<SupplementProvider, CalorieProvider, HydrationProvider, SleepAlarmProvider, CycleProvider>(
                    builder: (context, suppProv, calProv, hydProv, sleepProv, cycleProv, _) {
                      final activeMeals = calProv.savedMeals.where((m) => m.reminders.isNotEmpty).toList();
                      final bool workoutReminders = cycleProv.settings.workoutRemindersEnabled;
                      final bool waterReminders = hydProv.settings.remindersEnabled;
                      final bool bedtimeAlarm = sleepProv.settings.bedtimeEnabled;
                      final bool wakeUpAlarm = sleepProv.settings.wakeUpEnabled;

                      return ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: isLargeScreen ? 24.0 : 24.w, 
                              vertical: isLargeScreen ? 16.0 : 16.h
                            ),
                            physics: const BouncingScrollPhysics(),
                            children: [
                              // 1. RECOVERY SIGNALS
                              _buildSectionHeader("RECOVERY PROTOCOLS", isCompact, isLargeScreen),
                              _buildSignalTile(
                                icon: Icons.bedtime_rounded,
                                title: "BEDTIME REMINDER",
                                subtitle: bedtimeAlarm 
                                    ? "Target: ${TimeOfDay(hour: sleepProv.settings.bedtimeHour, minute: sleepProv.settings.bedtimeMinute).format(context)}"
                                    : "Protocol Offline",
                                value: bedtimeAlarm,
                                onChanged: (val) => sleepProv.updateSettings(bedtimeEnabled: val),
                                isLargeScreen: isLargeScreen,
                              ),
                              _buildSignalTile(
                                icon: Icons.wb_sunny_rounded,
                                title: "WAKE-UP ALARM",
                                subtitle: wakeUpAlarm
                                    ? "Target: ${TimeOfDay(hour: sleepProv.settings.wakeUpHour, minute: sleepProv.settings.wakeUpMinute).format(context)}"
                                    : "Protocol Offline",
                                value: wakeUpAlarm,
                                onChanged: (val) => sleepProv.updateSettings(wakeUpEnabled: val),
                                isLargeScreen: isLargeScreen,
                              ),
                              SizedBox(height: isLargeScreen ? 24.0 : 24.h),

                              // 2. TRAINING SIGNALS
                              _buildSectionHeader("TRAINING PROTOCOLS", isCompact, isLargeScreen),
                              _buildSignalTile(
                                icon: Icons.bolt_rounded,
                                title: "WORKOUT SCHEDULE",
                                subtitle: workoutReminders 
                                    ? "Interval: Every ${cycleProv.settings.workoutReminderInterval} Days"
                                    : "Protocol Offline",
                                value: workoutReminders,
                                onChanged: (val) => cycleProv.updateSettings(cycleProv.settings.copyWith(workoutRemindersEnabled: val)),
                                isLargeScreen: isLargeScreen,
                              ),
                              SizedBox(height: isLargeScreen ? 24.0 : 24.h),

                              // 3. HYDRATION SIGNALS
                              _buildSectionHeader("HYDRATION SYSTEM", isCompact, isLargeScreen),
                              _buildSignalTile(
                                icon: Icons.water_drop_rounded,
                                title: "SYSTEMIC HYDRATION",
                                subtitle: waterReminders ? "Active Monitoring Protocol" : "Protocol Offline",
                                value: waterReminders,
                                onChanged: (val) => hydProv.updateSettings(hydProv.settings.copyWith(remindersEnabled: val)),
                                isLargeScreen: isLargeScreen,
                              ),
                              SizedBox(height: isLargeScreen ? 24.0 : 24.h),

                              // 4. NUTRITION SIGNALS
                              if (activeMeals.isNotEmpty) ...[
                                _buildSectionHeader("NUTRITION LEDGER", isCompact, isLargeScreen),
                                ...activeMeals.map((m) => _buildSignalTile(
                                  icon: Icons.restaurant_rounded,
                                  title: m.name.toUpperCase(),
                                  subtitle: m.notificationsEnabled ? "Scheduled Meal Entry" : "Schedule Paused",
                                  value: m.notificationsEnabled,
                                  onChanged: (val) => calProv.updateSavedMeal(m.copyWith(notificationsEnabled: val)),
                                  isLargeScreen: isLargeScreen,
                                )),
                                SizedBox(height: isLargeScreen ? 24.0 : 24.h),
                              ],

                              SizedBox(height: isLargeScreen ? 40.0 : 40.h),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
  }

  // ─── UI COMPONENTS ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, bool isCompact, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLargeScreen ? 12.0 : 12.h, 
        left: isLargeScreen ? 4.0 : 4.w
      ),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.crimson, 
          fontWeight: FontWeight.w500, 
          letterSpacing: 1.5,
          fontSize: isLargeScreen ? 11.0 : null,
        ),
      ),
    );
  }

  Widget _buildSignalTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isLargeScreen,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isLargeScreen ? 12.0 : 12.h),
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isLargeScreen ? 12.0 : 16.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isLargeScreen ? 10.0 : 10.r),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.03), 
              borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r)
            ),
            child: Icon(icon, color: AppColors.white, size: isLargeScreen ? 20.0 : 20.r),
          ),
          SizedBox(width: isLargeScreen ? 16.0 : 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.white, 
                  fontWeight: FontWeight.w500,
                  fontSize: isLargeScreen ? 12.0 : null,
                )),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary, 
                  fontSize: isLargeScreen ? 10.0 : 10.sp, 
                  letterSpacing: 0
                )),
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
