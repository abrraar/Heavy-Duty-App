class CalorieSettings {
  final int dailyCalorieGoal;
  final int proteinPercent;
  final int carbPercent;
  final int fatPercent;
  final bool trackMacros;
  final bool showRemaining;
  final int isSynced;

  CalorieSettings({
    this.dailyCalorieGoal = 2800,
    this.proteinPercent = 30,
    this.carbPercent = 50,
    this.fatPercent = 20,
    this.trackMacros = true,
    this.showRemaining = true,
    this.isSynced = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'daily_calorie_goal': dailyCalorieGoal,
      'protein_percent': proteinPercent,
      'carb_percent': carbPercent,
      'fat_percent': fatPercent,
      'track_macros': trackMacros ? 1 : 0,
      'show_remaining': showRemaining ? 1 : 0,
      'is_synced': isSynced,
    };
  }

  factory CalorieSettings.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return true; // Default
    }

    return CalorieSettings(
      dailyCalorieGoal: (map['daily_calorie_goal'] as num?)?.toInt() ?? 2800,
      proteinPercent: (map['protein_percent'] as num?)?.toInt() ?? 30,
      carbPercent: (map['carb_percent'] as num?)?.toInt() ?? 50,
      fatPercent: (map['fat_percent'] as num?)?.toInt() ?? 20,
      trackMacros: parseBool(map['track_macros']),
      showRemaining: parseBool(map['show_remaining']),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
    );
  }

  CalorieSettings copyWith({
    int? dailyCalorieGoal,
    int? proteinPercent,
    int? carbPercent,
    int? fatPercent,
    bool? trackMacros,
    bool? showRemaining,
    int? isSynced,
  }) {
    return CalorieSettings(
      dailyCalorieGoal: dailyCalorieGoal ?? this.dailyCalorieGoal,
      proteinPercent: proteinPercent ?? this.proteinPercent,
      carbPercent: carbPercent ?? this.carbPercent,
      fatPercent: fatPercent ?? this.fatPercent,
      trackMacros: trackMacros ?? this.trackMacros,
      showRemaining: showRemaining ?? this.showRemaining,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
