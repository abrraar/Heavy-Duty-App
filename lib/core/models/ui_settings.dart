import 'dart:convert';

class UiSettings {
  final List<String> homeLayout;
  final int isSynced;
  final DateTime? updatedAt;

  UiSettings({
    this.homeLayout = const [
      'meal_log',
      'supplement_log',
      'stack_log',
      'water',
      'cycle_status',
      'metrics',
      'workout_action',
    ],
    this.isSynced = 1,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'home_layout_json': jsonEncode(homeLayout),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UiSettings.fromMap(Map<String, dynamic> map) {
    return UiSettings(
      homeLayout: map['home_layout_json'] != null
          ? List<String>.from(jsonDecode(map['home_layout_json']))
          : [
              'meal_log',
              'supplement_log',
              'stack_log',
              'water',
              'cycle_status',
              'metrics',
              'workout_action',
            ],
      isSynced: map['is_synced'] ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  UiSettings copyWith({
    List<String>? homeLayout,
    int? isSynced,
    DateTime? updatedAt,
  }) {
    return UiSettings(
      homeLayout: homeLayout ?? this.homeLayout,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
