// lib/features/tracker/sleep/model/sleep_log.dart

import 'package:flutter/material.dart';

enum SleepType { night, nap }

class SleepLog {
  final String id;
  final DateTime bedtime;
  final DateTime wakeUpTime;
  final int quality; // 1 to 5
  final SleepType type;
  final String note;
  final int isSynced;

  SleepLog({
    required this.id,
    required this.bedtime,
    required this.wakeUpTime,
    required this.quality,
    this.type = SleepType.night,
    this.note = "",
    this.isSynced = 1,
  });

  Duration get duration => wakeUpTime.difference(bedtime);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bedtime': bedtime.toIso8601String(),
      'wake_up_time': wakeUpTime.toIso8601String(),
      'quality': quality,
      'type': type.name,
      'note': note,
      'is_synced': isSynced,
    };
  }

  factory SleepLog.fromMap(Map<String, dynamic> map) {
    return SleepLog(
      id: map['id'] as String,
      bedtime: DateTime.parse(map['bedtime'] as String),
      wakeUpTime: DateTime.parse(map['wake_up_time'] as String),
      quality: map['quality'] as int,
      type: SleepType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => SleepType.night,
      ),
      note: map['note'] as String? ?? "",
      isSynced: map['is_synced'] ?? 1,
    );
  }

  SleepLog copyWith({
    DateTime? bedtime,
    DateTime? wakeUpTime,
    int? quality,
    SleepType? type,
    String? note,
    int? isSynced,
  }) {
    return SleepLog(
      id: this.id,
      bedtime: bedtime ?? this.bedtime,
      wakeUpTime: wakeUpTime ?? this.wakeUpTime,
      quality: quality ?? this.quality,
      type: type ?? this.type,
      note: note ?? this.note,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
