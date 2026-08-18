// lib/features/tracker/supplement/widgets/sheets/notification_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import 'package:heavy_duty/core/services/notification_service.dart';
import '../../model/supplement.dart';

class NotificationSheet extends StatefulWidget {
  final Supplement supplement;
  final List<SupplementReminder> initialReminders;
  final bool initialEnabled;

  const NotificationSheet({
    super.key,
    required this.supplement,
    required this.initialReminders,
    required this.initialEnabled,
  });

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  late bool recordEnabled;
  late bool restockEnabled;

  late List<SupplementReminder> intakeReminders;
  ReminderMode _selectedMode = ReminderMode.schedule;
  
  double lowStockThreshold = 5.0;
  bool restockUseServings = true;

  final List<bool> intakeUseServings = [];
  final List<TextEditingController> _intakeControllers = [];
  final List<TextEditingController> _intervalControllers = [];
  late TextEditingController _restockController;

  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    intakeReminders = widget.initialReminders
        .where((r) => r.type == ReminderType.intake)
        .toList();
    
    // Respect the master enabled flag from the parent card
    recordEnabled = widget.initialEnabled && intakeReminders.isNotEmpty;

    if (intakeReminders.isNotEmpty) {
      _selectedMode = intakeReminders.first.reminderMode;
    }

    final restockReminder = widget.initialReminders.firstWhere(
      (r) => r.type == ReminderType.lowStock,
      orElse: () => SupplementReminder(
        days: [],
        times: [],
        value: 5.0,
        type: ReminderType.lowStock,
      ),
    );

    // Respect the master enabled flag from the parent card
    restockEnabled = widget.initialEnabled && widget.initialReminders.any(
      (r) => r.type == ReminderType.lowStock,
    );
    lowStockThreshold = restockReminder.value;

    if (widget.supplement.weightPerServing > 0 && (lowStockThreshold % widget.supplement.weightPerServing == 0)) {
      restockUseServings = true;
      _restockController = TextEditingController(
        text: (lowStockThreshold / widget.supplement.weightPerServing).toStringAsFixed(1),
      );
    } else {
      restockUseServings = false;
      _restockController = TextEditingController(
        text: lowStockThreshold.toStringAsFixed(1),
      );
    }

    for (int i = 0; i < intakeReminders.length; i++) {
      intakeUseServings.add(true);
      _intakeControllers.add(TextEditingController(
        text: intakeReminders[i].value.toStringAsFixed(1),
      ));

      int startingInterval = intakeReminders[i].intervalValue ?? 30;
      if (intakeReminders[i].intervalUnit == IntervalUnit.minute && startingInterval < 15) {
        startingInterval = 15;
      }
      _intervalControllers.add(TextEditingController(
        text: startingInterval.toString(),
      ));
    }
  }

  @override
  void dispose() {
    for (var c in _intakeControllers) c.dispose();
    for (var c in _intervalControllers) c.dispose();
    _restockController.dispose();
    super.dispose();
  }

  void _handleSaveAndExit() {
    List<SupplementReminder> updatedIntake = [];
    
    // Process intake UI state
    for (int i = 0; i < intakeReminders.length; i++) {
      final r = intakeReminders[i].copyWith(reminderMode: _selectedMode);
      if (_selectedMode == ReminderMode.schedule) {
        updatedIntake.add(r.times.isEmpty ? r.copyWith(times: [TimeOfDay.now()]) : r);
      } else {
        updatedIntake.add(r);
      }
    }

    // Master Switch Logic: Active if either section is toggled ON
    bool masterActive = recordEnabled || restockEnabled;

    context.read<SupplementProvider>().updateNotificationSettings(
      targetId: widget.supplement.id,
      isStack: false, 
      masterEnabled: masterActive, 
      recordEnabled: recordEnabled, 
      restockEnabled: restockEnabled,
      intakeReminders: recordEnabled ? updatedIntake : [], 
      lowStockThresholds: restockEnabled ? {
        widget.supplement.id: restockUseServings
            ? lowStockThreshold * widget.supplement.weightPerServing
            : lowStockThreshold
      } : {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _handleSaveAndExit();
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 24.h),
                      _sectionHeader(
                        "INTAKE SCHEDULE",
                        Icons.history_edu_rounded,
                        recordEnabled,
                        (val) {
                          setState(() {
                            recordEnabled = val;
                            if (val && intakeReminders.isEmpty) {
                              _addNewIntakeSlot();
                            }
                          });
                        },
                      ),
                      if (recordEnabled) ...[
                        _buildModeSelectorMaster(),
                        SizedBox(height: 12.h),
                        ...intakeReminders.asMap().entries.map((e) => _buildIntakeCard(e.value, e.key)),
                        _buildAddButton("ADD TIME SLOT", _addNewIntakeSlot),
                      ],
                      SizedBox(height: 32.h),
                      _sectionHeader("INVENTORY ALERTS", Icons.inventory_2_rounded, restockEnabled, (val) => setState(() => restockEnabled = val)),
                      if (restockEnabled) ...[
                        _instructionTile("Enter any inventory threshold value above 0 to trigger restock notifications."),
                        SizedBox(height: 12.h),
                        _buildLowStockCard(),
                      ],
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewIntakeSlot() {
    setState(() {
      intakeReminders.add(
        SupplementReminder(
          days: [], times: [], value: 1.0, type: ReminderType.intake,
          reminderMode: _selectedMode, intervalValue: 30, intervalUnit: IntervalUnit.minute,
        ),
      );
      intakeUseServings.add(true);
      _intakeControllers.add(TextEditingController(text: "1.0"));
      _intervalControllers.add(TextEditingController(text: "30"));
    });
  }

  Widget _buildModeSelectorMaster() {
    return Container(
      padding: EdgeInsets.all(2.r),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          _modeBtnMaster("FIXED SCHEDULE", ReminderMode.schedule),
          _modeBtnMaster("INTERVAL LOOP", ReminderMode.interval),
        ],
      ),
    );
  }

  Widget _modeBtnMaster(String l, ReminderMode m) {
    bool active = _selectedMode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = m),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(10.r)),
          alignment: Alignment.center,
          child: Text(l, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: active ? Colors.white : AppColors.textSecondary, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildIntakeCard(SupplementReminder reminder, int index) {
    bool useServings = intakeUseServings[index];
    bool isSchedule = _selectedMode == ReminderMode.schedule;

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SET DOSE CONFIG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              IconButton(
                onPressed: () => setState(() {
                  intakeReminders.removeAt(index);
                  intakeUseServings.removeAt(index);
                  _intakeControllers[index].dispose();
                  _intakeControllers.removeAt(index);
                  _intervalControllers[index].dispose();
                  _intervalControllers.removeAt(index);
                }),
                icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withOpacity(0.7), size: 20.r),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.crimson.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _valueInputStepper(
                    controller: _intakeControllers[index],
                    value: reminder.value,
                    isInventory: false,
                    onChanged: (val) => setState(() {
                      intakeReminders[index] = reminder.copyWith(value: val);
                    }),
                  ),
                ),
                SizedBox(width: 12.w),
                _unitBtn(widget.supplement.servingUnit.toUpperCase(), useServings, () => setState(() => intakeUseServings[index] = true)),
                SizedBox(width: 4.w),
                _unitBtn(widget.supplement.weightUnit.toUpperCase(), !useServings, () => setState(() => intakeUseServings[index] = false)),
              ],
            ),
          ),
          Divider(color: AppColors.white.withOpacity(0.05), height: 32.h),

          if (isSchedule) ...[
            _buildDayPicker(reminder, index),
            SizedBox(height: 20.h),
            _buildTimeChips(reminder, index),
          ] else ...[
            _buildIntervalPicker(reminder, index),
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalPicker(SupplementReminder reminder, int index) {
    int currentVal = reminder.intervalValue ?? 30;
    IntervalUnit currentUnit = reminder.intervalUnit ?? IntervalUnit.minute;
    final controller = _intervalControllers[index];
    int minLimit = (currentUnit == IntervalUnit.minute) ? 15 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("REMIND ME EVERY:", style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              width: 140.w,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10.r)),
              child: Row(
                children: [
                  _stepBtn(Icons.remove, () {
                    int next = currentVal - 1;
                    int finalVal = next >= minLimit ? next : minLimit;
                    controller.text = finalVal.toString();
                    setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: finalVal));
                  }),
                  Expanded(
                    child: TextFormField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                      onChanged: (text) {
                        int? parsed = int.tryParse(text);
                        if (parsed != null) {
                           setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: parsed));
                        }
                      },
                      onFieldSubmitted: (text) {
                        int? parsed = int.tryParse(text);
                        int finalVal = (parsed == null || parsed < minLimit) ? minLimit : parsed;
                        controller.text = finalVal.toString();
                        setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: finalVal));
                      },
                    ),
                  ),
                  _stepBtn(Icons.add, () {
                    int next = currentVal + 1;
                    controller.text = next.toString();
                    setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: next));
                  }),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _unitBtn("MINS", currentUnit == IntervalUnit.minute, () {
                int finalVal = currentVal;
                if (finalVal < 15) { finalVal = 15; controller.text = "15"; }
                setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.minute, intervalValue: finalVal));
            }),
            SizedBox(width: 6.w),
            _unitBtn("HRS", currentUnit == IntervalUnit.hour, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.hour))),
            SizedBox(width: 6.w),
            _unitBtn("DAYS", currentUnit == IntervalUnit.day, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.day))),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockCard() {
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("THRESHOLD CONFIG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20.r)),
            child: Column(
              children: [
                _valueInputStepper(
                  controller: _restockController,
                  value: lowStockThreshold,
                  isInventory: true,
                  onChanged: (val) => setState(() => lowStockThreshold = val),
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(child: _unitBtn(widget.supplement.servingUnit.toUpperCase(), restockUseServings, () {
                        if (!restockUseServings) {
                          setState(() {
                            double currentWeight = double.tryParse(_restockController.text) ?? 0.0;
                            if (widget.supplement.weightPerServing > 0) {
                              _restockController.text = (currentWeight / widget.supplement.weightPerServing).toStringAsFixed(1);
                              lowStockThreshold = double.tryParse(_restockController.text) ?? 0.0;
                            }
                            restockUseServings = true;
                          });
                        }
                    })),
                    SizedBox(width: 12.w),
                    Expanded(child: _unitBtn(widget.supplement.weightUnit.toUpperCase(), !restockUseServings, () {
                        if (restockUseServings) {
                          setState(() {
                            double currentServings = double.tryParse(_restockController.text) ?? 0.0;
                            _restockController.text = (currentServings * widget.supplement.weightPerServing).toStringAsFixed(1);
                            lowStockThreshold = double.tryParse(_restockController.text) ?? 0.0;
                            restockUseServings = false;
                          });
                        }
                    })),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueInputStepper({required TextEditingController controller, required double value, required bool isInventory, required Function(double) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10.r)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepBtn(Icons.remove, () {
            double minVal = isInventory ? 0.0 : 0.5;
            double newVal = (value > minVal) ? value - 0.5 : minVal;
            controller.text = newVal.toStringAsFixed(1);
            onChanged(newVal);
          }),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))],
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
              onChanged: (text) {
                double? parsed = double.tryParse(text);
                if (parsed != null) { if (!isInventory && parsed < 0.5) return; onChanged(parsed); }
              },
              onSubmitted: (text) {
                double? parsed = double.tryParse(text);
                double minVal = isInventory ? 0.0 : 0.5;
                if (parsed == null || parsed < minVal) { controller.text = minVal.toStringAsFixed(1); onChanged(minVal); }
              },
            ),
          ),
          _stepBtn(Icons.add, () {
            double newVal = value + 0.5;
            controller.text = newVal.toStringAsFixed(1);
            onChanged(newVal);
          }),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(6.r),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Icon(icon, color: AppColors.crimson, size: 16.r),
    ),
  );

  Widget _unitBtn(String label, bool active, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: active ? AppColors.crimson : AppColors.background, borderRadius: BorderRadius.circular(10.r)),
          child: Text(label, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: active ? Colors.white : AppColors.textSecondary, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      );

  Widget _buildDayPicker(SupplementReminder reminder, int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isSelected = reminder.days.contains(i + 1);
        return GestureDetector(
          onTap: () => setState(() {
              if (isSelected) reminder.days.remove(i + 1);
              else reminder.days.add(i + 1);
          }),
          child: Container(
            width: 36.r, height: 36.r,
            decoration: BoxDecoration(color: isSelected ? AppColors.crimson : AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.white.withOpacity(0.05))),
            alignment: Alignment.center,
            child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 10.sp)),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(SupplementReminder reminder, int index) {
    return Wrap(
      spacing: 8.w, runSpacing: 8.h,
      children: [
        ...reminder.times.map((t) => Chip(
            backgroundColor: AppColors.surface,
            label: Text(t.format(context), style: AppTextStyles.labelSmall),
            deleteIcon: Icon(Icons.close, size: 14.r, color: AppColors.crimson),
            onDeleted: () => setState(() => reminder.times.remove(t)),
          ),
        ),
        GestureDetector(
          onTap: () => _selectTime(reminder),
          child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(20.r)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 14.r, color: AppColors.crimson),
                  SizedBox(width: 4.w),
                  Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ),
      ],
    );
  }

  Future<void> _selectTime(SupplementReminder reminder) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && !reminder.times.contains(picked)) {
      setState(() => reminder.times.add(picked));
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(padding: EdgeInsets.all(10.r), decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.notifications_active_rounded, color: AppColors.crimson, size: 22.r)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("SUPPLEMENT NOTIFICATION", style: AppTextStyles.h3),
              Text(widget.supplement.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String l, IconData i, bool v, Function(bool) o) =>
      Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          children: [
            Icon(i, color: AppColors.crimson, size: 16.r),
            SizedBox(width: 8.w),
            Text(l, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.white)),
            const Spacer(),
            Transform.scale(scale: 0.8, child: Switch.adaptive(value: v, activeColor: AppColors.crimson, onChanged: o)),
          ],
        ),
      );

  Widget _buildAddButton(String l, VoidCallback o) => GestureDetector(
    onTap: o,
    child: Container(
      margin: EdgeInsets.only(top: 12.h),
      padding: EdgeInsets.symmetric(vertical: 14.h),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.white.withOpacity(0.05)), color: AppColors.white.withOpacity(0.02)),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 18.r),
          SizedBox(width: 8.w),
          Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );

  Widget _instructionTile(String t) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.crimson.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.crimson.withOpacity(0.15), width: 1.r),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14.r, color: AppColors.crimson),
          SizedBox(width: 10.w),
          Expanded(child: Text(t, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.textSecondary, fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(child: Container(margin: EdgeInsets.symmetric(vertical: 12.h), width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2.r))));
}
