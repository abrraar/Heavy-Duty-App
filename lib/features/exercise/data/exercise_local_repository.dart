import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../model/exercise_template.dart';

class ExerciseLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  ExerciseLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  Future<List<ExerciseTemplate>> getAllTemplates() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'exercise_templates', 
      where: 'user_id = ?', 
      whereArgs: [userId],
      orderBy: 'name ASC'
    );
    return maps.map((map) => ExerciseTemplate.fromMap(map)).toList();
  }

  Future<void> insertTemplate(ExerciseTemplate template, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final existing = await db.query('exercise_templates', where: 'id = ?', whereArgs: [template.id]);
      if (existing.isNotEmpty) {
        final localIsSynced = existing.first['is_synced'] as int;
        final localUpdatedAt = existing.first['updated_at'] != null 
            ? DateTime.tryParse(existing.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (template.updatedAt != null && localUpdatedAt != null && template.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    final templateWithUser = template.copyWith(userId: userId);
    await db.insert('exercise_templates', templateWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTemplate(String id) async {
    final db = await _getDatabase();
    await db.delete('exercise_templates', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markTemplateSynced(String id) async {
    final db = await _getDatabase();
    await db.update('exercise_templates', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<ExerciseTemplate>> getUnsyncedTemplates() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('exercise_templates', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => ExerciseTemplate.fromMap(map)).toList();
  }

  Future<int> getUnsyncedCount() async {
    final db = await _getDatabase();
    final temps = await db.rawQuery('SELECT COUNT(*) as cnt FROM exercise_templates WHERE is_synced = 0 AND user_id = ?', [userId]);
    final dels = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_deletions WHERE user_id = ? AND table_name = ?', [userId, 'exercise_templates']);
    
    return (Sqflite.firstIntValue(temps) ?? 0) + (Sqflite.firstIntValue(dels) ?? 0);
  }

  // --- Deletion Queue ---

  Future<void> addToDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.insert('pending_deletions', {
      'id': id,
      'user_id': userId,
      'table_name': 'exercise_templates'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.delete('pending_deletions', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await _getDatabase();
    return await db.query('pending_deletions', where: 'table_name = ? AND user_id = ?', whereArgs: ['exercise_templates', userId]);
  }

}
