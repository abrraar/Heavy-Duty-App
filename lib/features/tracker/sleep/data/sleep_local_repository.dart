// lib/features/tracker/sleep/data/sleep_local_repository.dart

import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/sleep_log.dart';
import '../model/sleep_settings.dart';

class SleepLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SleepLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  // --- Settings ---

  Future<SleepSettings?> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('sleep_settings', where: 'user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return SleepSettings.fromMap(maps.first);
    return null;
  }

  Future<void> saveSettings(SleepSettings settings, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final results = await db.query('sleep_settings', where: 'user_id = ?', whereArgs: [userId]);
      if (results.isNotEmpty) {
        final localIsSynced = results.first['is_synced'] as int;
        final localUpdatedAt = results.first['updated_at'] != null 
            ? DateTime.tryParse(results.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (settings.updatedAt != null && localUpdatedAt != null && settings.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    await db.insert('sleep_settings', settings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertLog(SleepLog log, {bool isFromCloud = false}) async {
    final db = await _getDatabase();
    final logWithUser = log.copyWith(userId: userId);

    if (isFromCloud) {
      final existing = await db.query('sleep_logs', where: 'id = ?', whereArgs: [log.id]);
      if (existing.isNotEmpty) {
        final localIsSynced = existing.first['is_synced'] as int;
        final localUpdatedAt = existing.first['updated_at'] != null 
            ? DateTime.tryParse(existing.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (log.updatedAt != null && localUpdatedAt != null && log.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    await db.insert('sleep_logs', logWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await _getDatabase();
    await db.delete('sleep_logs', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<List<SleepLog>> getAllLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'sleep_logs', 
      where: 'user_id = ?', 
      whereArgs: [userId],
      orderBy: 'bedtime DESC'
    );
    return maps.map((map) => SleepLog.fromMap(map)).toList();
  }

  Future<int> getUnsyncedCount() async {
    final db = await _getDatabase();
    final logs = await db.rawQuery('SELECT COUNT(*) as cnt FROM sleep_logs WHERE is_synced = 0 AND user_id = ?', [userId]);
    final dels = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_deletions WHERE user_id = ? AND table_name = ?', [userId, 'sleep_logs']);
    
    return (Sqflite.firstIntValue(logs) ?? 0) + 
           (Sqflite.firstIntValue(dels) ?? 0);
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
    return await db.query(
      'pending_deletions', 
      where: 'user_id = ? AND table_name = ?', 
      whereArgs: [userId, 'sleep_logs']
    );
  }

  Future<List<SleepLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('sleep_logs', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => SleepLog.fromMap(map)).toList();
  }

  Future<void> markLogSynced(String id) async {
    final db = await _getDatabase();
    await db.update('sleep_logs', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

}
