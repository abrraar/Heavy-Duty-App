// lib/features/tracker/supplement/widgets/intake_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import '../../model/supplement.dart';

class IntakeSheet extends StatefulWidget {
  final Supplement supplement;
  final Function({
    required bool recordIntake,
    required bool restockInventory,
    required double intakeVal,
    required double restockVal,
    required bool useServingsForIntake,
    required bool useServingsForRestock,
    required DateTime selectedTimestamp,
  })
  onConfirm;

  const IntakeSheet({
    super.key,
    required this.supplement,
    required this.onConfirm,
  });

  @override
  State<IntakeSheet> createState() => _IntakeSheetState();
}

class _IntakeSheetState extends State<IntakeSheet> {
  bool recordIntake = true;
  bool restockInventory = false;
  bool useServingsForIntake = true;
  bool useServingsForRestock = true;
  DateTime selectedTimestamp = DateTime.now();

  final TextEditingController intakeController = TextEditingController(
    text: "1.0",
  );
  final TextEditingController restockController = TextEditingController(
    text: "1.0",
  );

  @override
  void dispose() {
    intakeController.dispose();
    restockController.dispose();
    super.dispose();
  }

  void _validateAndUpdateValue(TextEditingController controller, String text) {
    double? parsed = double.tryParse(text);
    if (parsed == null || parsed <= 0) {
      controller.text = "0.5";
    }
  }

  @override
  Widget build(BuildContext context) {
    double iVal = double.tryParse(intakeController.text) ?? 0.0;
    double rVal = double.tryParse(restockController.text) ?? 0.0;

    final bool isActionEnabled =
        (recordIntake && iVal > 0) || (restockInventory && rVal > 0);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
          border: Border.all(color: AppColors.white.withOpacity(0.05)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 40.h),
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      SizedBox(height: 24.h),
                      _buildDatePicker(),
                      SizedBox(height: 16.h),

                      // Intake Section
                      _buildActionContainer(
                        isActive: recordIntake,
                        child: Column(
                          children: [
                            _buildToggleRow(
                              "RECORD INTAKE",
                              recordIntake,
                              (v) => setState(() => recordIntake = v),
                            ),
                            if (recordIntake) ...[
                              SizedBox(height: 16.h),
                              _buildInputStepperRow(
                                intakeController,
                                useServingsForIntake,
                                (v) => setState(() => useServingsForIntake = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Restock Section
                      _buildActionContainer(
                        isActive: restockInventory,
                        child: Column(
                          children: [
                            _buildToggleRow(
                              "RESTOCK INVENTORY",
                              restockInventory,
                              (v) => setState(() => restockInventory = v),
                            ),
                            if (restockInventory) ...[
                              SizedBox(height: 16.h),
                              _buildInputStepperRow(
                                restockController,
                                useServingsForRestock,
                                (v) =>
                                    setState(() => useServingsForRestock = v),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),

                      _buildActionButton(
                        label: isActionEnabled
                            ? "CONFIRM LOG"
                            : "ENABLE AN ACTION ABOVE",
                        isEnabled: isActionEnabled,
                        onPressed: () {
                          if (isActionEnabled) {
                            widget.onConfirm(
                              recordIntake: recordIntake,
                              restockInventory: restockInventory,
                              intakeVal:
                                  double.tryParse(intakeController.text) ?? 0.5,
                              restockVal:
                                  double.tryParse(restockController.text) ??
                                  0.5,
                              useServingsForIntake: useServingsForIntake,
                              useServingsForRestock: useServingsForRestock,
                              selectedTimestamp: selectedTimestamp,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputStepperRow(
    TextEditingController controller,
    bool useServings,
    Function(bool) onUnitToggle,
  ) {
    double currentValue = double.tryParse(controller.text) ?? 1.0;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: AppColors.white.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                _stepBtn(Icons.remove, () {
                  double newVal = (currentValue > 0.5)
                      ? currentValue - 0.5
                      : 0.5;
                  setState(() => controller.text = newVal.toStringAsFixed(1));
                }),
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h3.copyWith(fontSize: 18.sp),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'(^\d*\.?\d*)'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (text) => setState(
                      () => _validateAndUpdateValue(controller, text),
                    ),
                    onChanged: (text) => setState(() {}),
                  ),
                ),
                _stepBtn(Icons.add, () {
                  double newVal = currentValue + 0.5;
                  setState(() => controller.text = newVal.toStringAsFixed(1));
                }),
              ],
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
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(8.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: AppColors.crimson, size: 20.r),
    ),
  );

  Widget _buildToggleRow(String title, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        Switch.adaptive(
          value: value,
          activeColor: AppColors.crimson,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return _buildActionContainer(
      isActive: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "DATE & TIME",
            style: AppTextStyles.labelSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: _pickDateTime,
            child: Text(
              DateFormat('MMM d, h:mm a').format(selectedTimestamp),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.crimson,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // CLEANED: Inline configurations removed; everything runs through AppPickerTheme definitions smoothly
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedTimestamp,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedTimestamp),
      );

      if (time != null) {
        setState(
          () => selectedTimestamp = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          ),
        );
      }
    }
  }

  Widget _buildHeader() => Row(
    children: [
      Container(
        padding: EdgeInsets.all(10.r),
        decoration: BoxDecoration(
          color: AppColors.crimson.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add_task_rounded,
          color: AppColors.crimson,
          size: 24.r,
        ),
      ),
      SizedBox(width: 12.w),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("LOG ACTIVITY", style: AppTextStyles.h3),
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
  );

  Widget _buildHandle() => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(vertical: 16.h),
    alignment: Alignment.center,
    child: Container(
      width: 40.w,
      height: 4.h,
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withOpacity(0.4),
        borderRadius: BorderRadius.circular(3.r),
      ),
    ),
  );

  Widget _buildActionContainer({
    required bool isActive,
    required Widget child,
  }) => AnimatedOpacity(
    duration: const Duration(milliseconds: 200),
    opacity: isActive ? 1.0 : 0.6,
    child: Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive
              ? AppColors.crimson.withOpacity(0.2)
              : AppColors.white.withOpacity(0.05),
        ),
      ),
      child: child,
    ),
  );

  Widget _buildSegmentedSelector(
    List<String> labels,
    int activeIndex,
    Function(int) onTap,
  ) => Container(
    height: 48.h,
    padding: EdgeInsets.all(4.r),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12.r),
      border: Border.all(color: AppColors.white.withOpacity(0.05)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(labels.length, (i) {
        final isActive = activeIndex == i;
        return GestureDetector(
          onTap: () => onTap(i),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive ? AppColors.crimson : Colors.transparent,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              labels[i].toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    ),
  );

  Widget _buildActionButton({
    required String label,
    required bool isEnabled,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 60.h,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppColors.crimson
              : AppColors.crimson.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.crimson.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
          border: isEnabled
              ? null
              : Border.all(color: AppColors.crimson.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: AppTextStyles.buttonPrimary.copyWith(
            fontSize: 16.sp,
            color: isEnabled ? Colors.white : Colors.white.withOpacity(0.3),
          ),
        ),
      ),
    );
  }
}
