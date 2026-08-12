import 'package:sqflite/sqflite.dart';
import 'package:heavy_duty/core/database/database_helper.dart';
import '../model/affirmation.dart';
import '../model/affirmation_settings.dart';

class AffirmationLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  AffirmationLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  Future<List<Affirmation>> getAllAffirmations() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('affirmations', orderBy: 'display_order ASC, created_at DESC');
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  // --- Settings ---
  Future<AffirmationSettings> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('affirmation_settings', where: 'id = 1');
    if (maps.isNotEmpty) {
      return AffirmationSettings.fromMap(maps.first);
    }
    return AffirmationSettings();
  }

  Future<void> saveSettings(AffirmationSettings settings) async {
    final db = await _getDatabase();
    final data = settings.toMap();
    data['id'] = 1;
    await db.insert('affirmation_settings', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateAffirmationOrder(List<Affirmation> affirmations) async {
    final db = await _getDatabase();
    await db.transaction((txn) async {
      for (int i = 0; i < affirmations.length; i++) {
        await txn.update(
          'affirmations',
          {'display_order': i},
          where: 'id = ?',
          whereArgs: [affirmations[i].id],
        );
      }
    });
  }

  Future<void> insertAffirmation(Affirmation affirmation) async {
    final db = await _getDatabase();
    await db.insert('affirmations', affirmation.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteAffirmation(String id) async {
    final db = await _getDatabase();
    await db.delete('affirmations', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Affirmation>> getUnsyncedAffirmations() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('affirmations', where: 'is_synced = 0');
    return maps.map((map) => Affirmation.fromMap(map)).toList();
  }

  Future<void> markAffirmationSynced(String id) async {
    final db = await _getDatabase();
    await db.update('affirmations', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addToDeletionQueue(String id, String tableName) async {
    final db = await _getDatabase();
    await db.insert('pending_deletions', {'id': id, 'table_name': tableName},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromDeletionQueue(String id) async {
    final db = await _getDatabase();
    await db.delete('pending_deletions', where: 'id = ?', whereArgs: [id]);
  }
}
