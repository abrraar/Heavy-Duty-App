import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/body_comp_log.dart';
import '../model/body_comp_settings.dart';

class BodyCompLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  BodyCompLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  String _getTableName(BodyMetricType type) {
    switch (type) {
      case BodyMetricType.weight: return 'body_comp_weight_logs';
      case BodyMetricType.fat: return 'body_comp_fats_logs';
      case BodyMetricType.muscle: return 'body_comp_muscle_logs';
    }
  }

  // --- Settings ---

  Future<BodyCompSettings> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('body_comp_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) {
      return BodyCompSettings.fromMap(maps.first);
    }
    final defaultSettings = BodyCompSettings(userId: userId);
    await saveSettings(defaultSettings);
    return defaultSettings;
  }

  Future<void> saveSettings(BodyCompSettings settings) async {
    final db = await _getDatabase();
    final settingsWithUser = settings.copyWith(userId: userId);
    final map = settingsWithUser.toMap();
    map['id'] = 1;
    await db.insert('body_comp_settings', map, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- Logs ---

  Future<List<BodyCompLog>> getAllLogs() async {
    final db = await _getDatabase();
    
    final List<BodyCompLog> allLogs = [];
    
    for (var type in BodyMetricType.values) {
      final List<Map<String, dynamic>> maps = await db.query(
        _getTableName(type), 
        where: 'user_id = ?', 
        whereArgs: [userId],
        orderBy: 'timestamp DESC'
      );
      allLogs.addAll(maps.map((map) => BodyCompLog.fromMap(map, type)));
    }
    
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<void> insertLog(BodyCompLog log, {bool isFromCloud = false}) async {
    final db = await _getDatabase();
    final logWithUser = log.copyWith(userId: userId);

    if (isFromCloud) {
      final existingLog = await db.query(_getTableName(log.type), where: 'id = ?', whereArgs: [log.id]);
      if (existingLog.isNotEmpty) {
        final localIsSynced = existingLog.first['is_synced'] as int;
        final localUpdatedAt = existingLog.first['updated_at'] != null 
            ? DateTime.tryParse(existingLog.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (log.updatedAt != null && localUpdatedAt != null && log.updatedAt!.isBefore(localUpdatedAt)) return;
      }
    }

    await db.insert(_getTableName(log.type), logWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id, BodyMetricType type) async {
    final db = await _getDatabase();
    await db.delete(_getTableName(type), where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<int> getUnsyncedCount() async {
    final db = await _getDatabase();
    int count = 0;
    for (var type in BodyMetricType.values) {
      final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM ${_getTableName(type)} WHERE is_synced = 0 AND user_id = ?', [userId]);
      count += Sqflite.firstIntValue(res) ?? 0;
    }
    final settings = await db.rawQuery('SELECT COUNT(*) as cnt FROM body_comp_settings WHERE is_synced = 0 AND user_id = ?', [userId]);
    count += Sqflite.firstIntValue(settings) ?? 0;
    
    final dels = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_deletions WHERE user_id = ? AND table_name IN (?, ?, ?)', [userId, 'body_comp_weight_logs', 'body_comp_fats_logs', 'body_comp_muscle_logs']);
    count += Sqflite.firstIntValue(dels) ?? 0;
    
    return count;
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
    return await db.query('pending_deletions', where: "user_id = ? AND table_name IN ('body_comp_weight_logs', 'body_comp_fats_logs', 'body_comp_muscle_logs')", whereArgs: [userId]);
  }

  Future<List<BodyCompLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<BodyCompLog> unsynced = [];
    
    for (var type in BodyMetricType.values) {
      final List<Map<String, dynamic>> maps = await db.query(_getTableName(type), where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
      unsynced.addAll(maps.map((map) => BodyCompLog.fromMap(map, type)));
    }
    return unsynced;
  }

  Future<BodyCompSettings?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('body_comp_settings', where: 'is_synced = 0 AND id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return BodyCompSettings.fromMap(maps.first);
    return null;
  }

  Future<void> markLogSynced(String id, BodyMetricType type) async {
    final db = await _getDatabase();
    await db.update(_getTableName(type), {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('body_comp_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

}
