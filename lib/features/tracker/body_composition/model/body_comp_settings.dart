// lib/features/tracker/body_composition/model/body_comp_settings.dart

import 'package:heavy_duty/features/tracker/cycle_tracker/model/cycle_settings.dart';

enum HeightUnit { cm, ftIn }

class BodyCompSettings {
  final WeightUnit weightUnit;
  final HeightUnit heightUnit;
  final int isSynced;

  BodyCompSettings({
    this.weightUnit = WeightUnit.kgs,
    this.heightUnit = HeightUnit.cm,
    this.isSynced = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'weight_unit': weightUnit.name,
      'height_unit': heightUnit.name,
      'is_synced': isSynced,
    };
  }

  factory BodyCompSettings.fromMap(Map<String, dynamic> map) {
    return BodyCompSettings(
      weightUnit: WeightUnit.values.firstWhere(
        (e) => e.name == map['weight_unit'],
        orElse: () => WeightUnit.kgs,
      ),
      heightUnit: HeightUnit.values.firstWhere(
        (e) => e.name == map['height_unit'],
        orElse: () => HeightUnit.cm,
      ),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
    );
  }

  BodyCompSettings copyWith({
    WeightUnit? weightUnit,
    HeightUnit? heightUnit,
    int? isSynced,
  }) {
    return BodyCompSettings(
      weightUnit: weightUnit ?? this.weightUnit,
      heightUnit: heightUnit ?? this.heightUnit,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
