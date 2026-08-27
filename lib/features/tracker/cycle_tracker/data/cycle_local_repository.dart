import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../../core/database/database_helper.dart';
import '../model/training_cycle.dart';
import '../model/workout.dart';
import '../model/exercise.dart';
import '../model/exercise_log.dart';

class CycleLocalRepository {
  final String userId;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  CycleLocalRepository({required this.userId});

  Future<Database> _getDatabase() async {
    return await _dbHelper.getDatabaseForUser(userId);
  }

  // --- Cycles ---

  Future<List<TrainingCycle>> getAllCycles() async {
    final db = await _getDatabase();
    
    // 1. Fetch Cycles
    final List<Map<String, dynamic>> cycleMaps = await db.query(
      'hit_cycles', 
      where: 'user_id = ?', 
      whereArgs: [userId]
    );
    
    List<TrainingCycle> cycles = [];
    
    for (var cycleMap in cycleMaps) {
      final cycleId = cycleMap['id'] as String;
      
      // 2. Fetch Workouts for this cycle
      final List<Map<String, dynamic>> workoutMaps = await db.query(
        'hit_workouts', 
        where: 'cycle_id = ? AND user_id = ?', 
        whereArgs: [cycleId, userId],
        orderBy: 'workout_order ASC'
      );
      
      List<Workout> workouts = [];
      for (var workoutMap in workoutMaps) {
        final workoutId = workoutMap['id'] as String;
        
        // 3. Fetch Exercises for this workout
        final List<Map<String, dynamic>> exerciseMaps = await db.query(
          'hit_exercises', 
          where: 'workout_id = ? AND user_id = ?', 
          whereArgs: [workoutId, userId],
          orderBy: 'exercise_order ASC'
        );
        
        final exercises = exerciseMaps.map((e) => Exercise.fromMap(e)).toList();
        workouts.add(Workout.fromMap(workoutMap, exercises));
      }
      
      cycles.add(TrainingCycle.fromMap(cycleMap, workouts));
    }
    
    return cycles;
  }

  Future<void> insertCycle(TrainingCycle cycle, {bool isFromCloud = false}) async {
    final db = await _getDatabase();
    
    await db.transaction((txn) async {
      // 0. Fetch Global Pending Deletions to protect local state
      final pendingDels = await txn.query('pending_deletions', where: 'user_id = ?', whereArgs: [userId]);
      final pendingIds = pendingDels.map((d) => d['id'] as String).toSet();

      if (isFromCloud && pendingIds.contains(cycle.id)) {
        debugPrint("Repo: [SYNC-CONFLICT] Blocking cloud insert of deleted Cycle ${cycle.id}");
        return;
      }

      // 1. Sync Cycle Header
      final existingCycle = await txn.query('hit_cycles', where: 'id = ?', whereArgs: [cycle.id]);
      if (isFromCloud && existingCycle.isNotEmpty) {
        final localIsSynced = existingCycle.first['is_synced'] as int;
        final localUpdatedAt = existingCycle.first['updated_at'] != null 
            ? DateTime.tryParse(existingCycle.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) {
          debugPrint("Repo: [SYNC-CONFLICT] Cycle ${cycle.id} is dirty locally. Skipping cloud overwrite.");
        } else if (cycle.updatedAt != null && localUpdatedAt != null && cycle.updatedAt!.isBefore(localUpdatedAt)) {
          debugPrint("Repo: [SYNC-CONFLICT] Local Cycle ${cycle.id} is newer. Skipping cloud overwrite.");
        } else {
          debugPrint("Repo: [SYNC] Updating Cycle ${cycle.id} from cloud.");
          await txn.insert('hit_cycles', cycle.copyWith(userId: userId).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      } else {
        await txn.insert('hit_cycles', cycle.copyWith(userId: userId).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      
      // 2. Sync Workouts (Delete synced orphans then insert)
      final workoutIds = cycle.workouts.map((w) => w.id).toList();
      if (isFromCloud) {
        if (workoutIds.isNotEmpty) {
          await txn.delete(
            'hit_workouts',
            where: 'cycle_id = ? AND user_id = ? AND is_synced = 1 AND id NOT IN (${workoutIds.map((_) => '?').join(',')})',
            whereArgs: [cycle.id, userId, ...workoutIds],
          );
        } else {
          await txn.delete('hit_workouts', where: 'cycle_id = ? AND user_id = ? AND is_synced = 1', whereArgs: [cycle.id, userId]);
        }
      }

      for (var workout in cycle.workouts) {
        if (isFromCloud && pendingIds.contains(workout.id)) {
          debugPrint("Repo: Blocking cloud re-insertion of deleted Workout ${workout.id}");
          continue;
        }

        final existingWorkout = await txn.query('hit_workouts', where: 'id = ?', whereArgs: [workout.id]);
        if (isFromCloud && existingWorkout.isNotEmpty) {
          final localIsSynced = existingWorkout.first['is_synced'] as int;
          final localUpdatedAt = existingWorkout.first['updated_at'] != null 
              ? DateTime.tryParse(existingWorkout.first['updated_at'].toString()) 
              : null;

          if (localIsSynced == 0) {
            debugPrint("Repo: Workout ${workout.id} is dirty. Skipping cloud overwrite.");
            continue;
          } else if (workout.updatedAt != null && localUpdatedAt != null && workout.updatedAt!.isBefore(localUpdatedAt)) {
            debugPrint("Repo: Local Workout ${workout.id} is newer. Skipping cloud overwrite.");
            continue;
          }
        }
        await txn.insert('hit_workouts', workout.copyWith(userId: userId).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        
        // 3. Sync Exercises
        final exerciseIds = workout.exercises.map((e) => e.id).toList();
        if (isFromCloud) {
          if (exerciseIds.isNotEmpty) {
            await txn.delete(
              'hit_exercises',
              where: 'workout_id = ? AND user_id = ? AND is_synced = 1 AND id NOT IN (${exerciseIds.map((_) => '?').join(',')})',
              whereArgs: [workout.id, userId, ...exerciseIds],
            );
          } else {
            await txn.delete('hit_exercises', where: 'workout_id = ? AND user_id = ? AND is_synced = 1', whereArgs: [workout.id, userId]);
          }
        }

        for (var exercise in workout.exercises) {
          if (isFromCloud && pendingIds.contains(exercise.id)) {
            debugPrint("Repo: Blocking cloud re-insertion of deleted Exercise ${exercise.id}");
            continue;
          }

          final existingEx = await txn.query('hit_exercises', where: 'id = ?', whereArgs: [exercise.id]);
          if (isFromCloud && existingEx.isNotEmpty) {
            final localIsSynced = existingEx.first['is_synced'] as int;
            final localUpdatedAt = existingEx.first['updated_at'] != null 
                ? DateTime.tryParse(existingEx.first['updated_at'].toString()) 
                : null;

            if (localIsSynced == 0) {
              debugPrint("Repo: Exercise ${exercise.id} is dirty. Skipping cloud overwrite.");
              continue;
            } else if (exercise.updatedAt != null && localUpdatedAt != null && exercise.updatedAt!.isBefore(localUpdatedAt)) {
              debugPrint("Repo: Local Exercise ${exercise.id} is newer. Skipping cloud overwrite.");
              continue;
            }
          }
          await txn.insert('hit_exercises', exercise.copyWith(userId: userId).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> deleteCycle(String id) async {
    final db = await _getDatabase();
    // ON DELETE CASCADE in SQLite handles Workouts and Exercises if set up correctly, 
    // but we can be explicit if needed. DatabaseHelper has foreign_keys = ON.
    await db.delete('hit_cycles', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // --- Granular Updates ---

  Future<void> insertWorkout(Workout workout) async {
    final db = await _getDatabase();
    final workoutWithUser = workout.copyWith(userId: userId);
    await db.insert('hit_workouts', workoutWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertExercise(Exercise exercise) async {
    final db = await _getDatabase();
    final exerciseWithUser = exercise.copyWith(userId: userId);
    await db.insert('hit_exercises', exerciseWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteWorkout(String id) async {
    final db = await _getDatabase();
    await db.delete('hit_workouts', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> deleteExercise(String id) async {
    final db = await _getDatabase();
    await db.delete('hit_exercises', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // --- Logs ---

  Future<List<ExerciseLog>> getAllLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query(
      'exercise_logs', 
      where: 'user_id = ?', 
      whereArgs: [userId],
      orderBy: 'timestamp DESC'
    );
    return maps.map((map) => ExerciseLog.fromMap(map)).toList();
  }

  Future<void> insertLog(ExerciseLog log, {bool isFromCloud = false}) async {
    final db = await _getDatabase();
    final logWithUser = log.copyWith(userId: userId);

    if (isFromCloud) {
      final existingLog = await db.query('exercise_logs', where: 'id = ?', whereArgs: [log.id]);
      if (existingLog.isNotEmpty) {
        final localIsSynced = existingLog.first['is_synced'] as int;
        final localUpdatedAt = existingLog.first['updated_at'] != null 
            ? DateTime.tryParse(existingLog.first['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) {
          debugPrint("Repo: [SYNC-CONFLICT] Exercise Log ${log.id} is dirty locally. Skipping cloud overwrite.");
          return;
        }
        if (log.updatedAt != null && localUpdatedAt != null && log.updatedAt!.isBefore(localUpdatedAt)) {
          debugPrint("Repo: [SYNC-CONFLICT] Local Exercise Log ${log.id} is newer. Skipping cloud overwrite.");
          return;
        }
      }
    }

    await db.insert('exercise_logs', logWithUser.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await _getDatabase();
    await db.delete('exercise_logs', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  // --- Settings ---

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('hit_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> saveSettings(Map<String, dynamic> settings, {bool isFromCloud = false}) async {
    final db = await _getDatabase();

    if (isFromCloud) {
      final results = await db.query('hit_settings', where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
      if (results.isNotEmpty) {
        final localIsSynced = results.first['is_synced'] as int;
        final localUpdatedAt = results.first['updated_at'] != null 
            ? DateTime.tryParse(results.first['updated_at'].toString()) 
            : null;
        
        final cloudUpdatedAt = settings['updated_at'] != null 
            ? DateTime.tryParse(settings['updated_at'].toString()) 
            : null;

        if (localIsSynced == 0) return; // Dirty locally
        if (cloudUpdatedAt != null && localUpdatedAt != null && cloudUpdatedAt.isBefore(localUpdatedAt)) return;
      }
    }

    final settingsMap = Map<String, dynamic>.from(settings);
    settingsMap['user_id'] = userId;
    settingsMap['id'] = 1;
    await db.insert('hit_settings', settingsMap, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> getUnsyncedCount() async {
    final db = await _getDatabase();
    final cycles = await db.rawQuery('SELECT COUNT(*) as cnt FROM hit_cycles WHERE is_synced = 0 AND user_id = ?', [userId]);
    final logs = await db.rawQuery('SELECT COUNT(*) as cnt FROM exercise_logs WHERE is_synced = 0 AND user_id = ?', [userId]);
    final settings = await db.rawQuery('SELECT COUNT(*) as cnt FROM hit_settings WHERE is_synced = 0 AND user_id = ?', [userId]);
    final dels = await db.rawQuery('SELECT COUNT(*) as cnt FROM pending_deletions WHERE user_id = ? AND table_name IN (?, ?, ?, ?)', [userId, 'hit_cycles', 'hit_workouts', 'hit_exercises', 'exercise_logs']);
    
    return (Sqflite.firstIntValue(cycles) ?? 0) + 
           (Sqflite.firstIntValue(logs) ?? 0) + 
           (Sqflite.firstIntValue(settings) ?? 0) + 
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
      where: 'user_id = ? AND table_name IN (?, ?, ?, ?)', 
      whereArgs: [userId, 'hit_cycles', 'hit_workouts', 'hit_exercises', 'exercise_logs']
    );
  }

  Future<List<TrainingCycle>> getUnsyncedCycles() async {
    final db = await _getDatabase();
    debugPrint("Repo: [DEBUG] Querying unsynced cycles for user $userId...");
    final List<Map<String, dynamic>> maps = await db.query('hit_cycles', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    debugPrint("Repo: [DEBUG] Found ${maps.length} rows with is_synced=0 in hit_cycles.");
    
    List<TrainingCycle> cycles = [];
    for (var cycleMap in maps) {
      final cycleId = cycleMap['id'] as String;
      
      // Fetch Workouts for this cycle
      final List<Map<String, dynamic>> workoutMaps = await db.query(
        'hit_workouts', 
        where: 'cycle_id = ? AND user_id = ?', 
        whereArgs: [cycleId, userId],
        orderBy: 'workout_order ASC'
      );
      
      List<Workout> workouts = [];
      for (var workoutMap in workoutMaps) {
        final workoutId = workoutMap['id'] as String;
        
        // Fetch Exercises for this workout
        final List<Map<String, dynamic>> exerciseMaps = await db.query(
          'hit_exercises', 
          where: 'workout_id = ? AND user_id = ?', 
          whereArgs: [workoutId, userId],
          orderBy: 'exercise_order ASC'
        );
        
        final exercises = exerciseMaps.map((e) => Exercise.fromMap(e)).toList();
        workouts.add(Workout.fromMap(workoutMap, exercises));
      }
      cycles.add(TrainingCycle.fromMap(cycleMap, workouts));
    }
    return cycles;
  }

  Future<List<ExerciseLog>> getUnsyncedLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('exercise_logs', where: 'is_synced = 0 AND user_id = ?', whereArgs: [userId]);
    return maps.map((map) => ExerciseLog.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('hit_settings', where: 'is_synced = 0 AND id = 1 AND user_id = ?', whereArgs: [userId]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> markCycleSynced(String id) async {
    final db = await _getDatabase();
    await db.update('hit_cycles', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markWorkoutSynced(String id) async {
    final db = await _getDatabase();
    await db.update('hit_workouts', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markExerciseSynced(String id) async {
    final db = await _getDatabase();
    await db.update('hit_exercises', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markLogSynced(String id) async {
    final db = await _getDatabase();
    await db.update('exercise_logs', {'is_synced': 1}, where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('hit_settings', {'is_synced': 1}, where: 'id = 1 AND user_id = ?', whereArgs: [userId]);
  }

  Future<void> renameExerciseGlobally(String oldName, String newName) async {
    final db = await _getDatabase();
    await db.update(
      'hit_exercises',
      {'name': newName, 'is_synced': 0},
      where: 'name = ? AND user_id = ?',
      whereArgs: [oldName, userId],
    );
  }

}
