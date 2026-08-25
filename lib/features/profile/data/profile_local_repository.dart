import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../model/profile_model.dart';
import '../model/user_email.dart';

class ProfileLocalRepository {
  final String userId;
  ProfileLocalRepository({required this.userId});

  Future<Database> _getDb() => DatabaseHelper.instance.getDatabaseForUser(userId);

  Future<List<UserEmail>> getEmails() async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps = await db.query('user_emails', where: 'user_id = ?', whereArgs: [userId]);
    return List.generate(maps.length, (i) => UserEmail.fromMap(maps[i]));
  }

  Future<void> insertEmail(UserEmail email) async {
    final db = await _getDb();
    final emailWithUser = email.copyWith(userId: userId);
    await db.insert('user_emails', emailWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteEmail(String id) async {
    final db = await _getDb();
    await db.delete('user_emails', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> updateEmail(UserEmail email) async {
    final db = await _getDb();
    final emailWithUser = email.copyWith(userId: userId);
    await db.update('user_emails', emailWithUser.toMap(), where: 'id = ? AND user_id = ?', whereArgs: [email.id, userId]);
  }

  // --- Profile Management ---

  Future<UserProfile?> getProfile() async {
    final db = await _getDb();
    final List<Map<String, dynamic>> maps = await db.query('profiles', where: 'user_id = ?', whereArgs: [userId], limit: 1);
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  Future<void> saveProfile(UserProfile profile) async {
    final db = await _getDb();
    final profileWithUser = profile.copyWith(userId: userId);
    await db.insert('profiles', profileWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

}
