import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/body_comp_log.dart';

class BodyCompLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  BodyCompLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  String _getTableName(BodyMetricType type) {
    switch (type) {
      case BodyMetricType.weight: return 'weight_logs';
      case BodyMetricType.fat: return 'body_fat_logs';
      case BodyMetricType.muscle: return 'muscle_mass_logs';
    }
  }

  Future<List<BodyCompLog>> getAllLogs() async {
    final db = await _getDatabase();
    
    final List<BodyCompLog> allLogs = [];
    
    for (var type in BodyMetricType.values) {
      final List<Map<String, dynamic>> maps = await db.query(_getTableName(type), orderBy: 'timestamp DESC');
      allLogs.addAll(maps.map((map) => BodyCompLog.fromMap(map, type)));
    }
    
    allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allLogs;
  }

  Future<void> insertLog(BodyCompLog log) async {
    final db = await _getDatabase();
    await db.insert(_getTableName(log.type), log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id, BodyMetricType type) async {
    final db = await _getDatabase();
    await db.delete(_getTableName(type), where: 'id = ?', whereArgs: [id]);
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
    return await db.query('pending_deletions', where: "table_name IN ('weight_logs', 'body_fat_logs', 'muscle_mass_logs')");
  }

  Future<List<BodyCompLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<BodyCompLog> unsynced = [];
    
    for (var type in BodyMetricType.values) {
      final List<Map<String, dynamic>> maps = await db.query(_getTableName(type), where: 'is_synced = 0');
      unsynced.addAll(maps.map((map) => BodyCompLog.fromMap(map, type)));
    }
    return unsynced;
  }

  Future<void> markLogSynced(String id, BodyMetricType type) async {
    final db = await _getDatabase();
    await db.update(_getTableName(type), {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }
}
