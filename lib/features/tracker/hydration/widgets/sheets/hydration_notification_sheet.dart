// lib/features/tracker/hydration/widgets/sheets/hydration_notification_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:provider/provider.dart';
import '../../provider/hydration_provider.dart';
import '../../model/hydration_reminder.dart';

class HydrationNotificationSheet extends StatefulWidget {
  const HydrationNotificationSheet({super.key});

  @override
  State<HydrationNotificationSheet> createState() => _HydrationNotificationSheetState();
}

class _HydrationNotificationSheetState extends State<HydrationNotificationSheet> {
  final List<String> weekDays = ["M", "T", "W", "T", "F", "S", "S"];
  
  late List<HydrationReminder> _localReminders;
  late bool _remindersEnabled;
  HydrationReminderMode _selectedMode = HydrationReminderMode.schedule;
  final List<TextEditingController> _intervalControllers = [];

  @override
  void initState() {
    super.initState();
    final settings = context.read<HydrationProvider>().settings;
    _remindersEnabled = settings.remindersEnabled;
    _localReminders = List.from(settings.reminders);
    
    if (_localReminders.isNotEmpty) {
      _selectedMode = _localReminders.first.mode;
    }

    for (var r in _localReminders) {
      _intervalControllers.add(TextEditingController(text: r.intervalValue?.toString() ?? "60"));
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
    final provider = context.read<HydrationProvider>();
    final settings = provider.settings;

    List<HydrationReminder> validatedReminders = [];
    if (_remindersEnabled) {
      for (int i = 0; i < _localReminders.length; i++) {
        var r = _localReminders[i].copyWith(mode: _selectedMode);
        
        if (_selectedMode == HydrationReminderMode.schedule) {
          if (r.days.isNotEmpty) {
            // Rule: If days picked but no times, set current time
            if (r.times.isEmpty) {
              validatedReminders.add(r.copyWith(times: [TimeOfDay.now()]));
            } else {
              validatedReminders.add(r);
            }
          }
        } else {
          // Interval mode
          validatedReminders.add(r);
        }
      }
    }

    bool finalEnabled = _remindersEnabled;
    if (validatedReminders.isEmpty) {
      finalEnabled = false;
    }

    provider.updateSettings(settings.copyWith(
      reminders: validatedReminders,
      remindersEnabled: finalEnabled,
    ));
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
          border: Border.all(color: AppColors.white.withValues(alpha: 0.05)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 40.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w, height: 4.h,
                decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2.r)),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: Colors.blueAccent, size: 24.r),
                SizedBox(width: 12.w),
                Text("HYDRATION REMINDERS", style: AppTextStyles.h3),
              ],
            ),
            SizedBox(height: 24.h),
            _buildMasterToggle(),
            if (_remindersEnabled) ...[
              SizedBox(height: 16.h),
              _buildModeSelectorMaster(),
              SizedBox(height: 12.h),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      ..._localReminders.asMap().entries.map((e) => _buildReminderCard(e.value, e.key)),
                      _buildAddButton(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMasterToggle() {
    return Container(
      padding: EdgeInsets.all(16.r),
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, color: AppColors.white, size: 22.r),
          SizedBox(width: 16.w),
          Expanded(child: Text("ENABLE REMINDERS", style: AppTextStyles.labelSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold))),
          Switch(
            value: _remindersEnabled, activeThumbColor: Colors.blueAccent, 
            onChanged: (val) {
              setState(() {
                _remindersEnabled = val;
                if (val && _localReminders.isEmpty) {
                  _localReminders.add(HydrationReminder(days: [], times: [], mode: _selectedMode));
                  _intervalControllers.add(TextEditingController(text: "60"));
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelectorMaster() {
    return Container(
      padding: EdgeInsets.all(2.r),
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          _modeBtnMaster("FIXED SCHEDULE", HydrationReminderMode.schedule),
          _modeBtnMaster("INTERVAL LOOP", HydrationReminderMode.interval),
        ],
      ),
    );
  }

  Widget _modeBtnMaster(String l, HydrationReminderMode m) {
    bool active = _selectedMode == m;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMode = m),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10.h),
          decoration: BoxDecoration(color: active ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(10.r)),
          alignment: Alignment.center,
          child: Text(l, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: active ? Colors.white : AppColors.textSecondary, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ),
      ),
    );
  }

  Widget _buildReminderCard(HydrationReminder reminder, int index) {
    bool isSchedule = _selectedMode == HydrationReminderMode.schedule;
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.white.withValues(alpha: 0.05))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("SET CONFIG #${index + 1}", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
              if (_localReminders.length > 1)
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: AppColors.textSecondary, size: 20.r),
                  onPressed: () => setState(() {
                    _localReminders.removeAt(index);
                    _intervalControllers[index].dispose();
                    _intervalControllers.removeAt(index);
                  }),
                ),
            ],
          ),
          SizedBox(height: 8.h),
          if (isSchedule) ...[
            _buildDayPicker(reminder, index),
            SizedBox(height: 16.h),
            _buildTimeChips(reminder, index),
          ] else ...[
            _buildIntervalPicker(reminder, index),
          ],
        ],
      ),
    );
  }

  Widget _buildIntervalPicker(HydrationReminder reminder, int index) {
    return Row(
      children: [
        Text("EVERY", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        _buildIntervalValueField(reminder, index),
        SizedBox(width: 8.w),
        _buildIntervalUnitSelector(reminder, index),
      ],
    );
  }

  Widget _buildIntervalValueField(HydrationReminder reminder, int index) {
    final controller = _intervalControllers[index];
    return Container(
      width: 60.w, height: 36.h,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8.r)),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(top: 8)),
        onChanged: (val) {
            int newVal = int.tryParse(val) ?? 60;
            if (newVal < 1) newVal = 1;
            _localReminders[index] = reminder.copyWith(intervalValue: newVal);
        },
      ),
    );
  }

  Widget _buildIntervalUnitSelector(HydrationReminder reminder, int index) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8.r)),
      child: DropdownButton<HydrationIntervalUnit>(
        value: reminder.intervalUnit ?? HydrationIntervalUnit.minute,
        underline: const SizedBox(),
        dropdownColor: AppColors.surface,
        items: [
          DropdownMenuItem(value: HydrationIntervalUnit.minute, child: Text("MINS", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp))),
          DropdownMenuItem(value: HydrationIntervalUnit.hour, child: Text("HRS", style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp))),
        ],
        onChanged: (val) {
            setState(() => _localReminders[index] = reminder.copyWith(intervalUnit: val));
        },
      ),
    );
  }

  Widget _buildDayPicker(HydrationReminder reminder, int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final day = i + 1;
        final isSelected = reminder.days.contains(day);
        return GestureDetector(
          onTap: () {
            setState(() {
              final newDays = List<int>.from(reminder.days);
              isSelected ? newDays.remove(day) : newDays.add(day);
              
              if (newDays.isEmpty && _localReminders.length > 1) {
                 _localReminders.removeAt(index);
                 _intervalControllers[index].dispose();
                 _intervalControllers.removeAt(index);
              } else {
                 _localReminders[index] = reminder.copyWith(days: newDays);
              }
            });
          },
          child: Container(
            width: 32.r, height: 32.r,
            decoration: BoxDecoration(color: isSelected ? Colors.blueAccent : AppColors.surface, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: isSelected ? Colors.white : AppColors.textSecondary, fontSize: 10.sp)),
          ),
        );
      }),
    );
  }

  Widget _buildTimeChips(HydrationReminder reminder, int index) {
    return Wrap(
      spacing: 8.w, 
      runSpacing: 8.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...reminder.times.map((t) => Chip(
          backgroundColor: AppColors.surface,
          visualDensity: VisualDensity.compact,
          label: Text(t.format(context), style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp)),
          onDeleted: () => setState(() => _localReminders[index] = reminder.copyWith(times: List.from(reminder.times)..remove(t))),
          deleteIcon: Icon(Icons.close, size: 14.r, color: Colors.blueAccent),
        )),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context, 
              initialTime: TimeOfDay.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: Colors.blueAccent,
                      onPrimary: Colors.white,
                      surface: AppColors.surface,
                      onSurface: Colors.white,
                    ),
                    timePickerTheme: Theme.of(context).timePickerTheme.copyWith(
                      dayPeriodColor: WidgetStateColor.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.blueAccent;
                        }
                        return Colors.white.withOpacity(0.05);
                      }),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _localReminders[index] = reminder.copyWith(times: List.from(reminder.times)..add(picked)));
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.1), 
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                Icon(Icons.access_time_rounded, size: 14.r, color: Colors.blueAccent),
                SizedBox(width: 4.w),
                Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10.sp)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _localReminders.add(HydrationReminder(days: [], times: [], mode: _selectedMode));
        _intervalControllers.add(TextEditingController(text: "60"));
      }),
      child: Container(
        margin: EdgeInsets.only(top: 12.h),
        padding: EdgeInsets.symmetric(vertical: 14.h),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.white.withValues(alpha: 0.05)), color: AppColors.white.withValues(alpha: 0.02)),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 18.r),
            SizedBox(width: 8.w),
            Text("ADD NEW SLOT", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }
}
