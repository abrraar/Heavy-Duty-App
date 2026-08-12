// lib/features/tracker/hydration/model/hydration_reminder.dart

import 'package:flutter/material.dart';

enum HydrationReminderMode { schedule, interval }
enum HydrationIntervalUnit { minute, hour }

class HydrationReminder {
  final List<int> days; // 1 (Mon) to 7 (Sun)
  final List<TimeOfDay> times;
  final HydrationReminderMode mode;
  final int? intervalValue;
  final HydrationIntervalUnit? intervalUnit;

  HydrationReminder({
    required this.days,
    required this.times,
    this.mode = HydrationReminderMode.schedule,
    this.intervalValue,
    this.intervalUnit,
  });

  Map<String, dynamic> toMap() {
    return {
      'days': days,
      'times': times.map((t) => '${t.hour}:${t.minute}').toList(),
      'mode': mode.name,
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit?.name,
    };
  }

  factory HydrationReminder.fromMap(Map<String, dynamic> map) {
    return HydrationReminder(
      days: List<int>.from(map['days'] ?? []),
      times: (map['times'] as List? ?? []).map((t) {
        final parts = (t as String).split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList(),
      mode: HydrationReminderMode.values.firstWhere(
        (e) => e.name == map['mode'],
        orElse: () => HydrationReminderMode.schedule,
      ),
      intervalValue: map['intervalValue'],
      intervalUnit: map['intervalUnit'] != null
          ? HydrationIntervalUnit.values.firstWhere(
              (e) => e.name == map['intervalUnit'],
              orElse: () => HydrationIntervalUnit.minute,
            )
          : null,
    );
  }

  HydrationReminder copyWith({
    List<int>? days,
    List<TimeOfDay>? times,
    HydrationReminderMode? mode,
    int? intervalValue,
    HydrationIntervalUnit? intervalUnit,
  }) {
    return HydrationReminder(
      days: days ?? this.days,
      times: times ?? this.times,
      mode: mode ?? this.mode,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
    );
  }
}
