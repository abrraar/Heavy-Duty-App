import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/core/widgets/elite_settings_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:heavy_duty/core/widgets/elite_snackbar.dart';
import '../tracker/calorie/provider/calorie_provider.dart';

class CalorieSettingsScreen extends StatefulWidget {
  const CalorieSettingsScreen({super.key});

  @override
  State<CalorieSettingsScreen> createState() => _CalorieSettingsScreenState();
}

class _CalorieSettingsScreenState extends State<CalorieSettingsScreen> {
  late TextEditingController _goalController;
  late TextEditingController _proteinController;
  late TextEditingController _carbController;
  late TextEditingController _fatController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<CalorieProvider>();
    _goalController = TextEditingController(text: provider.settings.dailyCalorieGoal.toString());
    _proteinController = TextEditingController(text: provider.settings.proteinPercent.toString());
    _carbController = TextEditingController(text: provider.settings.carbPercent.toString());
    _fatController = TextEditingController(text: provider.settings.fatPercent.toString());
  }

  @override
  void dispose() {
    _goalController.dispose();
    _proteinController.dispose();
    _carbController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _validateAndSaveRatios(String type, String value) {
    if (value.isEmpty) return;
    
    final provider = context.read<CalorieProvider>();
    final currentSettings = provider.settings;
    int? newVal = int.tryParse(value);
    if (newVal == null) return;

    int p = type == 'p' ? newVal : currentSettings.proteinPercent;
    int c = type == 'c' ? newVal : currentSettings.carbPercent;
    int f = type == 'f' ? newVal : currentSettings.fatPercent;

    if (p + c + f > 100) {
      EliteSnackbar.show(context, "TOTAL RATIO CANNOT EXCEED 100%", isError: true);
      
      // Revert the text in the controller immediately
      setState(() {
        if (type == 'p') _proteinController.text = currentSettings.proteinPercent.toString();
        if (type == 'c') _carbController.text = currentSettings.carbPercent.toString();
        if (type == 'f') _fatController.text = currentSettings.fatPercent.toString();
      });
      return;
    }

    provider.updateSettings(currentSettings.copyWith(
      proteinPercent: p,
      carbPercent: c,
      fatPercent: f,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CalorieProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                const EliteSettingsAppBar(title: "CALORIE SETTINGS"),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 16.h),
                        
                        _buildSectionHeader("NUTRITIONAL TARGETS"),
                        
                        _buildSettingCard(
                          title: "DAILY CALORIE GOAL",
                          subtitle: "TOTAL ENERGY INTAKE TARGET",
                          trailing: _buildSmallTextField(
                            controller: _goalController,
                            suffix: "KCAL",
                            maxLength: 5,
                            onChanged: (val) {
                              int? goal = int.tryParse(val);
                              if (goal != null) {
                                provider.updateSettings(settings.copyWith(dailyCalorieGoal: goal));
                              }
                            },
                          ),
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader("MACRO RATIOS (%)"),

                        _buildSettingCard(
                          title: "PROTEIN TARGET",
                          subtitle: "PERCENTAGE OF TOTAL CALORIES",
                          trailing: _buildSmallTextField(
                            controller: _proteinController,
                            suffix: "%",
                            maxLength: 3,
                            onChanged: (val) => _validateAndSaveRatios('p', val),
                          ),
                        ),

                        _buildSettingCard(
                          title: "CARBOHYDRATE TARGET",
                          subtitle: "PERCENTAGE OF TOTAL CALORIES",
                          trailing: _buildSmallTextField(
                            controller: _carbController,
                            suffix: "%",
                            maxLength: 3,
                            onChanged: (val) => _validateAndSaveRatios('c', val),
                          ),
                        ),

                        _buildSettingCard(
                          title: "FAT TARGET",
                          subtitle: "PERCENTAGE OF TOTAL CALORIES",
                          trailing: _buildSmallTextField(
                            controller: _fatController,
                            suffix: "%",
                            maxLength: 3,
                            onChanged: (val) => _validateAndSaveRatios('f', val),
                          ),
                        ),

                        SizedBox(height: 12.h),
                        Center(
                          child: Text(
                            "TOTAL: ${settings.proteinPercent + settings.carbPercent + settings.fatPercent}% / 100%",
                            style: AppTextStyles.labelSmall.copyWith(
                              color: (settings.proteinPercent + settings.carbPercent + settings.fatPercent) == 100 
                                  ? Colors.greenAccent 
                                  : AppColors.crimson,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        SizedBox(height: 32.h),
                        _buildSectionHeader("DISPLAY PREFERENCES"),

                        _buildToggleCard(
                          title: "TRACK MACRONUTRIENTS",
                          subtitle: "SHOW PROTEIN, CARBS, AND FATS",
                          value: settings.trackMacros,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(trackMacros: val));
                          },
                        ),

                        _buildToggleCard(
                          title: "SHOW REMAINING",
                          subtitle: "DISPLAY CALORIES LEFT FOR THE DAY",
                          value: settings.showRemaining,
                          onChanged: (val) {
                            provider.updateSettings(settings.copyWith(showRemaining: val));
                          },
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

  Widget _buildSmallTextField({
    required TextEditingController controller,
    required String suffix,
    required int maxLength,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      width: 100.w,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        maxLength: maxLength,
        style: AppTextStyles.labelSmall.copyWith(fontSize: 12.sp, color: AppColors.white, fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: "",
          border: InputBorder.none,
          suffixText: suffix,
          suffixStyle: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.textSecondary),
        ),
        onChanged: onChanged,
      ),
    );
  }

  // ─── REUSABLE COMPONENTS (Matches Notification/Sleep Settings) ─────────────

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

  Widget _buildSettingCard({required String title, required String subtitle, required Widget trailing}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp, letterSpacing: 0)),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _buildToggleCard({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10.sp, letterSpacing: 0)),
              ],
            ),
          ),
          Switch(value: value, activeThumbColor: AppColors.crimson, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildSmallDropdown<T>({required T value, required List<T> items, required String suffix, required Function(T?) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        icon: Icon(Icons.keyboard_arrow_down, color: AppColors.crimson, size: 16.r),
        items: items.map((T val) {
          return DropdownMenuItem<T>(
            value: val,
            child: Text("$val $suffix", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.white)),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}