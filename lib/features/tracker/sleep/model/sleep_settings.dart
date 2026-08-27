// lib/features/tracker/sleep/model/sleep_settings.dart

class SleepSettings {
  final String userId;
  final bool use24HourClock;
  final int isSynced;
  final DateTime? updatedAt;
  final DateTime? createdAt;

  SleepSettings({
    required this.userId,
    this.use24HourClock = false,
    this.isSynced = 1,
    this.updatedAt,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'use_24h_clock': use24HourClock ? 1 : 0,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  factory SleepSettings.fromMap(Map<String, dynamic> map) {
    return SleepSettings(
      userId: map['user_id'] ?? '',
      use24HourClock: (map['use_24h_clock'] as num? ?? 0) == 1,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
    );
  }

  SleepSettings copyWith({
    String? userId,
    bool? use24HourClock,
    int? isSynced,
    DateTime? updatedAt,
    DateTime? createdAt,
  }) {
    return SleepSettings(
      userId: userId ?? this.userId,
      use24HourClock: use24HourClock ?? this.use24HourClock,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
