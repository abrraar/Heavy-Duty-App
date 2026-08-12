import 'package:uuid/uuid.dart';

enum BodyMetricType { weight, fat, muscle }

enum BodyMetricUnit { kg, percentage }

class BodyCompLog {
  final String id;
  final double value;
  final BodyMetricType type;
  final BodyMetricUnit unit;
  final DateTime timestamp;
  final int isSynced;

  BodyCompLog({
    String? id,
    required this.value,
    required this.type,
    this.unit = BodyMetricUnit.kg,
    DateTime? timestamp,
    this.isSynced = 1,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'value': value,
      'unit': unit.name,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory BodyCompLog.fromMap(Map<String, dynamic> map, BodyMetricType type) {
    return BodyCompLog(
      id: map['id'] as String,
      value: (map['value'] as num).toDouble(),
      type: type,
      unit: map['unit'] != null 
          ? BodyMetricUnit.values.firstWhere((u) => u.name == map['unit'], orElse: () => BodyMetricUnit.kg)
          : (type == BodyMetricType.weight ? BodyMetricUnit.kg : BodyMetricUnit.percentage),
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: map['is_synced'] ?? 1,
    );
  }

  BodyCompLog copyWith({
    String? id,
    double? value,
    BodyMetricType? type,
    BodyMetricUnit? unit,
    DateTime? timestamp,
    int? isSynced,
  }) {
    return BodyCompLog(
      id: id ?? this.id,
      value: value ?? this.value,
      type: type ?? this.type,
      unit: unit ?? this.unit,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
