import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/navigation/app_routes.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Unit States (These should eventually come from a GlobalSettingsProvider)
  bool _useMetricWeight = true; 
  bool _useMetricVolume = true; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ───────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        "SYSTEM SETTINGS",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Opacity(opacity: 0, child: IconButton(icon: Icon(Icons.info), onPressed: null)),
                  ],
                ),
              ),
            ),

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
                      subtitle: "Inventory alerts and stack defaults",
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
                    _buildToggleTile(
                      icon: Icons.fitness_center_rounded,
                      title: "WEIGHT UNIT",
                      valueText: _useMetricWeight ? "METRIC (KG)" : "IMPERIAL (LBS)",
                      value: _useMetricWeight,
                      onChanged: (v) => setState(() => _useMetricWeight = v),
                    ),
                    _buildToggleTile(
                      icon: Icons.local_drink_rounded,
                      title: "FLUID UNIT",
                      valueText: _useMetricVolume ? "METRIC (ML)" : "IMPERIAL (OZ)",
                      value: _useMetricVolume,
                      onChanged: (v) => setState(() => _useMetricVolume = v),
                    ),

                    SizedBox(height: 24.h),
                    _buildSectionHeader("SYSTEM"),
                    _buildSettingTile(
                      icon: Icons.cloud_sync_rounded,
                      title: "BACKUP & CLOUD SYNC",
                      subtitle: "Force database synchronization",
                      onTap: () {},
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

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String valueText,
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
                Text(valueText, style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontSize: 10.sp, fontWeight: FontWeight.w900)),
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
            "TERMINATE SESSION (LOGOUT)",
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.crimson, fontWeight: FontWeight.w900, letterSpacing: 2),
          ),
        ),
      ),
    );
  }
}
