import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/settings/body_comp_settings_screen.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/provider/cycle_provider.dart';
import 'package:heavy_duty/features/tracker/hydration/provider/hydration_provider.dart';
import 'package:heavy_duty/features/tracker/body_composition/provider/body_comp_provider.dart';
import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';
import 'package:heavy_duty/features/tracker/body_composition/model/body_comp_settings.dart';
import 'package:heavy_duty/features/tracker/sleep/provider/sleep_provider.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:heavy_duty/features/exercise/provider/exercise_provider.dart';
import 'package:heavy_duty/features/affirmation/provider/affirmation_provider.dart';
import 'package:heavy_duty/core/providers/ui_provider.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';

import '../tracker/hydration/model/hydration_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;

  Future<void> _handleGlobalSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    try {
      // FORCE SYNC: Simultaneously trigger refresh/sync for all core modules
        await Future.wait<void>([
          context.read<CycleProvider>().forceRefresh(),
          context.read<HydrationProvider>().forceRefresh(),
          context.read<BodyCompProvider>().forceRefresh(),
          context.read<SleepProvider>().forceRefresh(),
          context.read<CalorieProvider>().forceRefresh(),
          context.read<SupplementProvider>().forceRefresh(),
          context.read<ExerciseProvider>().forceRefresh(),
          context.read<AffirmationProvider>().forceRefresh(),
          context.read<UiProvider>().forceRefresh(),
          context.read<AuthProvider>().refreshEmails(),
        ]);
      
      if (mounted) {
        EliteSnackbar.show(context, "CLOUD SYNC SUCCESSFUL");
      }
    } catch (e) {
      if (mounted) {
        EliteSnackbar.show(context, "SYNC ERROR: ${e.toString().toUpperCase()}", isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<CycleProvider, HydrationProvider, BodyCompProvider, SleepProvider>(
      builder: (context, cycleProv, hydProv, bodyProv, sleepProv, _) {
        final bool useMetricWeight = cycleProv.settings.weightUnit == WeightUnit.kgs;
        final bool useMetricVolume = hydProv.settings.unit == HydrationUnit.ml;
        final bool bodyUseMetricWeight = bodyProv.settings.weightUnit == WeightUnit.kgs;
        final bool bodyUseMetricHeight = bodyProv.settings.heightUnit == HeightUnit.cm;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const EliteSettingsAppBar(title: "SYSTEM SETTINGS"),

                // ── CONTENT ──────────────────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader("ACCOUNT & SECURITY"),
                        _buildSettingTile(
                          icon: Icons.person_outline_rounded,
                          title: "CHANGE USERNAME",
                          subtitle: "Update your unique elite tag",
                          onTap: () => context.push(AppRoutes.changeUsername),
                        ),
                        _buildSettingTile(
                          icon: Icons.lock_outline_rounded,
                          title: "CHANGE PASSWORD",
                          subtitle: "Update your elite security key",
                          onTap: () => context.push(AppRoutes.changePassword),
                        ),
                        _buildSettingTile(
                          icon: Icons.alternate_email_rounded,
                          title: "MANAGE EMAILS",
                          subtitle: "Primary and recovery addresses",
                          onTap: () => context.push(AppRoutes.manageEmail),
                        ),
                        _buildSettingTile(
                          icon: Icons.notifications_active_outlined,
                          title: "PUSH NOTIFICATIONS",
                          subtitle: "System alerts and workout reminders",
                          onTap: () => context.push(AppRoutes.settingsNotifications),
                        ),

                        SizedBox(height: 24.h),
                        _buildSectionHeader("MODULE CONFIGURATIONS"),
                        _buildSettingTile(
                          icon: Icons.bolt_rounded,
                          title: "TRAINING PROTOCOLS",
                          subtitle: "Cycle evolution and session settings",
                          onTap: () => context.push(AppRoutes.settingsCycle),
                        ),
                        _buildSettingTile(
                          icon: Icons.restaurant_rounded,
                          title: "NUTRITION LEDGER",
                          subtitle: "Calorie goals and macro targets",
                          onTap: () => context.push(AppRoutes.settingsCalorie),
                        ),
                        _buildSettingTile(
                          icon: Icons.water_drop_rounded,
                          title: "HYDRATION SYSTEM",
                          subtitle: "Daily intake and quick-add values",
                          onTap: () => context.push(AppRoutes.settingsHydration),
                        ),
                        _buildSettingTile(
                          icon: Icons.layers_rounded,
                          title: "SUPPLEMENT STACKS",
                          subtitle: "Inventory alerts and display preferences",
                          onTap: () => context.push(AppRoutes.settingsSupplement),
                        ),
                        _buildSettingTile(
                          icon: Icons.bedtime_rounded,
                          title: "RECOVERY & SLEEP",
                          subtitle: "Alarms and performance metrics",
                          onTap: () => context.push(AppRoutes.settingsSleep),
                        ),
                        _buildSettingTile(
                          icon: Icons.analytics_outlined,
                          title: "BODY COMPOSITION",
                          subtitle: "Visual trend and target tracking",
                          onTap: () => context.push(AppRoutes.settingsBodyComp),
                        ),

                        SizedBox(height: 24.h),
                        _buildSectionHeader("GLOBAL PREFERENCES"),
                        EliteUnitToggleCard(
                          title: "Exercise Weight Unit",
                          subtitle: "Switch between LBS and KGS for HIT",
                          options: const ["LBS", "KGS"],
                          selectedIndex: useMetricWeight ? 1 : 0,
                          onSelected: (v) {
                            cycleProv.updateSettings(cycleProv.settings.copyWith(
                              weightUnit: v == 1 ? WeightUnit.kgs : WeightUnit.lbs,
                            ));
                          },
                        ),
                        SizedBox(height: 12.h),
                        EliteUnitToggleCard(
                          title: "Body Comp Weight Unit",
                          subtitle: "Switch between LBS and KGS for Body Comp",
                          options: const ["LBS", "KGS"],
                          selectedIndex: bodyUseMetricWeight ? 1 : 0,
                          onSelected: (v) {
                            bodyProv.updateSettings(bodyProv.settings.copyWith(
                              weightUnit: v == 1 ? WeightUnit.kgs : WeightUnit.lbs,
                            ));
                          },
                        ),
                        SizedBox(height: 12.h),
                        EliteUnitToggleCard(
                          title: "Height Unit",
                          subtitle: "Switch between FT and CM",
                          options: const ["FT", "CM"],
                          selectedIndex: bodyUseMetricHeight ? 1 : 0,
                          onSelected: (v) {
                            bodyProv.updateSettings(bodyProv.settings.copyWith(
                              heightUnit: v == 1 ? HeightUnit.cm : HeightUnit.ftIn,
                            ));
                          },
                        ),
                        SizedBox(height: 12.h),
                        EliteUnitToggleCard(
                          title: "Hydration Unit",
                          subtitle: "Switch between OZ and ML",
                          options: const ["OZ", "ML"],
                          selectedIndex: useMetricVolume ? 1 : 0,
                          selectedColor: Colors.blueAccent,
                          onSelected: (v) {
                            hydProv.updateSettings(hydProv.settings.copyWith(
                              unit: v == 1 ? HydrationUnit.ml : HydrationUnit.oz,
                            ));
                          },
                        ),
                        SizedBox(height: 12.h),
                        EliteUnitToggleCard(
                          title: "Time Format",
                          subtitle: "Switch between 12H and 24H clock",
                          options: const ["12H", "24H"],
                          selectedIndex: sleepProv.settings.use24HourClock ? 1 : 0,
                          selectedColor: AppColors.crimson,
                          onSelected: (v) {
                            sleepProv.updateSettings(sleepProv.settings.copyWith(
                              use24HourClock: v == 1,
                            ));
                          },
                        ),

                        SizedBox(height: 24.h),
                        _buildSectionHeader("SYSTEM"),
                        _buildSettingTile(
                          icon: Icons.cloud_sync_rounded,
                          title: "BACKUP & CLOUD SYNC",
                          subtitle: _isSyncing ? "SYNCHRONIZING..." : "Force database synchronization",
                          onTap: _handleGlobalSync,
                          trailing: _isSyncing 
                            ? SizedBox(
                                width: 12.r, 
                                height: 12.r, 
                                child: const CircularProgressIndicator(color: AppColors.crimson, strokeWidth: 2)
                              ) 
                            : null,
                        ),
                        _buildSettingTile(
                          icon: Icons.info_outline_rounded,
                          title: "HEAVY DUTY v1.0.5",
                          subtitle: "All systems operational",
                          trailing: Text("UP TO DATE", style: AppTextStyles.labelSmall.copyWith(color: AppColors.success, fontSize: 9.sp, fontWeight: FontWeight.bold)),
                        ),

                        SizedBox(height: 48.h),
                        _buildLogoutButton(),
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

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  if (subtitle != null)
                    Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: 12.r),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        try {
          await context.read<AuthProvider>().signOut();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('LOGOUT FAILED: $e'), backgroundColor: AppColors.error));
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Center(
          child: Text(
            "LOGOUT",
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
