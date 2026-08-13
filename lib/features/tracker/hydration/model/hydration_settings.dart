// lib/features/tracker/hydration/model/hydration_settings.dart

import 'dart:convert';
import 'hydration_reminder.dart';

enum HydrationUnit { ml, oz }

class HydrationSettings {
  final int dailyGoal; // in ml
  final HydrationUnit unit;
  final int addValue; // in ml
  final int minusValue; // in ml
  final bool remindersEnabled;
  final bool isPinnedToHome;
  final List<HydrationReminder> reminders;
  final int isSynced;

  HydrationSettings({
    this.dailyGoal = 3500,
    this.unit = HydrationUnit.ml,
    this.addValue = 250,
    this.minusValue = 250,
    this.remindersEnabled = true,
    this.isPinnedToHome = true,
    this.reminders = const [],
    this.isSynced = 1,
  });

  bool get useMetric => unit == HydrationUnit.ml;

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'daily_goal': dailyGoal,
      'unit': unit.name,
      'add_value': addValue,
      'minus_value': minusValue,
      'reminders_enabled': remindersEnabled ? 1 : 0,
      'is_pinned_to_home': isPinnedToHome ? 1 : 0,
      'reminders_json': jsonEncode(reminders.map((r) => r.toMap()).toList()),
      'is_synced': isSynced,
    };
  }

  factory HydrationSettings.fromMap(Map<String, dynamic> map) {
    final List<dynamic> decodedReminders = map['reminders_json'] != null
        ? (map['reminders_json'] is String 
            ? jsonDecode(map['reminders_json'] as String)
            : map['reminders_json'] as List)
        : [];

    bool toBool(dynamic val) {
      if (val == null) return true;
      if (val is bool) return val;
      if (val is int) return val == 1;
      return true;
    }

    // Migration logic for old use_metric boolean
    HydrationUnit resolvedUnit = HydrationUnit.ml;
    if (map['unit'] != null) {
      resolvedUnit = HydrationUnit.values.firstWhere(
        (e) => e.name == map['unit'],
        orElse: () => HydrationUnit.ml,
      );
    } else if (map['use_metric'] != null) {
      resolvedUnit = toBool(map['use_metric']) ? HydrationUnit.ml : HydrationUnit.oz;
    }

    return HydrationSettings(
      dailyGoal: map['daily_goal'] as int? ?? 3500,
      unit: resolvedUnit,
      addValue: map['add_value'] as int? ?? 250,
      minusValue: map['minus_value'] as int? ?? 250,
      remindersEnabled: toBool(map['reminders_enabled']),
      isPinnedToHome: toBool(map['is_pinned_to_home']),
      reminders: decodedReminders
          .map((r) => HydrationReminder.fromMap(r as Map<String, dynamic>))
          .toList(),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
    );
  }

  HydrationSettings copyWith({
    int? dailyGoal,
    HydrationUnit? unit,
    int? addValue,
    int? minusValue,
    bool? remindersEnabled,
    bool? isPinnedToHome,
    List<HydrationReminder>? reminders,
    int? isSynced,
  }) {
    return HydrationSettings(
      dailyGoal: dailyGoal ?? this.dailyGoal,
      unit: unit ?? this.unit,
      addValue: addValue ?? this.addValue,
      minusValue: minusValue ?? this.minusValue,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      isPinnedToHome: isPinnedToHome ?? this.isPinnedToHome,
      reminders: reminders ?? this.reminders,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
