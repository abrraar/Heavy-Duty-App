import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../provider/affirmation_provider.dart';
import '../model/affirmation_settings.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';

class AffirmationSettingsSheet extends StatefulWidget {
  const AffirmationSettingsSheet({super.key});

  @override
  State<AffirmationSettingsSheet> createState() => _AffirmationSettingsSheetState();

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
      ),
      builder: (context) => const AffirmationSettingsSheet(),
    );
  }
}

class _AffirmationSettingsSheetState extends State<AffirmationSettingsSheet> {
  final List<String> _units = ['MINUTES', 'HOURS', 'DAYS'];
  late FixedExtentScrollController _valueController;
  late FixedExtentScrollController _unitController;
  
  int _selectedValue = 1;
  int _selectedUnitIdx = 0;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AffirmationProvider>().settings;
    _parseMinutes(settings.rotationMinutes);
    _valueController = FixedExtentScrollController(initialItem: _selectedValue - 1);
    _unitController = FixedExtentScrollController(initialItem: _selectedUnitIdx);
    
    _valueController.addListener(() => setState(() {}));
    _unitController.addListener(() => setState(() {}));
  }

  void _parseMinutes(int totalMins) {
    if (totalMins >= 1440 && totalMins % 1440 == 0) {
      _selectedValue = totalMins ~/ 1440;
      _selectedUnitIdx = 2; // DAYS
    } else if (totalMins >= 60 && totalMins % 60 == 0) {
      _selectedValue = totalMins ~/ 60;
      _selectedUnitIdx = 1; // HOURS
    } else {
      _selectedValue = totalMins;
      _selectedUnitIdx = 0; // MINUTES
    }
  }

  void _updateSettings() {
    int multiplier = 1;
    if (_selectedUnitIdx == 1) multiplier = 60;
    if (_selectedUnitIdx == 2) multiplier = 1440;
    
    final totalMins = _selectedValue * multiplier;
    context.read<AffirmationProvider>().updateSettings(
      context.read<AffirmationProvider>().settings.copyWith(rotationMinutes: totalMins)
    );
  }

  @override
  void dispose() {
    _valueController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AffirmationProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;

        return Padding(
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, MediaQuery.of(context).viewInsets.bottom + 40.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text("ROTATION SETTINGS", style: AppTextStyles.h3),
              SizedBox(height: 32.h),

              _buildSectionLabel("DISPLAY CONTENT"),
              Row(
                children: [
                  _buildToggleChip(
                    label: "SYSTEM",
                    isSelected: settings.showSystem,
                    // Prevent turning off if it's the only one active
                    isEnabled: settings.showCustom, 
                    onTap: () => provider.updateSettings(settings.copyWith(showSystem: !settings.showSystem)),
                  ),
                  SizedBox(width: 12.w),
                  _buildToggleChip(
                    label: "CUSTOM",
                    isSelected: settings.showCustom,
                    // Prevent turning off if it's the only one active OR if no custom affs exist
                    isEnabled: settings.showSystem && provider.allCustomAffirmations.isNotEmpty,
                    onTap: () => provider.updateSettings(settings.copyWith(showCustom: !settings.showCustom)),
                  ),
                ],
              ),
              SizedBox(height: 32.h),

              _buildSectionLabel("ROTATION FREQUENCY"),
              Container(
                height: 150.h,
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _valueController,
                        itemExtent: 40.h,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          _selectedValue = index + 1;
                          _updateSettings();
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: 60,
                          builder: (context, index) {
                            double opacity = 0.2;
                            if (_valueController.hasClients) {
                              final double itemExtent = 40.h;
                              final double currentPage = _valueController.offset / itemExtent;
                              final double diff = (currentPage - index).abs();
                              opacity = (1.0 - (diff * 0.7)).clamp(0.2, 1.0);
                            } else if (index == _selectedValue - 1) {
                              opacity = 1.0;
                            }
                            return Center(
                              child: Opacity(
                                opacity: opacity,
                                child: Text(
                                  "${index + 1}",
                                  style: AppTextStyles.h3.copyWith(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListWheelScrollView.useDelegate(
                        controller: _unitController,
                        itemExtent: 40.h,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          _selectedUnitIdx = index;
                          _updateSettings();
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          childCount: _units.length,
                          builder: (context, index) {
                            double opacity = 0.2;
                            if (_unitController.hasClients) {
                              final double itemExtent = 40.h;
                              final double currentPage = _unitController.offset / itemExtent;
                              final double diff = (currentPage - index).abs();
                              opacity = (1.0 - (diff * 0.7)).clamp(0.2, 1.0);
                            } else if (index == _selectedUnitIdx) {
                              opacity = 1.0;
                            }
                            return Center(
                              child: Opacity(
                                opacity: opacity,
                                child: Text(
                                  _units[index],
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: AppColors.crimson,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),

              _buildSectionLabel("ROTATION MODE"),
              Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: [
                  _buildModeChip("random", "RANDOM", settings, provider),
                  _buildModeChip("alternative", "ALTERNATIVE", settings, provider, 
                    isEnabled: settings.showSystem && settings.showCustom),
                  _buildModeChip("continuous", "CONTINUOUS", settings, provider),
                ],
              ),
              SizedBox(height: 32.h),

              _buildSectionLabel("ORDER BY"),
              Opacity(
                opacity: settings.rotationMode == 'random' ? 0.3 : 1.0,
                child: IgnorePointer(
                  ignoring: settings.rotationMode == 'random',
                  child: Row(
                    children: [
                      _buildOrderChip("asc", "ASCENDING", settings, provider),
                      SizedBox(width: 12.w),
                      _buildOrderChip("desc", "DESCENDING", settings, provider),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 40.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.crimson,
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "SAVE & CLOSE",
                    style: AppTextStyles.labelMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Remove unused methods
  /*
  String _getDisplayContentLabel(AffirmationSettings settings) { ... }
  */

  Widget _buildModeChip(String mode, String label, AffirmationSettings settings, AffirmationProvider provider, {bool isEnabled = true}) {
    final isSelected = settings.rotationMode == mode;
    return Opacity(
      opacity: isEnabled ? 1.0 : 0.3,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: ChoiceChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) provider.updateSettings(settings.copyWith(rotationMode: mode));
          },
          selectedColor: AppColors.crimson,
          backgroundColor: AppColors.surfaceLight.withOpacity(0.1),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderChip(String direction, String label, AffirmationSettings settings, AffirmationProvider provider) {
    final isSelected = settings.orderDirection == direction;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.updateSettings(settings.copyWith(orderDirection: direction)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected ? AppColors.crimson : AppColors.white.withOpacity(0.1),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: isSelected ? AppColors.crimson : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildToggleChip({required String label, required bool isSelected, required VoidCallback onTap, bool isEnabled = true}) {
    return Expanded(
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.crimson.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: isSelected 
                  ? AppColors.crimson 
                  : (isEnabled ? AppColors.white.withOpacity(0.1) : AppColors.white.withOpacity(0.02)),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.2,
            child: Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? AppColors.crimson : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
