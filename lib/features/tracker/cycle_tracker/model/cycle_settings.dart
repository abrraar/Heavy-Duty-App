import 'dart:convert';
import 'package:flutter/foundation.dart';

enum WeightUnit { lbs, kgs }

class CycleSettings {
  final WeightUnit weightUnit;
  final Set<String> visibleMetrics;
  final int isSynced;

  CycleSettings({
    this.weightUnit = WeightUnit.lbs,
    this.visibleMetrics = const {"strength", "volume"},
    this.isSynced = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'weight_unit': weightUnit.name,
      'visible_metrics_json': jsonEncode(visibleMetrics.toList()),
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
      isSynced: map['is_synced'] ?? 1,
    );
  }

  CycleSettings copyWith({
    WeightUnit? weightUnit,
    Set<String>? visibleMetrics,
    int? isSynced,
  }) {
    return CycleSettings(
      weightUnit: weightUnit ?? this.weightUnit,
      visibleMetrics: visibleMetrics ?? this.visibleMetrics,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
