import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:heavy_duty/core/widgets/elite_unit_toggle_card.dart';
import 'package:heavy_duty/core/utils/adaptive_utils.dart';
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
    AdaptiveUtils.showAdaptiveSheet(
      context: context,
      sheetBuilder: (sheetContext, isSideSheet) => HydrationNotificationSheet(isSideSheet: isSideSheet),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = deviceWidth >= 600;

    return Consumer<HydrationProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

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
                      title: "HYDRATION SETTINGS", 
                      isCompact: isCompact,
                      showBackButton: !isWideLandscape,
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: isLargeScreen ? 24.0 : 24.w
                        ),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                                SizedBox(height: isLargeScreen ? 16.0 : 16.h),
                                _buildSectionHeader("GOALS & MEASURES", isLargeScreen),
                                _buildManualInputTile(
                                  icon: Icons.track_changes_rounded,
                                  title: "DAILY GOAL",
                                  subtitle: "YOUR TARGET WATER INTAKE",
                                  controller: _goalController,
                                  suffix: settings.unit == HydrationUnit.ml ? "ML" : "OZ",
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    int? numeric = int.tryParse(val);
                                    if (numeric != null && numeric > 0) {
                                      int mlValue = settings.unit == HydrationUnit.ml ? numeric : provider.ozToMl(numeric.toDouble());
                                      provider.updateSettings(settings.copyWith(dailyGoal: mlValue));
                                    }
                                  },
                                ),
                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                EliteUnitToggleCard(
                                  title: "Hydration Unit",
                                  subtitle: "Switch between ML and OZ",
                                  options: const ["OZ", "ML"],
                                  selectedIndex: settings.unit == HydrationUnit.ml ? 1 : 0,
                                  selectedColor: Colors.blueAccent,
                                  onSelected: (index) {
                                    final HydrationUnit newUnit = index == 1 ? HydrationUnit.ml : HydrationUnit.oz;
                                    int currentGoalMl = settings.dailyGoal;
                                    int currentAddMl = settings.addValue;
                                    int currentMinusMl = settings.minusValue;

                                    if (newUnit == HydrationUnit.ml) { 
                                      _goalController.text = currentGoalMl.toString();
                                      _addController.text = currentAddMl.toString();
                                      _minusController.text = currentMinusMl.toString();
                                    } else { 
                                      _goalController.text = provider.mlToOz(currentGoalMl).toStringAsFixed(0);
                                      _addController.text = provider.mlToOz(currentAddMl).toStringAsFixed(0);
                                      _minusController.text = provider.mlToOz(currentMinusMl).toStringAsFixed(0);
                                    }

                                    provider.updateSettings(settings.copyWith(unit: newUnit));
                                  },
                                ),
                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("QUICK LOG CALIBRATION", isLargeScreen),
                                _buildManualInputTile(
                                  icon: Icons.add_circle_outline_rounded,
                                  title: "POSITIVE (+) INCREMENT",
                                  subtitle: "VALUE FOR THE ADD BUTTON",
                                  controller: _addController,
                                  suffix: settings.unit == HydrationUnit.ml ? "ML" : "OZ",
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    int? numeric = int.tryParse(val);
                                    if (numeric != null && numeric > 0) {
                                      int mlValue = settings.unit == HydrationUnit.ml ? numeric : provider.ozToMl(numeric.toDouble());
                                      provider.updateSettings(settings.copyWith(addValue: mlValue));
                                    }
                                  },
                                ),
                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                _buildManualInputTile(
                                  icon: Icons.remove_circle_outline_rounded,
                                  title: "NEGATIVE (-) INCREMENT",
                                  subtitle: "VALUE FOR THE SUBTRACT BUTTON",
                                  controller: _minusController,
                                  suffix: settings.unit == HydrationUnit.ml ? "ML" : "OZ",
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    int? numeric = int.tryParse(val);
                                    if (numeric != null && numeric > 0) {
                                      int mlValue = settings.unit == HydrationUnit.ml ? numeric : provider.ozToMl(numeric.toDouble());
                                      provider.updateSettings(settings.copyWith(minusValue: mlValue));
                                    }
                                  },
                                ),
                                SizedBox(height: isLargeScreen ? 32.0 : 32.h),
                                _buildSectionHeader("AUTOMATION & DISPLAY", isLargeScreen),
                                _buildToggleCard(
                                  icon: Icons.push_pin_rounded,
                                  title: "PIN TO HOME SCREEN",
                                  subtitle: "SHOW TRACKER ON DASHBOARD",
                                  value: settings.isPinnedToHome,
                                  isLargeScreen: isLargeScreen,
                                  onChanged: (val) {
                                    provider.updateSettings(settings.copyWith(isPinnedToHome: val));
                                  },
                                ),
                                SizedBox(height: isLargeScreen ? 12.0 : 12.h),
                                _buildReminderCard(
                                  title: "INTAKE REMINDERS",
                                  isEnabled: settings.remindersEnabled,
                                  onTap: _openNotifications,
                                  isLargeScreen: isLargeScreen,
                                ),
                                SizedBox(height: isLargeScreen ? 40.0 : 40.h),
                              ],
                            ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, bool isLargeScreen) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLargeScreen ? 12.0 : 12.h, 
        left: isLargeScreen ? 4.0 : 4.w
      ),
      child: Text(
        title,
        style: AppTextStyles.labelSmall.copyWith(
          color: Colors.blueAccent, 
          fontWeight: FontWeight.w500, 
          letterSpacing: 1.5,
          fontSize: isLargeScreen ? 11.0 : null,
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
    required bool isLargeScreen,
    required ValueChanged<String> onChanged
  }) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surface, 
        borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r), 
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05))
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: isLargeScreen ? 22.0 : 22.r),
          SizedBox(width: isLargeScreen ? 16.0 : 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white, 
                  fontWeight: FontWeight.w500,
                  fontSize: isLargeScreen ? 12.0 : null,
                )),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary, 
                  fontSize: isLargeScreen ? 10.0 : 10.sp
                )),
              ],
            ),
          ),
          Container(
            width: isLargeScreen ? 80.0 : 80.w,
            height: isLargeScreen ? 34.0 : 36.h,
            padding: EdgeInsets.symmetric(horizontal: isLargeScreen ? 8.0 : 8.w),
            decoration: BoxDecoration(
              color: AppColors.background, 
              borderRadius: BorderRadius.circular(isLargeScreen ? 6.0 : 8.r)
            ),
            alignment: Alignment.center,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(
                fontWeight: FontWeight.w500, 
                color: Colors.white,
                fontSize: isLargeScreen ? 12.0 : null,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly, 
                LengthLimitingTextInputFormatter(4)
              ],
              decoration: InputDecoration(
                border: InputBorder.none, 
                isDense: true, 
                contentPadding: EdgeInsets.zero,
                suffixText: " $suffix",
                suffixStyle: AppTextStyles.labelSmall.copyWith(
                  fontSize: isLargeScreen ? 9.0 : 8.sp, 
                  color: AppColors.textSecondary
                ),
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
    required bool isLargeScreen,
    required ValueChanged<bool> onChanged
  }) {
    return Container(
      padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.white, size: isLargeScreen ? 22.0 : 22.r),
          SizedBox(width: isLargeScreen ? 16.0 : 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.white, 
                  fontWeight: FontWeight.w500,
                  fontSize: isLargeScreen ? 12.0 : null,
                )),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary, 
                  fontSize: isLargeScreen ? 10.0 : 10.sp
                )),
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

  Widget _buildReminderCard({required String title, required bool isEnabled, required VoidCallback onTap, required bool isLargeScreen}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLargeScreen ? 16.0 : 16.r),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isLargeScreen ? 10.0 : 12.r),
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: isEnabled ? Colors.blueAccent : AppColors.white, size: isLargeScreen ? 22.0 : 22.r),
            SizedBox(width: isLargeScreen ? 16.0 : 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.white, 
                    fontWeight: FontWeight.w500,
                    fontSize: isLargeScreen ? 12.0 : null,
                  )),
                  Text(
                    isEnabled ? "ACTIVE" : "DISABLED",
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isEnabled ? Colors.blueAccent : AppColors.textSecondary,
                      fontSize: isLargeScreen ? 10.0 : 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: isLargeScreen ? 14.0 : 14.r),
          ],
        ),
      ),
    );
  }

}
