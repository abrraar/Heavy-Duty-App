// lib/features/tracker/hydration/data/hydration_local_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/hydration_log.dart';
import '../model/hydration_settings.dart';

class HydrationLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  HydrationLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  // --- Logs ---

  Future<void> insertLog(HydrationLog log) async {
    final db = await _getDatabase();
    final logWithUser = log.copyWith(userId: userId);
    await db.insert('hydration_logs', logWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await _getDatabase();
    await db.delete('hydration_logs', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<HydrationLog>> getAllLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'hydration_logs', 
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC'
    );
    return maps.map((map) => HydrationLog.fromMap(map)).toList();
  }

  Future<List<HydrationLog>> getLogsForDate(DateTime date) async {
    final db = await _getDatabase();
    final startOfDay = DateTime(date.year, date.month, date.day).toIso8601String();
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).toIso8601String();
    
    final List<Map<String, dynamic>> maps = await db.query(
      'hydration_logs',
      where: 'timestamp >= ? AND timestamp <= ? AND user_id = ?',
      whereArgs: [startOfDay, endOfDay, userId],
      orderBy: 'timestamp DESC',
    );
    return maps.map((map) => HydrationLog.fromMap(map)).toList();
  }

  // --- Settings ---

  Future<HydrationSettings> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('hydration_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) {
      return HydrationSettings.fromMap(maps.first);
    }
    // Default settings if none found
    final defaultSettings = HydrationSettings(userId: userId);
    await saveSettings(defaultSettings);
    return defaultSettings;
  }

  Future<void> saveSettings(HydrationSettings settings) async {
    final db = await _getDatabase();
    final settingsWithUser = settings.copyWith(userId: userId);
    final map = settingsWithUser.toMap();
    map['id'] = 1;
    await db.insert('hydration_settings', map, conflictAlgorithm: ConflictAlgorithm.replace);
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

  Future<List<HydrationLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('hydration_logs', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => HydrationLog.fromMap(map)).toList();
  }

  Future<HydrationSettings?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('hydration_settings', where: 'is_synced = 0 AND id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return HydrationSettings.fromMap(maps.first);
    return null;
  }

  Future<void> markLogSynced(String id) async {
    final db = await _getDatabase();
    await db.update('hydration_logs', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('hydration_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

}
