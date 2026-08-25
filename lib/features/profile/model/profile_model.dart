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
    );
  }
}

