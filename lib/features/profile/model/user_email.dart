import 'package:uuid/uuid.dart';

class UserEmail {
  final String id;
  final String email;
  final bool isVerified;
  final int isSynced;

  UserEmail({
    String? id,
    required this.email,
    this.isVerified = false,
    this.isSynced = 1,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'is_verified': isVerified ? 1 : 0,
      'is_synced': isSynced,
    };
  }

  factory UserEmail.fromMap(Map<String, dynamic> map) {
    return UserEmail(
      id: map['id'],
      email: map['email'],
      isVerified: map['is_verified'] == 1,
      isSynced: map['is_synced'] ?? 1,
    );
  }

  UserEmail copyWith({
    String? id,
    String? email,
    bool? isVerified,
    int? isSynced,
  }) {
    return UserEmail(
      id: id ?? this.id,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
