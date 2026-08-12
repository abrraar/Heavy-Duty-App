import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/auth/provider/auth_provider.dart';
import 'package:heavy_duty/features/settings/notification_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Unit States
  bool _useMetricWeight = true; // KG vs LBS
  bool _useMetricDistance = true; // CM vs INCH
  bool _useMetricVolume = true; // ML vs OZ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: null,
      // SafeArea prevents overlap with phone notch/camera
      body: SafeArea(
        child: Column(
          children: [
            // Heavy Duty Header Protocol
            Padding(
              padding: EdgeInsets.only(
                top: 8.h,
                left: 8.w,
                right: 8.w,
                bottom: 8.h,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: AppColors.white,
                      ),
                      // Standardized to use GoRouter pop
                      onPressed: () => context.pop(),
                    ),
                    Expanded(
                      child: Text(
                        "SETTINGS",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Opacity(
                      opacity: 0,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded),
                        onPressed: null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16.h),

                    _buildSectionHeader("UNITS & MEASURES"),

                    _buildSettingTile(
                      icon: Icons.fitness_center_rounded,
                      title: _useMetricWeight
                          ? "WEIGHT: KILOGRAMS (KG)"
                          : "WEIGHT: POUNDS (LBS)",
                      trailing: Switch(
                        value: _useMetricWeight,
                        activeColor: AppColors.crimson,
                        onChanged: (val) =>
                            setState(() => _useMetricWeight = val),
                      ),
                    ),
                    _buildSettingTile(
                      icon: Icons.straighten_rounded,
                      title: _useMetricDistance
                          ? "DISTANCE: CENTIMETERS (CM)"
                          : "DISTANCE: INCHES (IN)",
                      trailing: Switch(
                        value: _useMetricDistance,
                        activeColor: AppColors.crimson,
                        onChanged: (val) =>
                            setState(() => _useMetricDistance = val),
                      ),
                    ),
                    _buildSettingTile(
                      icon: Icons.water_drop_rounded,
                      title: _useMetricVolume
                          ? "FLUIDS: MILLILITERS (ML)"
                          : "FLUIDS: OUNCES (OZ)",
                      trailing: Switch(
                        value: _useMetricVolume,
                        activeColor: AppColors.crimson,
                        onChanged: (val) =>
                            setState(() => _useMetricVolume = val),
                      ),
                    ),

                    SizedBox(height: 32.h),
                    _buildSectionHeader("ACCOUNT & PREFERENCES"),

                    _buildSettingTile(
                      icon: Icons.notifications_none_rounded,
                      title: "PUSH NOTIFICATIONS",
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const NotificationSettingsScreen(),
                          ),
                        );
                      },
                    ),

                    _buildSettingTile(
                      icon: Icons.security_rounded,
                      title: "PRIVACY & SECURITY",
                      onTap: () {},
                    ),

                    SizedBox(height: 32.h),
                    _buildSectionHeader("SYSTEM"),
                    _buildSettingTile(
                      icon: Icons.cloud_upload_outlined,
                      title: "BACKUP & SYNC",
                      onTap: () {},
                    ),
                    _buildSettingTile(
                      icon: Icons.info_outline_rounded,
                      title: "VERSION 1.0.4",
                      trailing: Text(
                        "UP TO DATE",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.success,
                          letterSpacing: 1.5,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  // ─── REUSABLE SETTINGS COMPONENTS ──────────────────────────────────────────

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

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
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
              child: Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary,
                  size: 14.r,
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        try {
          // Triggers global session clearance via Supabase Auth
          await context.read<AuthProvider>().signOut();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'LOGOUT FAILED: ${e.toString().replaceAll('Exception: ', '')}',
                style: AppTextStyles.bodySmall,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 16.h),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Text(
            "LOGOUT",
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.crimson,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }
}
