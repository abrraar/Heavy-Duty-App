class AffirmationSettings {
  final int rotationMinutes;
  final String rotationMode; // 'random', 'alternative', 'continuous'
  final String orderDirection; // 'asc', 'desc'
  final bool showSystem;
  final bool showCustom;
  final int isSynced;

  AffirmationSettings({
    this.rotationMinutes = 60,
    this.rotationMode = 'random',
    this.orderDirection = 'asc',
    this.showSystem = true,
    this.showCustom = true,
    this.isSynced = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'rotation_minutes': rotationMinutes,
      'rotation_mode': rotationMode,
      'order_direction': orderDirection,
      'show_system': showSystem ? 1 : 0,
      'show_custom': showCustom ? 1 : 0,
      'is_synced': isSynced,
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
    );
  }

  AffirmationSettings copyWith({
    int? rotationMinutes,
    String? rotationMode,
    String? orderDirection,
    bool? showSystem,
    bool? showCustom,
    int? isSynced,
  }) {
    return AffirmationSettings(
      rotationMinutes: rotationMinutes ?? this.rotationMinutes,
      rotationMode: rotationMode ?? this.rotationMode,
      orderDirection: orderDirection ?? this.orderDirection,
      showSystem: showSystem ?? this.showSystem,
      showCustom: showCustom ?? this.showCustom,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
