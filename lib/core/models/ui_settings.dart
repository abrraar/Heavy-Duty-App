import 'dart:convert';

class UiSettings {
  final List<String> homeLayout;
  final int isSynced;

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
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'home_layout_json': jsonEncode(homeLayout),
      'is_synced': isSynced,
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
    );
  }

  UiSettings copyWith({
    List<String>? homeLayout,
    int? isSynced,
  }) {
    return UiSettings(
      homeLayout: homeLayout ?? this.homeLayout,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
