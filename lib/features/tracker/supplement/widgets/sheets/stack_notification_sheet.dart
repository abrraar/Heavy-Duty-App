// lib/features/tracker/supplement/widgets/sheets/stack_notification_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:heavy_duty/core/theme/app_colors.dart';
import 'package:heavy_duty/core/theme/app_text_styles.dart';
import 'package:heavy_duty/features/tracker/supplement/provider/supplement_provider.dart';
import 'package:provider/provider.dart';
import '../../model/supplement.dart';
import '../../model/supplement_stack.dart';

class StackNotificationSheet extends StatefulWidget {
  final SupplementStack stack;
  final List<SupplementReminder> initialReminders;
  final bool initialEnabled;

  const StackNotificationSheet({
    super.key,
    required this.stack,
    required this.initialReminders,
    required this.initialEnabled,
  });

  @override
  State<StackNotificationSheet> createState() => _StackNotificationSheetState();
}

class _StackNotificationSheetState extends State<StackNotificationSheet> {
  late bool recordEnabled;
  late bool restockEnabled;

  late List<SupplementReminder> intakeReminders;
  ReminderMode _selectedMode = ReminderMode.schedule;

  final Map<String, double> lowStockValues = {};
  final Map<String, bool> lowStockUseServings = {};
  final Map<String, TextEditingController> _lowStockControllers = {};

  final List<Map<String, TextEditingController>> _itemControllers = [];
  final List<Map<String, bool>> _itemUseServings = [];
  final List<TextEditingController> _intervalControllers = [];

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

    // Respect the master enabled flag from the parent card
    restockEnabled = widget.initialEnabled && widget.initialReminders.any(
      (r) => r.type == ReminderType.lowStock,
    );

    for (int i = 0; i < intakeReminders.length; i++) {
      _initItemStatesForReminder(intakeReminders[i]);
    }

    for (var item in widget.stack.items) {
      final existing = widget.initialReminders.firstWhere(
        (r) => r.type == ReminderType.lowStock && r.supplementId == item.id,
        orElse: () => SupplementReminder(
          days: [], times: [], value: 5.0, type: ReminderType.lowStock, supplementId: item.id,
        ),
      );
      lowStockValues[item.id] = existing.value;
      if (item.weightPerServing > 0 && (existing.value % item.weightPerServing == 0)) {
        lowStockUseServings[item.id] = true;
        _lowStockControllers[item.id] = TextEditingController(text: (existing.value / item.weightPerServing).toStringAsFixed(1));
      } else {
        lowStockUseServings[item.id] = false;
        _lowStockControllers[item.id] = TextEditingController(text: existing.value.toStringAsFixed(1));
      }
    }
  }

  void _initItemStatesForReminder(SupplementReminder reminder) {
    Map<String, TextEditingController> controllers = {};
    Map<String, bool> useServings = {};

    int startingValue = reminder.intervalValue ?? 30;
    if (reminder.intervalUnit == IntervalUnit.minute && startingValue < 15) startingValue = 15;
    _intervalControllers.add(TextEditingController(text: startingValue.toString()));

    for (var item in widget.stack.items) {
      final double initialValue = reminder.stackItemValues?[item.id] ?? 1.0;
      controllers[item.id] = TextEditingController(text: initialValue.toStringAsFixed(1));
      useServings[item.id] = true;
    }
    _itemControllers.add(controllers);
    _itemUseServings.add(useServings);
  }

  void _performFinalCleanupAndSave() {
    List<SupplementReminder> updatedIntake = [];
    
    // Process intake UI state
    for (int i = 0; i < intakeReminders.length; i++) {
      var r = intakeReminders[i].copyWith(reminderMode: _selectedMode);
      
      if (_selectedMode == ReminderMode.schedule) {
        // If no days picked, ignore this slot
        if (r.days.isEmpty) continue;

        // Auto-pick time ONLY if days are picked but no time is set
        if (r.times.isEmpty) {
          r = r.copyWith(times: [TimeOfDay.now()]);
        }
      }

      final Map<String, double> itemValues = {};
      for (var item in widget.stack.items) {
        double? val = double.tryParse(_itemControllers[i][item.id]?.text ?? "");
        itemValues[item.id] = (val == null || val <= 0) ? 1.0 : val;
      }
      r = r.copyWith(stackItemValues: itemValues);
      updatedIntake.add(r);
    }

    // If no valid slots remain in schedule mode, turn off notifications for this section
    if (updatedIntake.isEmpty && _selectedMode == ReminderMode.schedule) {
      recordEnabled = false;
    }

    final Map<String, double> thresholds = {};
    for (var item in widget.stack.items) {
      double raw = double.tryParse(_lowStockControllers[item.id]?.text ?? "") ?? 5.0;
      thresholds[item.id] = (lowStockUseServings[item.id] ?? false) ? raw * item.weightPerServing : raw;
    }

    // Master Switch Logic: Active if either section is toggled ON
    bool masterActive = recordEnabled || restockEnabled;

    context.read<SupplementProvider>().updateNotificationSettings(
      targetId: widget.stack.id, 
      isStack: true, 
      masterEnabled: masterActive,
      recordEnabled: recordEnabled, 
      restockEnabled: restockEnabled,
      intakeReminders: recordEnabled ? updatedIntake : [], 
      lowStockThresholds: restockEnabled ? thresholds : {},
    );
  }

  @override
  void dispose() {
    for (var m in _itemControllers) for (var c in m.values) {
      c.dispose();
    }
    for (var c in _intervalControllers) {
      c.dispose();
    }
    for (var c in _lowStockControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) { if (didPop) _performFinalCleanupAndSave(); },
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)), border: Border.all(color: AppColors.white.withOpacity(0.05))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHandle(),
              Flexible(child: SingleChildScrollView(padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 40.h), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildHeader(),
                    SizedBox(height: 24.h),
                    _sectionHeader("STACK SCHEDULE", Icons.layers_rounded, recordEnabled, (v) => setState(() {
                        recordEnabled = v;
                        if (v && intakeReminders.isEmpty) _addNewSlot();
                    })),
                    if (recordEnabled) ...[
                      _buildModeSelectorMaster(),
                      SizedBox(height: 12.h),
                      ...intakeReminders.asMap().entries.map((e) => _buildGranularCard(e.value, e.key)),
                      _buildAddButton("ADD NEW TIME SLOT", _addNewSlot),
                    ],
                    SizedBox(height: 32.h),
                    _sectionHeader("INVENTORY ALERTS", Icons.inventory_2_rounded, restockEnabled, (v) => setState(() => restockEnabled = v)),
                    if (restockEnabled) ...[
                      _instructionTile("Enter any inventory threshold value above 0 to trigger restock notifications."),
                      SizedBox(height: 12.h),
                      ...widget.stack.items.map((i) => _buildLowStockCard(i)),
                    ],
              ]))),
            ],
          ),
        ),
      ),
    );
  }

  void _addNewSlot() {
    setState(() {
      final r = SupplementReminder(days: [], times: [], value: 1.0, type: ReminderType.intake, supplementIds: widget.stack.items.map((i) => i.id).toList(), reminderMode: _selectedMode, intervalValue: 30, intervalUnit: IntervalUnit.minute);
      intakeReminders.add(r);
      _initItemStatesForReminder(r);
    });
  }

  Widget _buildModeSelectorMaster() {
    return Container(padding: EdgeInsets.all(2.r), margin: EdgeInsets.only(bottom: 12.h), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12.r)), child: Row(children: [
          _modeBtnMaster("FIXED SCHEDULE", ReminderMode.schedule),
          _modeBtnMaster("INTERVAL LOOP", ReminderMode.interval),
    ]));
  }

  Widget _modeBtnMaster(String l, ReminderMode m) {
    bool active = _selectedMode == m;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedMode = m), child: Container(padding: EdgeInsets.symmetric(vertical: 10.h), decoration: BoxDecoration(color: active ? AppColors.crimson : Colors.transparent, borderRadius: BorderRadius.circular(10.r)), alignment: Alignment.center, child: Text(l, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: active ? Colors.white : AppColors.textSecondary, fontWeight: active ? FontWeight.bold : FontWeight.normal)))));
  }

  Widget _buildGranularCard(SupplementReminder reminder, int index) {
    bool isSchedule = _selectedMode == ReminderMode.schedule;
    return Container(margin: EdgeInsets.only(bottom: 20.h), padding: EdgeInsets.all(20.r), decoration: BoxDecoration(color: AppColors.background.withOpacity(0.5), borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.white.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("TIME SLOT CONFIG", style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w900, color: Colors.white)),
              if (intakeReminders.length > 1) IconButton(onPressed: () => setState(() { 
                intakeReminders.removeAt(index); 
                for (var c in _itemControllers[index].values) {
                  c.dispose();
                }
                _itemControllers.removeAt(index); 
                _itemUseServings.removeAt(index);
                _intervalControllers[index].dispose();
                _intervalControllers.removeAt(index); 
              }), icon: Icon(Icons.delete_outline_rounded, color: AppColors.crimson.withOpacity(0.7), size: 20.r)),
          ]),
          SizedBox(height: 8.h),
          ...widget.stack.items.map((i) => _buildGranularItemRow(index, i, reminder)),
          Divider(color: AppColors.white.withOpacity(0.05), height: 24.h),
          if (isSchedule) ...[
            _buildDayPicker(reminder, (days) => setState(() => intakeReminders[index] = reminder.copyWith(days: days))),
            SizedBox(height: 16.h),
            _buildTimeChips(reminder, (times) => setState(() => intakeReminders[index] = reminder.copyWith(times: times))),
          ] else ...[
            _buildIntervalPicker(reminder, index),
          ],
    ]));
  }

  Widget _buildIntervalPicker(SupplementReminder reminder, int index) {
    int currentVal = reminder.intervalValue ?? 30;
    IntervalUnit currentUnit = reminder.intervalUnit ?? IntervalUnit.minute;
    final controller = _intervalControllers[index];
    int minLimit = (currentUnit == IntervalUnit.minute) ? 15 : 1;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
            Text("REMIND ME EVERY:", style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp)),
            const Spacer(),
            Container(width: 130.w, padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10.r)), child: Row(children: [
                  _stepBtn(Icons.remove, () { int next = currentVal - 1; int finalVal = next >= minLimit ? next : minLimit; controller.text = finalVal.toString(); setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: finalVal)); }),
                  Expanded(child: TextFormField(controller: controller, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold, color: Colors.white), inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero), onFieldSubmitted: (text) { int? p = int.tryParse(text); int f = (p == null || p < minLimit) ? minLimit : p; controller.text = f.toString(); setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: f)); })),
                  _stepBtn(Icons.add, () { int next = currentVal + 1; controller.text = next.toString(); setState(() => intakeReminders[index] = reminder.copyWith(intervalValue: next)); }),
            ])),
        ]),
        SizedBox(height: 12.h),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _unitBtn("MINS", currentUnit == IntervalUnit.minute, () { int f = currentVal; if (f < 15) { f = 15; controller.text = "15"; } setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.minute, intervalValue: f)); }),
            SizedBox(width: 4.w),
            _unitBtn("HRS", currentUnit == IntervalUnit.hour, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.hour))),
            SizedBox(width: 4.w),
            _unitBtn("DAYS", currentUnit == IntervalUnit.day, () => setState(() => intakeReminders[index] = reminder.copyWith(intervalUnit: IntervalUnit.day))),
        ]),
    ]);
  }

  Widget _buildGranularItemRow(int rIdx, Supplement item, SupplementReminder r) {
    final enabled = r.supplementIds?.contains(item.id) ?? false;
    final controller = _itemControllers[rIdx][item.id]!;
    final useServings = _itemUseServings[rIdx][item.id]!;
    return AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: enabled ? 1.0 : 0.4, child: Container(margin: EdgeInsets.only(bottom: 12.h), padding: EdgeInsets.all(12.r), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: enabled ? AppColors.crimson.withOpacity(0.2) : Colors.transparent)), child: Column(children: [
            Row(children: [
                Expanded(child: Text(item.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold, fontSize: 11.sp))),
                Transform.scale(scale: 0.7, child: Switch.adaptive(value: enabled, activeColor: AppColors.crimson, onChanged: (val) { setState(() { final ids = List<String>.from(r.supplementIds ?? []); val ? ids.add(item.id) : ids.remove(item.id); intakeReminders[rIdx] = r.copyWith(supplementIds: ids); }); })),
            ]),
            if (enabled) ...[
              SizedBox(height: 12.h),
              Row(children: [
                  Expanded(child: _valueInputStepper(controller: controller, onManualChanged: (v) => setState(() {}))),
                  SizedBox(width: 12.w),
                  _unitBtn(item.servingUnit, useServings, () => setState(() => _itemUseServings[rIdx][item.id] = true)),
                  SizedBox(width: 4.w),
                  _unitBtn(item.weightUnit, !useServings, () => setState(() => _itemUseServings[rIdx][item.id] = false)),
              ]),
            ],
    ])));
  }

  Widget _buildLowStockCard(Supplement item) {
    bool useServings = lowStockUseServings[item.id] ?? false;
    final controller = _lowStockControllers[item.id]!;
    return Container(margin: EdgeInsets.only(bottom: 16.h), padding: EdgeInsets.all(20.r), decoration: BoxDecoration(color: AppColors.background.withOpacity(0.5), borderRadius: BorderRadius.circular(24.r), border: Border.all(color: AppColors.white.withOpacity(0.05))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white)),
          SizedBox(height: 16.h),
          Container(padding: EdgeInsets.all(12.r), decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20.r)), child: Column(children: [
                _valueInputStepper(controller: controller, onManualChanged: (v) => setState(() {})),
                SizedBox(height: 16.h),
                Row(children: [
                    Expanded(child: _unitBtn(item.servingUnit, useServings, () { if (!useServings) setState(() { double w = double.tryParse(controller.text) ?? 0.0; if (item.weightPerServing > 0) controller.text = (w / item.weightPerServing).toStringAsFixed(1); lowStockUseServings[item.id] = true; }); })),
                    SizedBox(width: 12.w),
                    Expanded(child: _unitBtn(item.weightUnit, !useServings, () { if (useServings) setState(() { double s = double.tryParse(controller.text) ?? 0.0; controller.text = (s * item.weightPerServing).toStringAsFixed(1); lowStockUseServings[item.id] = false; }); })),
                ]),
          ])),
    ]));
  }

  Widget _valueInputStepper({required TextEditingController controller, required Function(double) onManualChanged}) {
    double value = double.tryParse(controller.text) ?? 1.0;
    return Container(padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h), decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10.r)), child: Row(children: [
          _stepBtn(Icons.remove, () { double n = (value > 0.5) ? value - 0.5 : 0.1; if (n <= 0.0) n = 1.0; controller.text = n.toStringAsFixed(1); onManualChanged(n); }),
          Expanded(child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.bold), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))], decoration: const InputDecoration(border: InputBorder.none, isDense: true), onSubmitted: (t) { double? p = double.tryParse(t); controller.text = (p == null || p <= 0) ? "1.0" : p.toStringAsFixed(1); onManualChanged(double.parse(controller.text)); })),
          _stepBtn(Icons.add, () { double n = value + 0.5; controller.text = n.toStringAsFixed(1); onManualChanged(n); }),
    ]));
  }

  Widget _buildDayPicker(SupplementReminder r, Function(List<int>) onChanged) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: List.generate(7, (i) {
        final sel = r.days.contains(i + 1);
        return GestureDetector(onTap: () => onChanged(sel ? (List.from(r.days)..remove(i + 1)) : (List.from(r.days)..add(i + 1))), child: Container(width: 36.r, height: 36.r, decoration: BoxDecoration(color: sel ? AppColors.crimson : AppColors.surface, shape: BoxShape.circle, border: Border.all(color: sel ? Colors.transparent : AppColors.white.withOpacity(0.05))), alignment: Alignment.center, child: Text(weekDays[i], style: AppTextStyles.labelSmall.copyWith(color: sel ? Colors.white : AppColors.textSecondary, fontSize: 10.sp))));
    }));
  }

  Widget _buildTimeChips(SupplementReminder r, Function(List<TimeOfDay>) onChanged) {
    return Wrap(spacing: 8.w, runSpacing: 8.h, children: [
        ...r.times.map((t) => Chip(backgroundColor: AppColors.surface, label: Text(t.format(context), style: AppTextStyles.labelSmall), onDeleted: () => onChanged(List.from(r.times)..remove(t)), deleteIcon: Icon(Icons.close, size: 14.r, color: AppColors.crimson))),
        Opacity(
          opacity: r.days.isNotEmpty ? 1.0 : 0.4,
          child: GestureDetector(
            onTap: r.days.isNotEmpty ? () async { 
              final p = await showTimePicker(context: context, initialTime: TimeOfDay.now()); 
              if (p != null) onChanged(List.from(r.times)..add(p)); 
            } : null, 
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h), 
              decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), borderRadius: BorderRadius.circular(20.r)), 
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.access_time_rounded, size: 14.r, color: AppColors.crimson), 
                SizedBox(width: 4.w), 
                Text("ADD TIME", style: AppTextStyles.labelSmall.copyWith(color: AppColors.crimson, fontWeight: FontWeight.bold))
              ])
            )
          ),
        ),
    ]);
  }

  Widget _buildHeader() { return Row(children: [Container(padding: EdgeInsets.all(10.r), decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.layers_rounded, color: AppColors.crimson, size: 22.r)), SizedBox(width: 12.w), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("STACK NOTIFICATION", style: AppTextStyles.h3), Text(widget.stack.name.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, letterSpacing: 1.2))]))]); }
  Widget _buildHandle() => Center(child: Container(margin: EdgeInsets.symmetric(vertical: 12.h), width: 40.w, height: 4.h, decoration: BoxDecoration(color: AppColors.textSecondary.withOpacity(0.3), borderRadius: BorderRadius.circular(2.r))));
  Widget _sectionHeader(String l, IconData i, bool v, Function(bool) o) => Padding(padding: EdgeInsets.only(bottom: 8.h), child: Row(children: [Icon(i, color: AppColors.crimson, size: 16.r), SizedBox(width: 8.w), Text(l, style: AppTextStyles.labelSmall.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold, color: Colors.white)), const Spacer(), Transform.scale(scale: 0.8, child: Switch.adaptive(value: v, activeColor: AppColors.crimson, onChanged: o))]));
  Widget _instructionTile(String t) { return Container(padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h), decoration: BoxDecoration(color: AppColors.crimson.withOpacity(0.08), borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.crimson.withOpacity(0.15), width: 1.r)), child: Row(children: [Icon(Icons.info_outline_rounded, size: 14.r, color: AppColors.crimson), SizedBox(width: 10.w), Expanded(child: Text(t, style: AppTextStyles.labelSmall.copyWith(fontSize: 10.sp, color: AppColors.textSecondary, fontStyle: FontStyle.italic)))])); }
  Widget _stepBtn(IconData i, VoidCallback? o) => GestureDetector(onTap: o, child: Container(padding: EdgeInsets.all(6.r), decoration: BoxDecoration(color: const Color(0xFF0A0A0A), borderRadius: BorderRadius.circular(8.r)), child: Icon(i, color: o != null ? AppColors.crimson : AppColors.crimson.withValues(alpha: 0.3), size: 16.r)));
  Widget _unitBtn(String l, bool a, VoidCallback? o) => GestureDetector(onTap: o, child: Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h), decoration: BoxDecoration(color: a ? AppColors.crimson : AppColors.background, borderRadius: BorderRadius.circular(8.r)), child: Text(l.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(fontSize: 9.sp, color: a ? Colors.white : AppColors.textSecondary, fontWeight: a ? FontWeight.bold : FontWeight.normal))));
  Widget _buildAddButton(String l, VoidCallback o) => GestureDetector(onTap: o, child: Container(margin: EdgeInsets.only(top: 12.h), padding: EdgeInsets.symmetric(vertical: 14.h), decoration: BoxDecoration(borderRadius: BorderRadius.circular(16.r), color: AppColors.white.withOpacity(0.02), border: Border.all(color: AppColors.white.withOpacity(0.05))), alignment: Alignment.center, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_circle_outline_rounded, color: AppColors.textSecondary, size: 18.r), SizedBox(width: 8.w), Text(l, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold))])));
}
