// lib/features/tracker/body_composition/model/body_comp_log.dart

enum BodyMetricType { weight, fat, muscle }
enum BodyMetricUnit { kg, percentage, lbs }

class BodyCompLog {
  final String id;
  final double valueKg; // Also stores percentage if unit is percentage
  final double valueLbs; // Also stores percentage if unit is percentage
  final BodyMetricType type;
  final BodyMetricUnit unit;
  final DateTime timestamp;
  final int isSynced;

  BodyCompLog({
    String? id,
    required this.valueKg,
    required this.valueLbs,
    required this.type,
    required this.unit,
    required this.timestamp,
    this.isSynced = 1,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  // For backward compatibility and internal calculations
  double get value => valueKg;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'value_kg': valueKg,
      'value_lbs': valueLbs,
      'unit': unit.name,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory BodyCompLog.fromMap(Map<String, dynamic> map, BodyMetricType type) {
    double? vKg = (map['value_kg'] as num?)?.toDouble();
    double? vLbs = (map['value_lbs'] as num?)?.toDouble();
    final unit = BodyMetricUnit.values.firstWhere(
      (e) => e.name == (map['unit'] ?? 'kg'),
      orElse: () => BodyMetricUnit.kg,
    );

    if (vKg == null || vLbs == null) {
      double legacyValue = (map['value'] as num? ?? 0.0).toDouble();
      vKg = legacyValue;
      if (unit == BodyMetricUnit.percentage) {
        vLbs = legacyValue;
      } else {
        // Assume legacy was kg as per current logic
        vLbs = legacyValue * 2.205;
      }
    }

    return BodyCompLog(
      id: map['id']?.toString(),
      valueKg: vKg,
      valueLbs: vLbs,
      type: type,
      unit: unit,
      timestamp: DateTime.parse(map['timestamp'].toString()),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
    );
  }

  BodyCompLog copyWith({
    String? id,
    double? valueKg,
    double? valueLbs,
    BodyMetricType? type,
    BodyMetricUnit? unit,
    DateTime? timestamp,
    int? isSynced,
  }) {
    return BodyCompLog(
      id: id ?? this.id,
      valueKg: valueKg ?? this.valueKg,
      valueLbs: valueLbs ?? this.valueLbs,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
