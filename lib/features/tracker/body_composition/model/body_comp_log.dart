import 'package:uuid/uuid.dart';

enum BodyMetricType { weight, fat, muscle }
enum BodyMetricUnit { kg, percentage, lbs }

class BodyCompLog {
  final String id;
  final String? userId;
  final double valueKg; // Also stores percentage if unit is percentage
  final double valueLbs; // Also stores percentage if unit is percentage
  final BodyMetricType type;
  final BodyMetricUnit unit;
  final DateTime timestamp;
  final int isSynced;
  final DateTime? updatedAt;

  BodyCompLog({
    String? id,
    this.userId,
    required this.valueKg,
    required this.valueLbs,
    required this.type,
    required this.unit,
    required this.timestamp,
    this.isSynced = 1,
    this.updatedAt,
  }) : id = id ?? const Uuid().v4();

  // For backward compatibility and internal calculations
  double get value => valueKg;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'value_kg': valueKg,
      'value_lbs': valueLbs,
      'unit': unit.name,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
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
      userId: map['user_id']?.toString(),
      valueKg: vKg,
      valueLbs: vLbs,
      type: type,
      unit: unit,
      timestamp: DateTime.parse(map['timestamp'].toString()),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  BodyCompLog copyWith({
    String? id,
    String? userId,
    double? valueKg,
    double? valueLbs,
    BodyMetricType? type,
    BodyMetricUnit? unit,
    DateTime? timestamp,
    int? isSynced,
    DateTime? updatedAt,
  }) {
    return BodyCompLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      valueKg: valueKg ?? this.valueKg,
      valueLbs: valueLbs ?? this.valueLbs,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
