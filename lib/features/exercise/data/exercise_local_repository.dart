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
    final List<Map<String, dynamic>> maps = await db.query('exercise_templates', orderBy: 'name ASC');
    return maps.map((map) => ExerciseTemplate.fromMap(map)).toList();
  }

  Future<void> insertTemplate(ExerciseTemplate template) async {
    final db = await _getDatabase();
    await db.insert('exercise_templates', template.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteTemplate(String id) async {
    final db = await _getDatabase();
    await db.delete('exercise_templates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markTemplateSynced(String id) async {
    final db = await _getDatabase();
    await db.update('exercise_templates', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ExerciseTemplate>> getUnsyncedTemplates() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('exercise_templates', where: 'is_synced = 0');
    return maps.map((map) => ExerciseTemplate.fromMap(map)).toList();
  }

  // --- Deletion Queue ---

  Future<void> addToDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.insert('pending_deletions', {
      'id': id,
      'table_name': 'exercise_templates'
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.delete('pending_deletions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await _getDatabase();
    return await db.query('pending_deletions', where: 'table_name = ?', whereArgs: ['exercise_templates']);
  }
}
