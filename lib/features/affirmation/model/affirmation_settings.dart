class AffirmationSettings {
  final int rotationMinutes;
  final String rotationMode; // 'random', 'alternative', 'continuous'
  final String orderDirection; // 'asc', 'desc'
  final bool showSystem;
  final bool showCustom;
  final int isSynced;
  final DateTime? updatedAt;
  final String? userId;

  AffirmationSettings({
    this.rotationMinutes = 60,
    this.rotationMode = 'random',
    this.orderDirection = 'asc',
    this.showSystem = true,
    this.showCustom = true,
    this.isSynced = 1,
    this.updatedAt,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'rotation_minutes': rotationMinutes,
      'rotation_mode': rotationMode,
      'order_direction': orderDirection,
      'show_system': showSystem ? 1 : 0,
      'show_custom': showCustom ? 1 : 0,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory AffirmationSettings.fromMap(Map<String, dynamic> map) {
    return AffirmationSettings(
      rotationMinutes: map['rotation_minutes'] as int? ?? 60,
      rotationMode: map['rotation_mode'] as String? ?? 'random',
      orderDirection: map['order_direction'] as String? ?? 'asc',
      showSystem: map['show_system'] == null || map['show_system'] == 1 || map['show_system'] == true,
      showCustom: map['show_custom'] == null || map['show_custom'] == 1 || map['show_custom'] == true,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
      userId: map['user_id'] as String?,
    );
  }

  AffirmationSettings copyWith({
    int? rotationMinutes,
    String? rotationMode,
    String? orderDirection,
    bool? showSystem,
    bool? showCustom,
    int? isSynced,
    DateTime? updatedAt,
    String? userId,
  }) {
    return AffirmationSettings(
      rotationMinutes: rotationMinutes ?? this.rotationMinutes,
      rotationMode: rotationMode ?? this.rotationMode,
      orderDirection: orderDirection ?? this.orderDirection,
      showSystem: showSystem ?? this.showSystem,
      showCustom: showCustom ?? this.showCustom,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
    );
  }
}

