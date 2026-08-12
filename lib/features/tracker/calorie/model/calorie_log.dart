import 'dart:convert';
import 'package:uuid/uuid.dart';

class CalorieLog {
  final String id;
  final String mealName;
  final String foodItems;
  final double calories;
  final double? protein;
  final double? carbs;
  final double? fats;
  final DateTime timestamp;
  final int isSynced;
  final String? addedSupplementsJson;
  final String? addedStacksJson;
  final double servings;

  CalorieLog({
    String? id,
    required this.mealName,
    required this.foodItems,
    required this.calories,
    this.protein,
    this.carbs,
    this.fats,
    DateTime? timestamp,
    this.isSynced = 1,
    this.addedSupplementsJson,
    this.addedStacksJson,
    this.servings = 1.0,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'meal_name': mealName,
      'food_items': foodItems,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
      'added_supplements_json': addedSupplementsJson,
      'added_stacks_json': addedStacksJson,
      'servings': servings,
    };
  }

  factory CalorieLog.fromMap(Map<String, dynamic> map) {
    // Supabase might return JSONB columns as actual Lists/Maps instead of Strings
    // Check for both plural (standard) and singular variations
    dynamic suppsRaw = map['added_supplements_json'] ?? map['added_supplement_json'];
    String? suppsJson = (suppsRaw is List || suppsRaw is Map) ? jsonEncode(suppsRaw) : suppsRaw as String?;

    dynamic stacksRaw = map['added_stacks_json'] ?? map['added_stack_json'];
    String? stacksJson = (stacksRaw is List || stacksRaw is Map) ? jsonEncode(stacksRaw) : stacksRaw as String?;

    return CalorieLog(
      id: map['id'] as String,
      mealName: map['meal_name'] as String,
      foodItems: map['food_items'] as String,
      calories: (map['calories'] as num).toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble(),
      fats: (map['fats'] as num?)?.toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      addedSupplementsJson: suppsJson,
      addedStacksJson: stacksJson,
      servings: (map['servings'] as num?)?.toDouble() ?? 1.0,
    );
  }

  CalorieLog copyWith({
    String? id,
    String? mealName,
    String? foodItems,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    DateTime? timestamp,
    int? isSynced,
    String? addedSupplementsJson,
    bool clearSupplements = false,
    String? addedStacksJson,
    bool clearStacks = false,
    double? servings,
  }) {
    return CalorieLog(
      id: id ?? this.id,
      mealName: mealName ?? this.mealName,
      foodItems: foodItems ?? this.foodItems,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      addedSupplementsJson: clearSupplements ? null : (addedSupplementsJson ?? this.addedSupplementsJson),
      addedStacksJson: clearStacks ? null : (addedStacksJson ?? this.addedStacksJson),
      servings: servings ?? this.servings,
    );
  }
}
