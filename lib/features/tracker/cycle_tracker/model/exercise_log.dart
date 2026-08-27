import 'package:uuid/uuid.dart';

class ExerciseLog {
  final String id;
  final String exerciseId;
  final double weightKg;
  final double weightLbs;
  final int positiveReps;
  final int staticHoldSeconds;
  final int negativeReps;
  final int forcedReps;
  final String? comment;
  final DateTime timestamp;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  ExerciseLog({
    String? id,
    required this.exerciseId,
    required this.weightKg,
    required this.weightLbs,
    required this.positiveReps,
    this.staticHoldSeconds = 0,
    this.negativeReps = 0,
    this.forcedReps = 0,
    this.comment,
    DateTime? timestamp,
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'exercise_id': exerciseId,
      'weight_kg': weightKg,
      'weight_lbs': weightLbs,
      'positive_reps': positiveReps,
      'static_hold_seconds': staticHoldSeconds,
      'negative_reps': negativeReps,
      'forced_reps': forcedReps,
      'comment': comment,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory ExerciseLog.fromMap(Map<String, dynamic> map) {
    // Migration helper: If new columns don't exist yet, fallback to old 'weight'
    double? wKg = (map['weight_kg'] as num?)?.toDouble();
    double? wLbs = (map['weight_lbs'] as num?)?.toDouble();
    
    if (wKg == null || wLbs == null) {
      double legacyWeight = (map['weight'] as num? ?? 0.0).toDouble();
      // Assume legacy was lbs as per current logic
      wLbs = legacyWeight;
      wKg = legacyWeight / 2.205;
    }

    return ExerciseLog(
      id: map['id']?.toString() ?? const Uuid().v4(),
      userId: map['user_id']?.toString(),
      exerciseId: map['exercise_id']?.toString() ?? "",
      weightKg: wKg,
      weightLbs: wLbs,
      positiveReps: (map['positive_reps'] as num?)?.toInt() ?? 0,
      staticHoldSeconds: (map['static_hold_seconds'] as num?)?.toInt() ?? 0,
      negativeReps: (map['negative_reps'] as num?)?.toInt() ?? 0,
      forcedReps: (map['forced_reps'] as num?)?.toInt() ?? 0,
      comment: map['comment']?.toString(),
      timestamp: DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now(),
      isSynced: map['is_synced'] ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  ExerciseLog copyWith({
    String? id,
    String? exerciseId,
    double? weightKg,
    double? weightLbs,
    int? positiveReps,
    int? staticHoldSeconds,
    int? negativeReps,
    int? forcedReps,
    String? Function()? comment,
    DateTime? Function()? timestamp,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return ExerciseLog(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      weightKg: weightKg ?? this.weightKg,
      weightLbs: weightLbs ?? this.weightLbs,
      positiveReps: positiveReps ?? this.positiveReps,
      staticHoldSeconds: staticHoldSeconds ?? this.staticHoldSeconds,
      negativeReps: negativeReps ?? this.negativeReps,
      forcedReps: forcedReps ?? this.forcedReps,
      comment: comment != null ? comment() : this.comment,
      timestamp: timestamp != null ? timestamp() ?? DateTime.now() : this.timestamp,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}

