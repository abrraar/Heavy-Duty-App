// lib/features/tracker/supplement/widgets/quick_log_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import '../../model/supplement.dart';

class QuickLogSheet extends StatefulWidget {
  final Supplement supplement;
  final Function({
    required bool isPinned,
    required double intakeVal,
    required bool useServingsIntake,
    required double restockVal,
    required bool useServingsRestock,
  })
  onSave;

  const QuickLogSheet({
    super.key,
    required this.supplement,
    required this.onSave,
  });

  @override
  State<QuickLogSheet> createState() => _QuickLogSheetState();
}

class _QuickLogSheetState extends State<QuickLogSheet> {
  late bool recordEnabled;
  late bool restockEnabled;
  late bool useServingsIntake;
  late bool useServingsRestock;

  final TextEditingController intakeController = TextEditingController();
  final TextEditingController restockController = TextEditingController();

  @override
  void initState() {
    super.initState();
    useServingsIntake = widget.supplement.pinnedUseServingsIntake;
    useServingsRestock = widget.supplement.pinnedUseServingsRestock;

    recordEnabled = widget.supplement.pinnedIntakeAmount > 0;
    restockEnabled = widget.supplement.pinnedRestockAmount > 0;

    intakeController.text = widget.supplement.pinnedIntakeAmount > 0
        ? widget.supplement.pinnedIntakeAmount.toString()
        : "";
    restockController.text = widget.supplement.pinnedRestockAmount > 0
        ? widget.supplement.pinnedRestockAmount.toString()
        : "";
  }

  /// Sanitizes inputs right as the user exits the sheet view.
  /// If toggled ON but value is missing or 0, it auto-toggles OFF.
  void _handleSaveAndExit() {
    double iVal = double.tryParse(intakeController.text) ?? 0.0;
    double rVal = double.tryParse(restockController.text) ?? 0.0;

    // Cleanup phase: Turn off switches if fields were left blank or 0
    if (recordEnabled && iVal <= 0.0) {
      recordEnabled = false;
      iVal = 0.0;
    }
    if (restockEnabled && rVal <= 0.0) {
      restockEnabled = false;
      rVal = 0.0;
    }

    widget.onSave(
      isPinned: (recordEnabled && iVal > 0) || (restockEnabled && rVal > 0),
      intakeVal: recordEnabled ? iVal : 0.0,
      useServingsIntake: useServingsIntake,
      restockVal: restockEnabled ? rVal : 0.0,
      useServingsRestock: useServingsRestock,
    );
  }

  @override
  void dispose() {
    intakeController.dispose();
    restockController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _handleSaveAndExit();
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 40.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 20.h),

              // Header Block
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(
                      color: AppColors.crimson.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.push_pin_rounded,
                      color: AppColors.crimson,
                      size: 22.r,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("QUICK LOG SETTINGS", style: AppTextStyles.h3),
                        Text(
                          widget.supplement.name.toUpperCase(),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16.h),

              // Info Help Notice card block
              Container(
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: AppColors.crimson.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.crimson.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.crimson,
                      size: 18.r,
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        "Activating a toggle and setting values greater than 0 pins this shortcut card onto your dashboard space. Empty fields will auto-disable upon exit.",
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white70,
                          fontSize: 11.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24.h),

              // Daily Intake Segment
              _buildActionSection(
                title: "DAILY INTAKE",
                isActive: recordEnabled,
                controller: intakeController,
                useServings: useServingsIntake,
                onToggleChanged: (val) {
                  setState(() {
                    recordEnabled = val;
                    if (val) {
                      final double currentVal =
                          double.tryParse(intakeController.text) ?? 0;
                      if (currentVal <= 0) {
                        intakeController.text = "1.0";
                      }
                    } else {
                      intakeController.clear();
                    }
                  });
                },
                onUnitToggle: (v) => setState(() => useServingsIntake = v),
              ),

              SizedBox(height: 16.h),

              // Common Restock Segment
              _buildActionSection(
                title: "COMMON RESTOCK",
                isActive: restockEnabled,
                controller: restockController,
                useServings: useServingsRestock,
                onToggleChanged: (val) {
                  setState(() {
                    restockEnabled = val;
                    if (val) {
                      final double currentVal =
                          double.tryParse(restockController.text) ?? 0;
                      if (currentVal <= 0) {
                        restockController.text = "1.0";
                      }
                    } else {
                      restockController.clear();
                    }
                  });
                },
                onUnitToggle: (v) => setState(() => useServingsRestock = v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionSection({
    required String title,
    required bool isActive,
    required TextEditingController controller,
    required bool useServings,
    required Function(bool) onToggleChanged,
    required Function(bool) onUnitToggle,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive
              ? AppColors.crimson.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTextStyles.labelSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch.adaptive(
                  value: isActive,
                  activeColor: AppColors.crimson,
                  onChanged: onToggleChanged,
                ),
              ),
            ],
          ),
          if (isActive) ...[
            SizedBox(height: 16.h),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.white.withOpacity(0.05),
                      ),
                    ),
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'(^\d*\.?\d*)'),
                        ),
                      ],
                      style: AppTextStyles.labelSmall.copyWith(fontSize: 16.sp),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        hintText: "1.0",
                        hintStyle: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                _buildSegmentedSelector(
                  [widget.supplement.servingUnit, widget.supplement.weightUnit],
                  useServings ? 0 : 1,
                  (i) => onUnitToggle(i == 0),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentedSelector(
    List<String> labels,
    int activeIndex,
    Function(int) onTap,
  ) {
    return Container(
      height: 48.h,
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          labels.length,
          (i) => GestureDetector(
            onTap: () => onTap(i),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activeIndex == i
                    ? AppColors.crimson
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                labels[i].toUpperCase(),
                style: AppTextStyles.labelSmall.copyWith(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: activeIndex == i
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
