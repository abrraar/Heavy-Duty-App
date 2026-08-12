import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

enum CalorieReminderMode { schedule, interval }

enum CalorieIntervalUnit { minute, hour, day }

class CalorieReminder {
  final List<int> days;
  final List<TimeOfDay> times;
  final CalorieReminderMode reminderMode;
  final int? intervalValue;
  final CalorieIntervalUnit? intervalUnit;

  CalorieReminder({
    required this.days,
    required this.times,
    this.reminderMode = CalorieReminderMode.schedule,
    this.intervalValue,
    this.intervalUnit,
  });

  CalorieReminder copyWith({
    List<int>? days,
    List<TimeOfDay>? times,
    CalorieReminderMode? reminderMode,
    int? intervalValue,
    CalorieIntervalUnit? intervalUnit,
  }) {
    return CalorieReminder(
      days: days ?? this.days,
      times: times ?? this.times,
      reminderMode: reminderMode ?? this.reminderMode,
      intervalValue: intervalValue ?? this.intervalValue,
      intervalUnit: intervalUnit ?? this.intervalUnit,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'days': days,
      'times': times.map((t) => '${t.hour}:${t.minute}').toList(),
      'reminderMode': reminderMode.name,
      'intervalValue': intervalValue,
      'intervalUnit': intervalUnit?.name,
    };
  }

  factory CalorieReminder.fromMap(Map<String, dynamic> map) {
    return CalorieReminder(
      days: List<int>.from(map['days'] ?? []),
      times: (map['times'] as List? ?? []).map((t) {
        final parts = (t as String).split(':');
        return TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }).toList(),
      reminderMode: CalorieReminderMode.values.firstWhere(
        (e) => e.name == map['reminderMode'],
        orElse: () => CalorieReminderMode.schedule,
      ),
      intervalValue: (map['intervalValue'] as num?)?.toInt(),
      intervalUnit: map['intervalUnit'] != null
          ? CalorieIntervalUnit.values.firstWhere(
              (e) => e.name == map['intervalUnit'],
              orElse: () => CalorieIntervalUnit.minute,
            )
          : null,
    );
  }
}

class SavedMeal {
  final String id;
  final String name;
  final String foodItems;
  final double calories;
  final double? protein;
  final double? carbs;
  final double? fats;
  final bool isPinnedToHome;
  final bool notificationsEnabled;
  final List<CalorieReminder> reminders;
  final String? addedSupplementsJson;
  final String? addedStacksJson;
  final double servings;
  final bool multiplySupps;
  final String? sharedBy;
  final int isSynced;

  SavedMeal({
    String? id,
    required this.name,
    required this.foodItems,
    required this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.isPinnedToHome = false,
    this.notificationsEnabled = false,
    this.reminders = const [],
    this.addedSupplementsJson,
    this.addedStacksJson,
    this.servings = 1.0,
    this.multiplySupps = true,
    this.sharedBy,
    this.isSynced = 1,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'food_items': foodItems,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'is_pinned_to_home': isPinnedToHome ? 1 : 0,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'reminders_json': jsonEncode(reminders.map((r) => r.toMap()).toList()),
      'added_supplements_json': addedSupplementsJson,
      'added_stacks_json': addedStacksJson,
      'servings': servings,
      'shared_by': sharedBy,
      'multiply_supps': multiplySupps ? 1 : 0,
      'is_synced': isSynced,
    };
  }

  factory SavedMeal.fromMap(Map<String, dynamic> map) {
    final List<dynamic> decodedReminders = map['reminders_json'] != null
        ? (map['reminders_json'] is String 
            ? jsonDecode(map['reminders_json'] as String) 
            : map['reminders_json'] as List)
        : [];

    // Supabase might return JSONB columns as actual Lists/Maps instead of Strings
    // We check both plural (standard) and singular (potential leftover) variations
    dynamic suppsRaw = map['added_supplements_json'] ?? map['added_supplement_json'];
    String? suppsJson = (suppsRaw is List || suppsRaw is Map) ? jsonEncode(suppsRaw) : suppsRaw as String?;

    dynamic stacksRaw = map['added_stacks_json'] ?? map['added_stack_json'];
    String? stacksJson = (stacksRaw is List || stacksRaw is Map) ? jsonEncode(stacksRaw) : stacksRaw as String?;

    return SavedMeal(
      id: map['id'] as String,
      name: map['name'] as String,
      foodItems: map['food_items'] as String,
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble(),
      fats: (map['fats'] as num?)?.toDouble(),
      isPinnedToHome: map['is_pinned_to_home'] == true || map['is_pinned_to_home'] == 1,
      notificationsEnabled: map['notifications_enabled'] == true || map['notifications_enabled'] == 1,
      reminders: decodedReminders
          .map((r) => CalorieReminder.fromMap(r as Map<String, dynamic>))
          .toList(),
      addedSupplementsJson: suppsJson,
      addedStacksJson: stacksJson,
      servings: (map['servings'] as num?)?.toDouble() ?? 1.0,
      sharedBy: map['shared_by'] as String?,
      multiplySupps: map['multiply_supps'] == null || map['multiply_supps'] == true || map['multiply_supps'] == 1,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
    );
  }

  SavedMeal copyWith({
    String? id,
    String? name,
    String? foodItems,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    bool? isPinnedToHome,
    bool? notificationsEnabled,
    List<CalorieReminder>? reminders,
    String? addedSupplementsJson,
    bool clearSupplements = false,
    String? addedStacksJson,
    bool clearStacks = false,
    double? servings,
    bool? multiplySupps,
    String? sharedBy,
    int? isSynced,
  }) {
    return SavedMeal(
      id: id ?? this.id,
      name: name ?? this.name,
      foodItems: foodItems ?? this.foodItems,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      isPinnedToHome: isPinnedToHome ?? this.isPinnedToHome,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminders: reminders ?? this.reminders,
      addedSupplementsJson: clearSupplements ? null : (addedSupplementsJson ?? this.addedSupplementsJson),
      addedStacksJson: clearStacks ? null : (addedStacksJson ?? this.addedStacksJson),
      servings: servings ?? this.servings,
      multiplySupps: multiplySupps ?? this.multiplySupps,
      sharedBy: sharedBy ?? this.sharedBy,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
