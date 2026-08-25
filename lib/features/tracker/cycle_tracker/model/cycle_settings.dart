import 'dart:convert';
import 'package:flutter/foundation.dart';

enum WeightUnit { lbs, kgs }

class CycleSettings {
  final WeightUnit weightUnit;
  final Set<String> visibleMetrics;
  final bool workoutRemindersEnabled;
  final int workoutReminderInterval;
  final int isSynced;
  final String? userId;

  CycleSettings({
    this.weightUnit = WeightUnit.lbs,
    this.visibleMetrics = const {"strength", "volume"},
    this.workoutRemindersEnabled = false,
    this.workoutReminderInterval = 2,
    this.isSynced = 1,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'user_id': userId,
      'weight_unit': weightUnit.name,
      'visible_metrics_json': jsonEncode(visibleMetrics.toList()),
      'workout_reminders_enabled': workoutRemindersEnabled ? 1 : 0,
      'workout_reminder_interval': workoutReminderInterval,
      'is_synced': isSynced,
    };
  }

  factory CycleSettings.fromMap(Map<String, dynamic> map) {
    final rawMetrics = map['visible_metrics_json'];
    Set<String> metrics = {"strength", "volume"};

    if (rawMetrics != null) {
      try {
        if (rawMetrics is String) {
          final List<dynamic> decoded = jsonDecode(rawMetrics);
          metrics = Set<String>.from(decoded);
        } else if (rawMetrics is List) {
          metrics = Set<String>.from(rawMetrics);
        }
      } catch (e) {
        debugPrint("Error decoding visible metrics: $e");
      }
    }

    return CycleSettings(
      weightUnit: WeightUnit.values.firstWhere(
        (e) => e.name == map['weight_unit'],
        orElse: () => WeightUnit.lbs,
      ),
      visibleMetrics: metrics,
      workoutRemindersEnabled: map['workout_reminders_enabled'] == 1,
      workoutReminderInterval: map['workout_reminder_interval'] ?? 2,
      isSynced: map['is_synced'] ?? 1,
      userId: map['user_id'] as String?,
    );
  }

  CycleSettings copyWith({
    WeightUnit? weightUnit,
    Set<String>? visibleMetrics,
    bool? workoutRemindersEnabled,
    int? workoutReminderInterval,
    int? isSynced,
    String? userId,
  }) {
    return CycleSettings(
      weightUnit: weightUnit ?? this.weightUnit,
      visibleMetrics: visibleMetrics ?? this.visibleMetrics,
      workoutRemindersEnabled: workoutRemindersEnabled ?? this.workoutRemindersEnabled,
      workoutReminderInterval: workoutReminderInterval ?? this.workoutReminderInterval,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
    );
  }
}


