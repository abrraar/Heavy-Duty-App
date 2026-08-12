// lib/features/tracker/hydration/model/hydration_log.dart

class HydrationLog {
  final String id;
  final int amount; // in ml
  final DateTime timestamp;
  final int isSynced;

  HydrationLog({
    required this.id,
    required this.amount,
    required this.timestamp,
    this.isSynced = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory HydrationLog.fromMap(Map<String, dynamic> map) {
    return HydrationLog(
      id: map['id'] as String,
      amount: map['amount'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: map['is_synced'] ?? 1,
    );
  }

  HydrationLog copyWith({
    String? id,
    int? amount,
    DateTime? timestamp,
    int? isSynced,
  }) {
    return HydrationLog(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
