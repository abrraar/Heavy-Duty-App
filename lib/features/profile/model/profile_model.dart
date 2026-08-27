class UserProfile {
  final String id;
  final String? userId;
  final String? fullName;
  final String? username;
  final DateTime? birthday;
  final String? gender;
  final double? height;
  final double? weight;
  final int isSynced;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    this.userId,
    this.fullName,
    this.username,
    this.birthday,
    this.gender,
    this.height,
    this.weight,
    this.isSynced = 1,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'username': username,
      'birthday': birthday?.toIso8601String(),
      'gender': gender,
      'height': height,
      'weight': weight,
      'is_synced': isSynced,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      userId: map['user_id'],
      fullName: map['full_name'],
      username: map['username'],
      birthday: map['birthday'] != null ? DateTime.tryParse(map['birthday']) : null,
      gender: map['gender'],
      height: (map['height'] as num?)?.toDouble(),
      weight: (map['weight'] as num?)?.toDouble(),
      isSynced: map['is_synced'] ?? 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  UserProfile copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? username,
    DateTime? birthday,
    String? gender,
    double? height,
    double? weight,
    int? isSynced,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

