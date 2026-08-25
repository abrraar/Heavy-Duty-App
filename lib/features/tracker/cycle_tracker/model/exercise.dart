import 'package:uuid/uuid.dart';

class Exercise {
  final String id;
  final String workoutId;
  final String name;
  final int order;
  final String? targetMuscles;
  final int isSynced;
  final String? userId;

  Exercise({
    String? id,
    required this.workoutId,
    required this.name,
    required this.order,
    this.targetMuscles,
    this.isSynced = 1,
    this.userId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'workout_id': workoutId,
      'name': name,
      'exercise_order': order,
      'target_muscles': targetMuscles,
      'is_synced': isSynced,
    };
  }

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id']?.toString() ?? const Uuid().v4(),
      userId: map['user_id']?.toString(),
      workoutId: map['workout_id']?.toString() ?? "",
      name: map['name']?.toString() ?? "Untitled Exercise",
      order: (map['exercise_order'] as num?)?.toInt() ?? 0,
      targetMuscles: map['target_muscles']?.toString(),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise.fromMap(json);

  Exercise copyWith({
    String? id,
    String? workoutId,
    String? name,
    int? order,
    String? targetMuscles,
    int? isSynced,
    String? userId,
  }) {
    return Exercise(
      id: id ?? this.id,
      workoutId: workoutId ?? this.workoutId,
      name: name ?? this.name,
      order: order ?? this.order,
      targetMuscles: targetMuscles ?? this.targetMuscles,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
    );
  }
}

