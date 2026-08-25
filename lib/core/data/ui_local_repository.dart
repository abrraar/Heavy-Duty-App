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

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final db = await _db;
    final data = Map<String, dynamic>.from(settings);
    data['user_id'] = userId;
    await db.insert(
      'home_widget_settings',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> markSettingsSynced() async {
    final db = await _db;
    await db.update('home_widget_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

}
