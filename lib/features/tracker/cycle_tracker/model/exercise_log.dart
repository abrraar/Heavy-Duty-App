import 'package:uuid/uuid.dart';

class ExerciseLog {
  final String id;
  final String exerciseId;
  final double weight;
  final int positiveReps;
  final int staticHoldSeconds;
  final int negativeReps;
  final int forcedReps;
  final String? comment;
  final DateTime timestamp;
  final int isSynced;

  ExerciseLog({
    String? id,
    required this.exerciseId,
    required this.weight,
    required this.positiveReps,
    this.staticHoldSeconds = 0,
    this.negativeReps = 0,
    this.forcedReps = 0,
    this.comment,
    DateTime? timestamp,
    this.isSynced = 1,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'weight': weight,
      'positive_reps': positiveReps,
      'static_hold_seconds': staticHoldSeconds,
      'negative_reps': negativeReps,
      'forced_reps': forcedReps,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
    };
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map) {
    return ExerciseLog(
      id: map['id']?.toString() ?? const Uuid().v4(),
      exerciseId: map['exercise_id']?.toString() ?? "",
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
      positiveReps: (map['positive_reps'] as num?)?.toInt() ?? 0,
      staticHoldSeconds: (map['static_hold_seconds'] as num?)?.toInt() ?? 0,
      negativeReps: (map['negative_reps'] as num?)?.toInt() ?? 0,
      forcedReps: (map['forced_reps'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString(),
      timestamp: DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
      isSynced: map['is_synced'] ?? 1,
    );
  }

  ExerciseLog copyWith({
    String? id,
    String? exerciseId,
    double? weight,
    int? positiveReps,
    int? staticHoldSeconds,
    int? negativeReps,
    int? forcedReps,
    String? comment,
    DateTime? timestamp,
    int? isSynced,
  }) {
    return ExerciseLog(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      weight: weight ?? this.weight,
      positiveReps: positiveReps ?? this.positiveReps,
      staticHoldSeconds: staticHoldSeconds ?? this.staticHoldSeconds,
      negativeReps: negativeReps ?? this.negativeReps,
      forcedReps: forcedReps ?? this.forcedReps,
      comment: comment ?? this.comment,
      timestamp: timestamp ?? this.timestamp,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
