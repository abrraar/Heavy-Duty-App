// lib/features/tracker/hydration/model/hydration_log.dart

class HydrationLog {
  final String id;
  final int amountMl;
  final double amountOz;
  final DateTime timestamp;
  final int isSynced;
  final String? userId;

  HydrationLog({
    required this.id,
    required this.amountMl,
    required this.amountOz,
    required this.timestamp,
    this.isSynced = 1,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount_ml': amountMl,
      'amount_oz': amountOz,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory HydrationLog.fromMap(Map<String, dynamic> map) {
    int? ml = map['amount_ml'] as int?;
    double? oz = (map['amount_oz'] as num?)?.toDouble();

    if (ml == null || oz == null) {
      // Legacy fallback
      ml = map['amount'] as int? ?? 0;
      oz = ml * 0.03;
    }

    return HydrationLog(
      id: map['id'] as String,
      amountMl: ml,
      amountOz: oz,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: map['is_synced'] ?? 1,
      userId: map['user_id'] as String?,
    );
  }

  HydrationLog copyWith({
    String? id,
    int? amountMl,
    double? amountOz,
    DateTime? timestamp,
    int? isSynced,
    String? userId,
  }) {
    return HydrationLog(
      id: id ?? this.id,
      amountMl: amountMl ?? this.amountMl,
      amountOz: amountOz ?? this.amountOz,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
    );
  }
}

