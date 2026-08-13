import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/calorie_log.dart';
import '../model/calorie_settings.dart';
import '../model/saved_meal.dart';

class CalorieLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CalorieLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  // --- Logs ---

  Future<List<CalorieLog>> getAllLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_meal_logs', orderBy: 'timestamp DESC');
    return maps.map((map) => CalorieLog.fromMap(map)).toList();
  }

  Future<void> insertLog(CalorieLog log) async {
    final db = await _getDatabase();
    await db.insert('calorie_meal_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await _getDatabase();
    await db.delete('calorie_meal_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- Settings ---

  Future<CalorieSettings> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_settings', where: 'id = 1');
    if (maps.isNotEmpty) {
      return CalorieSettings.fromMap(maps.first);
    }
    return CalorieSettings();
  }

  Future<void> saveSettings(CalorieSettings settings) async {
    final db = await _getDatabase();
    final data = settings.toMap();
    data['id'] = 1;
    await db.insert('calorie_settings', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Saved Meals ---

  Future<List<SavedMeal>> getSavedMeals() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_meals', orderBy: 'name ASC');
    return maps.map((map) => SavedMeal.fromMap(map)).toList();
  }

  Future<void> insertSavedMeal(SavedMeal meal) async {
    final db = await _getDatabase();
    await db.insert('calorie_meals', meal.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSavedMeal(String id) async {
    final db = await _getDatabase();
    await db.delete('calorie_meals', where: 'id = ?', whereArgs: [id]);
  }

  // --- Sync Helpers ---

  Future<void> addToDeletionQueue(String id, String tableName) async {
    final db = await _getDatabase();
    await db.insert('pending_deletions', {'id': id, 'table_name': tableName},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.delete('pending_deletions', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await _getDatabase();
    return await db.query('pending_deletions');
  }

  Future<List<CalorieLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_meal_logs', where: 'is_synced = 0');
    return maps.map((map) => CalorieLog.fromMap(map)).toList();
  }

  Future<CalorieSettings?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_settings', where: 'is_synced = 0 AND id = 1');
    if (maps.isNotEmpty) return CalorieSettings.fromMap(maps.first);
    return null;
  }

  Future<List<SavedMeal>> getUnsyncedSavedMeals() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_meals', where: 'is_synced = 0');
    return maps.map((map) => SavedMeal.fromMap(map)).toList();
  }

  Future<void> markLogSynced(String id) async {
    final db = await _getDatabase();
    await db.update('calorie_meal_logs', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSavedMealSynced(String id) async {
    final db = await _getDatabase();
    await db.update('calorie_meals', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('calorie_settings', {'is_synced': 1}, where: 'id = 1');
  }
}
