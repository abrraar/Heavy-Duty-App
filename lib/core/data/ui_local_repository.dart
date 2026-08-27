import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class UiLocalRepository {
  final String userId;

  UiLocalRepository({required this.userId});

  Future<Database> get _db async => await DatabaseHelper.instance.getDatabaseForUser(userId);

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await _db;
    final results = await db.query('home_widget_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (results.isNotEmpty) return results.first;
    return null;
  }

  Future<void> saveSettings(Map<String, dynamic> settings, {bool isFromCloud = false}) async {
    final db = await _db;

    if (isFromCloud) {
      final results = await db.query('home_widget_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
      if (results.isNotEmpty) {
        final localIsSynced = results.first['is_synced'] as int;
        final localUpdatedAt = results.first['updated_at'] != null 
            ? DateTime.tryParse(results.first['updated_at'].toString()) 
            : null;
        
        final cloudUpdatedAt = settings['updated_at'] != null 
            ? DateTime.tryParse(settings['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) {
          debugPrint("Repo: [SYNC-CONFLICT] UI Settings are dirty locally. Skipping cloud overwrite.");
          return;
        }
        if (cloudUpdatedAt != null && localUpdatedAt != null && cloudUpdatedAt.isBefore(localUpdatedAt)) {
          debugPrint("Repo: [SYNC-CONFLICT] Local UI Settings are newer. Skipping cloud overwrite.");
          return;
        }
      }
    }

    final data = Map<String, dynamic>.from(settings);
    data['user_id'] = userId;
    data['id'] = 1; // Force singleton ID
    await db.insert(
      'home_widget_settings',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getUnsyncedCount() async {
    final db = await _db;
    final res = await db.rawQuery('SELECT COUNT(*) as cnt FROM home_widget_settings WHERE is_synced = 0 AND user_id = ?', [userId]);
    return Sqflite.firstIntValue(res) ?? 0;
  }

  Future<void> markSettingsSynced() async {
    final db = await _db;
    await db.update('home_widget_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

}
