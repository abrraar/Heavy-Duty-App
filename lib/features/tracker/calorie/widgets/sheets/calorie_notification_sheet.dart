import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/calorie/provider/calorie_provider.dart';
import 'package:provider/provider.dart';
import '../../model/saved_meal.dart';

class CalorieNotificationSheet extends StatefulWidget {
  final SavedMeal meal;

  const CalorieNotificationSheet({
    super.key,
    required this.meal,
  });

  @override
  State<CalorieNotificationSheet> createState() => _CalorieNotificationSheetState();
}

class _CalorieNotificationSheetState extends State<CalorieNotificationSheet> {
  late bool notificationsEnabled;
  late List<CalorieReminder> reminders;
  CalorieReminderMode _selectedMode = CalorieReminderMode.schedule;
  
  final List<TextEditingController> _intervalControllers = [];
  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    notificationsEnabled = widget.meal.notificationsEnabled;
    reminders = List.from(widget.meal.reminders);
    
    if (reminders.isNotEmpty) {
      _selectedMode = reminders.first.reminderMode;
    } else if (notificationsEnabled) {
      _addNewReminderSlot();
    }

    for (var r in reminders) {
      _intervalControllers.add(TextEditingController(text: (r.intervalValue ?? 30).toString()));
    }
  }

  @override
  void dispose() {
    for (var c in _intervalControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _handleSaveAndExit() {
    List<CalorieReminder> updatedReminders = [];
    
    // Always process current UI state into the reminders list
    for (int i = 0; i < reminders.length; i++) {
      final r = reminders[i].copyWith(reminderMode: _selectedMode);
      if (_selectedMode == CalorieReminderMode.schedule) {
        updatedReminders.add(r.times.isEmpty ? r.copyWith(times: [TimeOfDay.now()]) : r);
      } else {
        updatedReminders.add(r);
      }
    }

    final updatedMeal = widget.meal.copyWith(
      notificationsEnabled: notificationsEnabled, // This is the master switch
      reminders: updatedReminders, // Preserves data in JSON
    );

    context.read<CalorieProvider>().updateSavedMeal(updatedMeal);
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
            border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
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
                        "MEAL SCHEDULE",
                        Icons.history_edu_rounded,
                        notificationsEnabled,
                        (val) {
                          setState(() {
                            notificationsEnabled = val;
                            if (val && reminders.isEmpty) {
                              _addNewReminderSlot();
                            }
                          });
                        },
                      ),
                      if (notificationsEnabled) ...[
                        _buildModeSelectorMaster(),
                        SizedBox(height: 12.h),
                        ...reminders.asMap().entries.map((e) => _buildReminderCard(e.value, e.key)),
                        _buildAddButton("ADD TIME SLOT", _addNewReminderSlot),
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

  void _addNewReminderSlot() {
    setState(() {
      reminders.add(
        CalorieReminder(
          days: [], times: [],
          reminderMode: _selectedMode, intervalValue: 30, intervalUnit: CalorieIntervalUnit.minute,
        ),
      );
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
          _modeBtnMaster("FIXED SCHEDULE", CalorieReminderMode.schedule),
          _modeBtnMaster("INTERVAL LOOP", CalorieReminderMode.interval),
        ],
      ),
    );
  }

  Widget _modeBtnMaster(String l, CalorieReminderMode m) {
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

  Widget _buildReminderCard(CalorieReminder reminder, int index) {
    bool isSchedule = _selectedMode == CalorieReminderMode.schedule;

    return Container(
      margin: EdgeInsets.only(bottom: 20.h),
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SET REMINDER", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              if (reminders.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    reminders.removeAt(index);
                    _intervalControllers[index].dispose();
                    _intervalControllers.removeAt(index);
                  }),
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withValues(alpha: 0.7), size: 20.r),
                ),
            ],
          ),
          Divider(color: AppColors.white.withValues(alpha: 0.05), height: 32.h),

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

  Widget _buildIntervalPicker(CalorieReminder reminder, int index) {
    int currentVal = reminder.intervalValue ?? 30;
    CalorieIntervalUnit currentUnit = reminder.intervalUnit ?? CalorieIntervalUnit.minute;
    final controller = _intervalControllers[index];
    int minLimit = (currentUnit == CalorieIntervalUnit.minute) ? 15 : 1;

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
                    setState(() => reminders[index] = reminder.copyWith(intervalValue: finalVal));
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
                           setState(() => reminders[index] = reminder.copyWith(intervalValue: parsed));
                        }
                      },
                    ),
                  ),
                  _stepBtn(Icons.add, () {
                    int next = currentVal + 1;
                    controller.text = next.toString();
                    setState(() => reminders[index] = reminder.copyWith(intervalValue: next));
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
            _unitBtn("MINS", currentUnit == CalorieIntervalUnit.minute, () {
                int finalVal = currentVal;
                if (finalVal < 15) { finalVal = 15; controller.text = "15"; }
                setState(() => reminders[index] = reminder.copyWith(intervalUnit: CalorieIntervalUnit.minute, intervalValue: finalVal));
            }),
            SizedBox(width: 6.w),
            _unitBtn("HRS", currentUnit == CalorieIntervalUnit.hour, () => setState(() => reminders[index] = reminder.copyWith(intervalUnit: CalorieIntervalUnit.hour))),
            SizedBox(width: 6.w),
            _unitBtn("DAYS", currentUnit == CalorieIntervalUnit.day, () => setState(() => reminders[index] = reminder.copyWith(intervalUnit: CalorieIntervalUnit.day))),
          ],
        ),
      ],
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

  Widget _buildDayPicker(CalorieReminder reminder, int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isSelected = reminder.days.contains(i + 1);
        return GestureDetector(
          onTap: () => setState(() {
              if (isSelected) {
                reminder.days.remove(i + 1);
              } else {
                reminder.days.add(i + 1);
              }
          }),
          child: Container(
            width: 36.r, height: 36.r,
            decoration: BoxDecoration(color: isSelected ? AppColors.crimson : AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.white.withValues(alpha: 0.05))),
            alignment: Alignment.center,
            child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 10.sp)),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(CalorieReminder reminder, int index) {
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
              decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20.r)),
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

  Future<void> _selectTime(CalorieReminder reminder) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && !reminder.times.contains(picked)) {
      setState(() => reminder.times.add(picked));
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(padding: EdgeInsets.all(10.r), decoration: BoxDecoration(color: AppColors.crimson.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.notifications_active_rounded, color: AppColors.crimson, size: 22.r)),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("MEAL NOTIFICATION", style: AppTextStyles.h3),
              Text(widget.meal.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
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
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.white.withValues(alpha: 0.05)), color: AppColors.white.withValues(alpha: 0.02)),
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

  Widget _buildHandle() => Center(child: Container(margin: EdgeInsets.symmetric(vertical: 12.h), width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r))));
}
