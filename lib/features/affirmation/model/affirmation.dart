import 'package:uuid/uuid.dart';

class Affirmation {
  final String id;
  final String text;
  final bool isCustom;
  final DateTime createdAt;
  final int isSynced;

  final int displayOrder;

  Affirmation({
    String? id,
    required this.text,
    this.isCustom = true,
    DateTime? createdAt,
    this.isSynced = 1,
    this.displayOrder = 0,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'is_custom': isCustom ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      'display_order': displayOrder,
    };
  }

  factory Affirmation.fromMap(Map<String, dynamic> map) {
    return Affirmation(
      id: map['id'] as String,
      text: map['text'] as String,
      isCustom: map['is_custom'] == 1 || map['is_custom'] == true,
      createdAt: DateTime.parse(map['created_at'] as String),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      displayOrder: (map['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  Affirmation copyWith({
    String? id,
    String? text,
    bool? isCustom,
    DateTime? createdAt,
    int? isSynced,
    int? displayOrder,
  }) {
    return Affirmation(
      id: id ?? this.id,
      text: text ?? this.text,
      isCustom: isCustom ?? this.isCustom,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      displayOrder: displayOrder ?? this.displayOrder,
    );
  }
}
