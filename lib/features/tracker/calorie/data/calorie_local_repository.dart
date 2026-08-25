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
    final List<Map<String, dynamic>> maps = await db.query(
      'calorie_meal_logs', 
      where: 'user_id = ?', 
      whereArgs: [userId],
      orderBy: 'timestamp DESC'
    );
    return maps.map((map) => CalorieLog.fromMap(map)).toList();
  }

  Future<void> insertLog(CalorieLog log) async {
    final db = await _getDatabase();
    final logWithUser = log.copyWith(userId: userId);
    await db.insert('calorie_meal_logs', logWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await _getDatabase();
    await db.delete('calorie_meal_logs', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // --- Settings ---

  Future<CalorieSettings> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) {
      return CalorieSettings.fromMap(maps.first);
    }
    return CalorieSettings(userId: userId);
  }

  Future<void> saveSettings(CalorieSettings settings) async {
    final db = await _getDatabase();
    final settingsWithUser = settings.copyWith(userId: userId);
    final data = settingsWithUser.toMap();
    data['id'] = 1;
    await db.insert('calorie_settings', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Saved Meals ---

  Future<List<SavedMeal>> getSavedMeals() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'calorie_meals', 
      where: 'user_id = ?', 
      whereArgs: [userId],
      orderBy: 'name ASC'
    );
    return maps.map((map) => SavedMeal.fromMap(map)).toList();
  }

  Future<void> insertSavedMeal(SavedMeal meal) async {
    final db = await _getDatabase();
    final mealWithUser = meal.copyWith(userId: userId);
    await db.insert('calorie_meals', mealWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSavedMeal(String id) async {
    final db = await _getDatabase();
    await db.delete('calorie_meals', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // --- Sync Helpers ---

  Future<void> addToDeletionQueue(String id, String tableName) async {
    final db = await _getDatabase();
    await db.insert('pending_deletions', {'id': id, 'user_id': userId, 'table_name': tableName},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.delete('pending_deletions', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    final db = await _getDatabase();
    return await db.query('pending_deletions', where: 'user_id = ?', whereArgs: [userId]);
  }

  Future<List<CalorieLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_meal_logs', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => CalorieLog.fromMap(map)).toList();
  }

  Future<CalorieSettings?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_settings', where: 'is_synced = 0 AND id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return CalorieSettings.fromMap(maps.first);
    return null;
  }

  Future<List<SavedMeal>> getUnsyncedSavedMeals() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('calorie_meals', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => SavedMeal.fromMap(map)).toList();
  }

  Future<void> markLogSynced(String id) async {
    final db = await _getDatabase();
    await db.update('calorie_meal_logs', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markSavedMealSynced(String id) async {
    final db = await _getDatabase();
    await db.update('calorie_meals', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('calorie_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

}
