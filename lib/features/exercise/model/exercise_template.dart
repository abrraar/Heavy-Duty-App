import 'package:uuid/uuid.dart';

enum ExerciseType { isolation, compound }

class ExerciseTemplate {
  final String id;
  final String name;
  final String? targetMuscles;
  final int intensity; // 1-5
  final bool isDefault;
  final ExerciseType type;
  final String? imageUrl;
  final String? aboutTheMovement;
  final String? sharedBy;
  final int isSynced;
  
  // IN-MEMORY CACHE: For dynamic UI adjustments
  double? aspectRatio;

  ExerciseTemplate({
    String? id,
    required this.name,
    this.targetMuscles,
    this.intensity = 3,
    this.isDefault = false,
    this.type = ExerciseType.isolation,
    this.imageUrl,
    this.aboutTheMovement,
    this.sharedBy,
    this.isSynced = 1,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'target_muscles': targetMuscles,
      'intensity': intensity,
      'is_default': isDefault ? 1 : 0,
      'type': type.name,
      'image_url': imageUrl,
      'about_the_movement': aboutTheMovement,
      'shared_by': sharedBy,
      'is_synced': isSynced,
    };
  }

  factory ExerciseTemplate.fromMap(Map<String, dynamic> map) {
    final isDefaultVal = map['is_default'];
    bool isDefaultBool = false;
    if (isDefaultVal is int) {
      isDefaultBool = isDefaultVal == 1;
    } else if (isDefaultVal is bool) {
      isDefaultBool = isDefaultVal;
    }

    return ExerciseTemplate(
      id: map['id'] as String,
      name: map['name'] as String,
      targetMuscles: map['target_muscles'] as String?,
      intensity: map['intensity'] as int? ?? 3,
      isDefault: isDefaultBool,
      type: ExerciseType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'isolation'),
        orElse: () => ExerciseType.isolation,
      ),
      imageUrl: map['image_url'] as String?,
      aboutTheMovement: map['about_the_movement'] as String?,
      sharedBy: map['shared_by'] as String?,
      isSynced: map['is_synced'] as int? ?? 1,
    );
  }

  ExerciseTemplate copyWith({
    String? name,
    String? targetMuscles,
    int? intensity,
    bool? isDefault,
    ExerciseType? type,
    String? imageUrl,
    String? aboutTheMovement,
    String? sharedBy,
    int? isSynced,
  }) {
    return ExerciseTemplate(
      id: this.id,
      name: name ?? this.name,
      targetMuscles: targetMuscles ?? this.targetMuscles,
      intensity: intensity ?? this.intensity,
      isDefault: isDefault ?? this.isDefault,
      type: type ?? this.type,
      imageUrl: imageUrl ?? this.imageUrl,
      aboutTheMovement: aboutTheMovement ?? this.aboutTheMovement,
      sharedBy: sharedBy ?? this.sharedBy,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
