import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import '../model/body_comp_settings.dart';

class BodyCompNotificationSheet extends StatefulWidget {
  final String title;
  final List<BodyCompReminder> initialReminders;
  final bool initialEnabled;
  final Function(bool, List<BodyCompReminder>) onSave;

  const BodyCompNotificationSheet({
    super.key,
    required this.title,
    required this.initialReminders,
    required this.initialEnabled,
    required this.onSave,
  });

  @override
  State<BodyCompNotificationSheet> createState() => _BodyCompNotificationSheetState();
}

class _BodyCompNotificationSheetState extends State<BodyCompNotificationSheet> {
  late bool enabled;
  late List<BodyCompReminder> reminders;
  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];

  @override
  void initState() {
    super.initState();
    enabled = widget.initialEnabled;
    reminders = List.from(widget.initialReminders);
    // Ensure at least one schedule exists
    if (reminders.isEmpty) {
      reminders.add(BodyCompReminder(days: [], times: []));
    }
  }

  void _addNewSlot() {
    setState(() {
      reminders.add(BodyCompReminder(days: [], times: []));
    });
  }

  void _handleSave() {
    List<BodyCompReminder> finalReminders = [];
    bool anyDaySelected = false;

    for (var r in reminders) {
      if (r.days.isNotEmpty) {
        anyDaySelected = true;
        // If days are selected but no time, auto-add current time
        if (r.times.isEmpty) {
          finalReminders.add(r.copyWith(times: [TimeOfDay.now()]));
        } else {
          finalReminders.add(r);
        }
      } else {
        finalReminders.add(r);
      }
    }

    // A reminder can only be ON if at least one day is selected
    bool finalEnabled = enabled && anyDaySelected;

    widget.onSave(finalEnabled, finalReminders);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _handleSave();
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                        "REMINDER SCHEDULE",
                        Icons.notifications_active_rounded,
                        enabled,
                        (val) {
                          setState(() {
                            enabled = val;
                            if (val && reminders.isEmpty) {
                              _addNewSlot();
                            }
                          });
                        },
                      ),
                      if (enabled) ...[
                        ...reminders.asMap().entries.map((e) => _buildReminderCard(e.value, e.key)),
                        _buildAddButton("ADD TIME SLOT", _addNewSlot),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10.r),
          decoration: BoxDecoration(
            color: AppColors.crimson.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.notifications_active_rounded, color: AppColors.crimson, size: 22.r),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title.toUpperCase(), style: AppTextStyles.h3),
              Text("SET TRACKING REMINDERS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String l, IconData i, bool v, Function(bool) o) => Padding(
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

  Widget _buildReminderCard(BodyCompReminder reminder, int index) {
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
              Text("SCHEDULE ${index + 1}", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              if (reminders.length > 1)
                IconButton(
                  onPressed: () => setState(() {
                    reminders.removeAt(index);
                  }),
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withOpacity(0.7), size: 20.r),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildDayPicker(reminder, index),
          SizedBox(height: 20.h),
          _buildTimeChips(reminder, index),
        ],
      ),
    );
  }

  Widget _buildDayPicker(BodyCompReminder reminder, int index) {
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
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.crimson : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white.withOpacity(0.05)),
            ),
            alignment: Alignment.center,
            child: Text(
              weekDays[i],
              style: AppTextStyles.labelSmall.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 10.sp,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(BodyCompReminder reminder, int index) {
    final bool daysSelected = reminder.days.isNotEmpty;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: daysSelected ? 1.0 : 0.3,
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          ...reminder.times.map(
            (t) => Chip(
              backgroundColor: AppColors.surface,
              label: Text(t.format(context), style: AppTextStyles.labelSmall),
              deleteIcon: Icon(Icons.close, size: 14.r, color: AppColors.crimson),
              onDeleted: daysSelected ? () => setState(() => reminder.times.remove(t)) : null,
            ),
          ),
          GestureDetector(
            onTap: daysSelected ? () => _selectTime(reminder) : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.crimson.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
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
      ),
    );
  }

  Future<void> _selectTime(BodyCompReminder reminder) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && !reminder.times.contains(picked)) {
      setState(() => reminder.times.add(picked));
    }
  }

  Widget _buildAddButton(String l, VoidCallback o) => GestureDetector(
        onTap: o,
        child: Container(
          margin: EdgeInsets.only(top: 12.h),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: AppColors.white.withOpacity(0.05)),
            color: AppColors.white.withOpacity(0.02),
          ),
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

  Widget _buildHandle() => Center(
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 12.h),
          width: 40.w,
          height: 4.h,
          decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2.r)),
        ),
      );
}
