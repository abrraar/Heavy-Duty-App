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
import 'package:heavy_duty/core/providers/update_provider.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';

import '../profile/change_password_screen.dart';
import '../profile/change_username_screen.dart';
import '../profile/manage_email_screen.dart';
import 'body_comp_settings_screen.dart';
import 'calorie_settings_screen.dart';
import 'cycle_tracking_settings_screen.dart';
import 'hydration_settings_screen.dart';
import 'notification_screen.dart';
import 'sleep_settings_screen.dart';
import 'supplement_settings_screen.dart';
import '../tracker/hydration/model/hydration_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSyncing = false;
  String? _selectedRoute;

  void _navigateTo(String route, bool isWideLandscape) {
    if (isWideLandscape) {
      setState(() => _selectedRoute = route);
    } else {
      context.push(route);
    }
  }

  Widget _buildDetailView(String? route, bool isCompact) {
    if (route == null) {
      return Center(
        child: Text(
          "SELECT AN OPTION TO VIEW",
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.textSecondary.withValues(alpha: 0.3), 
            letterSpacing: 2,
            fontSize: isCompact ? 12.sp : 18.0,
          ),
        ),
      );
    }

    switch (route) {
      case AppRoutes.changeUsername: return const ChangeUsernameScreen();
      case AppRoutes.changePassword: return const ChangePasswordScreen();
      case AppRoutes.manageEmail: return const ManageEmailScreen();
      case AppRoutes.settingsNotifications: return const NotificationSettingsScreen();
      case AppRoutes.settingsCycle: return const CycleTrackingSettingsScreen();
      case AppRoutes.settingsCalorie: return const CalorieSettingsScreen();
      case AppRoutes.settingsHydration: return const HydrationSettingsScreen();
      case AppRoutes.settingsSupplement: return const SupplementSettingsScreen();
      case AppRoutes.settingsSleep: return const SleepSettingsScreen();
      case AppRoutes.settingsBodyComp: return const BodyCompConfigScreen();
      default: return const SizedBox.shrink();
    }
  }

  Future<void> _handleGlobalSync() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    try {
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
          context.read<UpdateProvider>().checkForUpdates(showNotification: false),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600;
                final bool isWideLandscape = !isCompact && MediaQuery.orientationOf(context) == Orientation.landscape;

                return Column(
                  children: [
                    EliteSettingsAppBar(title: "SYSTEM SETTINGS", isCompact: isCompact),

                    // ── CONTENT ──────────────────────────────────────────────────────
                    Expanded(
                      child: isWideLandscape
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ── MASTER PANE (LEFT) ──────────────────────────────
                                SizedBox(
                                  width: 380,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border(right: BorderSide(color: AppColors.white.withValues(alpha: 0.05))),
                                    ),
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                                      physics: const BouncingScrollPhysics(),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildMasterList(context, cycleProv, hydProv, bodyProv, sleepProv, isCompact, isWideLandscape),
                                          const SizedBox(height: 100.0),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // ── DETAIL PANE (RIGHT) ─────────────────────────────
                                Expanded(
                                  child: Container(
                                    color: AppColors.background,
                                    child: _buildDetailView(_selectedRoute, isCompact),
                                  ),
                                ),
                              ],
                            )
                          : SingleChildScrollView(
                              padding: EdgeInsets.symmetric(horizontal: isCompact ? 24.w : 24.0, vertical: 20.0),
                              physics: const BouncingScrollPhysics(),
                              child: _buildMasterList(context, cycleProv, hydProv, bodyProv, sleepProv, isCompact, isWideLandscape),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMasterList(
    BuildContext context, 
    CycleProvider cycleProv, 
    HydrationProvider hydProv, 
    BodyCompProvider bodyProv, 
    SleepProvider sleepProv, 
    bool isCompact, 
    bool isWideLandscape
  ) {
    final bool useMetricWeight = cycleProv.settings.weightUnit == WeightUnit.kgs;
    final bool useMetricVolume = hydProv.settings.unit == HydrationUnit.ml;
    final bool bodyUseMetricWeight = bodyProv.settings.weightUnit == WeightUnit.kgs;
    final bool bodyUseMetricHeight = bodyProv.settings.heightUnit == HeightUnit.cm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("ACCOUNT & SECURITY", isCompact),
        _buildSettingTile(
          icon: Icons.person_outline_rounded,
          title: "CHANGE USERNAME",
          subtitle: "Update your unique elite tag",
          onTap: () => _navigateTo(AppRoutes.changeUsername, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.changeUsername,
        ),
        _buildSettingTile(
          icon: Icons.lock_outline_rounded,
          title: "CHANGE PASSWORD",
          subtitle: "Update your elite security key",
          onTap: () => _navigateTo(AppRoutes.changePassword, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.changePassword,
        ),
        _buildSettingTile(
          icon: Icons.alternate_email_rounded,
          title: "MANAGE EMAILS",
          subtitle: "Primary and recovery addresses",
          onTap: () => _navigateTo(AppRoutes.manageEmail, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.manageEmail,
        ),
        _buildSettingTile(
          icon: Icons.notifications_active_outlined,
          title: "PUSH NOTIFICATIONS",
          subtitle: "System alerts and workout reminders",
          onTap: () => _navigateTo(AppRoutes.settingsNotifications, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsNotifications,
        ),

        const SizedBox(height: 32.0),
        _buildSectionHeader("MODULE CONFIGURATIONS", isCompact),
        _buildSettingTile(
          icon: Icons.bolt_rounded,
          title: "TRAINING PROTOCOLS",
          subtitle: "Cycle evolution and session settings",
          onTap: () => _navigateTo(AppRoutes.settingsCycle, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsCycle,
        ),
        _buildSettingTile(
          icon: Icons.restaurant_rounded,
          title: "NUTRITION LEDGER",
          subtitle: "Calorie goals and macro targets",
          onTap: () => _navigateTo(AppRoutes.settingsCalorie, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsCalorie,
        ),
        _buildSettingTile(
          icon: Icons.water_drop_rounded,
          title: "HYDRATION SYSTEM",
          subtitle: "Daily intake and quick-add values",
          onTap: () => _navigateTo(AppRoutes.settingsHydration, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsHydration,
        ),
        _buildSettingTile(
          icon: Icons.layers_rounded,
          title: "SUPPLEMENT STACKS",
          subtitle: "Inventory alerts and display preferences",
          onTap: () => _navigateTo(AppRoutes.settingsSupplement, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsSupplement,
        ),
        _buildSettingTile(
          icon: Icons.bedtime_rounded,
          title: "RECOVERY & SLEEP",
          subtitle: "Alarms and performance metrics",
          onTap: () => _navigateTo(AppRoutes.settingsSleep, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsSleep,
        ),
        _buildSettingTile(
          icon: Icons.analytics_outlined,
          title: "BODY COMPOSITION",
          subtitle: "Visual trend and target tracking",
          onTap: () => _navigateTo(AppRoutes.settingsBodyComp, isWideLandscape),
          isCompact: isCompact,
          isSelected: isWideLandscape && _selectedRoute == AppRoutes.settingsBodyComp,
        ),

        const SizedBox(height: 32.0),
        _buildSectionHeader("GLOBAL PREFERENCES", isCompact),
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
        const SizedBox(height: 12.0),
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
        const SizedBox(height: 12.0),
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
        const SizedBox(height: 12.0),
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
        const SizedBox(height: 12.0),
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

        const SizedBox(height: 32.0),
        _buildSectionHeader("SYSTEM", isCompact),
        _buildSettingTile(
          icon: Icons.cloud_sync_rounded,
          title: "BACKUP & CLOUD SYNC",
          subtitle: _isSyncing ? "SYNCHRONIZING..." : "Force database synchronization",
          onTap: _handleGlobalSync,
          isCompact: isCompact,
          trailing: _isSyncing
            ? const SizedBox(
                width: 12.0,
                height: 12.0,
                child: CircularProgressIndicator(color: AppColors.crimson, strokeWidth: 2)
              )
            : null,
        ),
        Consumer<UpdateProvider>(
          builder: (context, updateProv, _) {
            final bool update = updateProv.isUpdateAvailable;
            return _buildSettingTile(
              icon: Icons.info_outline_rounded,
              title: "HEAVY DUTY v${updateProv.currentVersion}",
              subtitle: update ? "New version available. Tap to upgrade." : "All systems operational",
              onTap: update ? updateProv.launchUpdateUrl : null,
              isCompact: isCompact,
              trailing: update
                ? Text(
                    "NOT UP TO DATE",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.crimson,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  )
                : Text(
                    "UP TO DATE",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.success,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w500
                    ),
                  ),
            );
          },
        ),
        const SizedBox(height: 16.0),
        _buildLogoutButton(isCompact),
      ],
    );
  }

  // ─── UI COMPONENTS ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(bottom: isCompact ? 12.h : 12.0, left: isCompact ? 4.w : 4.0),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.crimson, 
          fontWeight: FontWeight.w500, 
          letterSpacing: 1.5,
          fontSize: isCompact ? null : 11.0,
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isCompact,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: isCompact ? 12.h : 12.0),
        padding: EdgeInsets.all(isCompact ? 16.r : 16.0),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.crimson.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
          border: Border.all(
            color: isSelected ? AppColors.crimson.withValues(alpha: 0.5) : AppColors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isCompact ? 10.r : 10.0),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.crimson.withValues(alpha: 0.2) : AppColors.white.withValues(alpha: 0.03), 
                borderRadius: BorderRadius.circular(isCompact ? 12.r : 10.0)
              ),
              child: Icon(icon, color: isSelected ? AppColors.crimson : AppColors.white, size: isCompact ? 20.r : 20.0),
            ),
            SizedBox(width: isCompact ? 16.w : 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelSmall.copyWith(
                    color: Colors.white, 
                    fontWeight: FontWeight.w500,
                    fontSize: isCompact ? null : 12.0,
                  )),
                  if (subtitle != null)
                    Text(subtitle, style: AppTextStyles.labelSmall.copyWith(
                      color: isSelected ? AppColors.white.withValues(alpha: 0.7) : AppColors.textSecondary, 
                      fontSize: isCompact ? 10.sp : 10.0
                    )),
                ],
              ),
            ),
            if (trailing != null) 
              trailing 
            else if (!isSelected)
              Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary.withValues(alpha: 0.3), size: isCompact ? 12.r : 12.0),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isCompact) {
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
        padding: EdgeInsets.symmetric(vertical: isCompact ? 16.h : 16.0),
        decoration: BoxDecoration(
          color: AppColors.crimson.withValues(alpha: 0.1),
          border: Border.all(color: AppColors.crimson.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(isCompact ? 16.r : 12.0),
        ),
        child: Center(
          child: Text(
            "LOGOUT",
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.crimson, 
              fontWeight: FontWeight.w500, 
              letterSpacing: 2,
              fontSize: isCompact ? null : 13.0,
            ),
          ),
        ),
      ),
    );
  }
}
