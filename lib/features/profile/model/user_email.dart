import 'package:uuid/uuid.dart';

class UserEmail {
  final String id;
  final String email;
  final bool isVerified;
  final int isSynced;
  final String? userId;

  UserEmail({
    String? id,
    required this.email,
    this.isVerified = false,
    this.isSynced = 1,
    this.userId,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'email': email,
      'is_verified': isVerified ? 1 : 0,
      'is_synced': isSynced,
    };
  }

  factory UserEmail.fromMap(Map<String, dynamic> map) {
    return UserEmail(
      id: map['id'],
      userId: map['user_id'],
      email: map['email'],
      // Support both boolean (from Supabase) and integer (from SQLite)
      isVerified: map['is_verified'] == 1 || map['is_verified'] == true,
      isSynced: map['is_synced'] ?? 1,
    );
  }

  UserEmail copyWith({
    String? id,
    String? email,
    bool? isVerified,
    int? isSynced,
    String? userId,
  }) {
    return UserEmail(
      id: id ?? this.id,
      email: email ?? this.email,
      isVerified: isVerified ?? this.isVerified,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
    );
  }
}

