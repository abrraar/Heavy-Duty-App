// lib/features/tracker/supplement/data/supplement_local_repository.dart

import 'dart:convert';
import 'package:heavy_duty/features/tracker/supplement/model/supplement_item.dart';
import 'package:heavy_duty/features/tracker/supplement/model/supplement_settings.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/supplement.dart';
import '../model/supplement_stack.dart';

class SupplementLocalRepository {
  final String userId; // Added to scope repository to user
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  SupplementLocalRepository({required this.userId});
  

  // Helper method to get the specific DB for this user
  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }
  // ==========================================
  // 1. GLOBAL SUPPLEMENT OPERATION METHODS
  // ==========================================

  /// Updates only the stock column value inside the local SQLite database
  Future<void> updateSupplementStock(
    String supplementId,
    double newStockAmount,
  ) async {
    final db = await _getDatabase();

    await db.update(
      'ss_supplements', // Aligned table name
      {'remaining_stock': newStockAmount},
      where: 'id = ?',
      whereArgs: [supplementId],
    );
  }

  /// Fetch all raw supplements saved in the database library
  Future<List<Supplement>> getAllSupplements() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'ss_supplements',
    ); // Aligned table name

    return maps.map((map) => Supplement.fromMap(map)).toList();
  }

  /// Inserts or replaces a supplement model entry into local memory
  Future<void> saveSupplement(Supplement supplement) async {
    final db = await _getDatabase();
    await db.insert(
      'ss_supplements', // Aligned table name
      supplement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Completely drops a supplement item from the inventory catalog
  Future<void> deleteSupplement(String id) async {
    final db = await _getDatabase();
    await db.delete(
      'ss_supplements',
      where: 'id = ?',
      whereArgs: [id],
    ); // Aligned table name
  }

  // ==========================================
  // 2. HISTORY / LOGGING METHODS
  // ==========================================

  /// Inserts a new operational intake or restock item log into the history ledger
  Future<void> insertSupplementItem(SupplementItem entry) async {
    final db = await _getDatabase();
    await db.insert(
      'ss_records', // Aligned table name
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Updates the synchronization status flag to true (1) following a backend push
  Future<void> markHistoryAsSynced(String id) async {
    final db = await _getDatabase();
    await db.update(
      'ss_records', // Aligned table name
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a specific history entry (used primarily for Undo rollback requests)
  Future<void> deleteSupplementItem(String id) async {
    final db = await _getDatabase();
    await db.delete(
      'ss_records',
      where: 'id = ?',
      whereArgs: [id],
    ); // Aligned table name
  }

  /// Retrieves all local history logs from the database, ordered by timestamp
  Future<List<SupplementItem>> getAllHistory() async {
    final db = await _getDatabase();

    final List<Map<String, dynamic>> maps = await db.query(
      'ss_records',
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) => SupplementItem.fromMap(map)).toList();
  }

  /// Retrieves all local history logs that have not been synced to the cloud yet
  Future<List<SupplementItem>> getUnsyncedHistory() async {
    final db = await _getDatabase();

    final List<Map<String, dynamic>> maps = await db.query(
      'ss_records', // Aligned table name
      where: 'is_synced = ?',
      whereArgs: [0], // Pull rows where is_synced is false/0
    );

    return maps.map((map) => SupplementItem.fromMap(map)).toList();
  }

  // ==========================================
  // 3. STACK / ROUTINE METHODS
  // ==========================================

  /// Fetch all routine stacks saved locally
  Future<List<SupplementStack>> getAllStacks(
    List<Supplement> allSupplements,
  ) async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'ss_stack',
    ); // Aligned table name

    return maps.map((stackMap) {
      final String? idsJson = stackMap['supplement_ids_json'] as String?;
      final List<dynamic> targetIds = idsJson != null ? jsonDecode(idsJson) : [];

      List<Supplement> associatedItems = targetIds.map((id) {
        return allSupplements.firstWhere(
          (supp) => supp.id == id,
          orElse:
              () => Supplement(
                id: id,
                name: "Deleted Item",
                servingUnit: "",
                weightPerServing: 0,
                weightUnit: "",
                isActive: false,
              ),
        );
      }).toList();

      return SupplementStack.fromMap(stackMap, associatedItems);
    }).toList();
  }

  /// Saves or alters a custom predefined combination routine stack structure
  Future<void> saveStack(SupplementStack stack) async {
    final db = await _getDatabase();
    await db.insert(
      'ss_stack', // Aligned table name
      stack.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deletes a custom combination routine stack layout completely
  Future<void> deleteStack(String id) async {
    final db = await _getDatabase();
    await db.delete(
      'ss_stack',
      where: 'id = ?',
      whereArgs: [id],
    ); // Aligned table name
  }

  // ==========================================
  // 4. SETTINGS METHODS
  // ==========================================

  Future<SupplementSettings?> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('ss_settings', where: 'id = 1');
    if (maps.isNotEmpty) return SupplementSettings.fromMap(maps.first);
    return null;
  }

  Future<void> saveSettings(SupplementSettings settings) async {
    final db = await _getDatabase();
    await db.insert('ss_settings', settings.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
