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
    final List<Map<String, dynamic>> cycleMaps = await db.query('training_cycles');
    
    List<TrainingCycle> cycles = [];
    
    for (var cycleMap in cycleMaps) {
      final cycleId = cycleMap['id'] as String;
      
      // 2. Fetch Workouts for this cycle
      final List<Map<String, dynamic>> workoutMaps = await db.query(
        'workouts', 
        where: 'cycle_id = ?', 
        whereArgs: [cycleId],
        orderBy: 'workout_order ASC'
      );
      
      List<Workout> workouts = [];
      for (var workoutMap in workoutMaps) {
        final workoutId = workoutMap['id'] as String;
        
        // 3. Fetch Exercises for this workout
        final List<Map<String, dynamic>> exerciseMaps = await db.query(
          'exercises', 
          where: 'workout_id = ?', 
          whereArgs: [workoutId],
          orderBy: 'exercise_order ASC'
        );
        
        final exercises = exerciseMaps.map((e) => Exercise.fromMap(e)).toList();
        workouts.add(Workout.fromMap(workoutMap, exercises));
      }
      
      cycles.add(TrainingCycle.fromMap(cycleMap, workouts));
    }
    
    return cycles;
  }

  Future<void> insertCycle(TrainingCycle cycle) async {
    final db = await _getDatabase();
    
    await db.transaction((txn) async {
      // 1. Insert Cycle
      await txn.insert('training_cycles', cycle.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      
      // 2. Insert Workouts
      for (var workout in cycle.workouts) {
        await txn.insert('workouts', workout.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        
        // 3. Insert Exercises
        for (var exercise in workout.exercises) {
          await txn.insert('exercises', exercise.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }

  Future<void> deleteCycle(String id) async {
    final db = await _getDatabase();
    // ON DELETE CASCADE in SQLite handles Workouts and Exercises if set up correctly, 
    // but we can be explicit if needed. DatabaseHelper has foreign_keys = ON.
    await db.delete('training_cycles', where: 'id = ?', whereArgs: [id]);
  }

  // --- Granular Updates ---

  Future<void> insertWorkout(Workout workout) async {
    final db = await _getDatabase();
    await db.insert('workouts', workout.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> insertExercise(Exercise exercise) async {
    final db = await _getDatabase();
    await db.insert('exercises', exercise.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteWorkout(String id) async {
    final db = await _getDatabase();
    await db.delete('workouts', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteExercise(String id) async {
    final db = await _getDatabase();
    await db.delete('exercises', where: 'id = ?', whereArgs: [id]);
  }

  // --- Logs ---

  Future<List<ExerciseLog>> getAllLogs() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('exercise_logs', orderBy: 'timestamp DESC');
    return maps.map((map) => ExerciseLog.fromMap(map)).toList();
  }

  Future<void> insertLog(ExerciseLog log) async {
    final db = await _getDatabase();
    await db.insert('exercise_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteLog(String id) async {
    final db = await _getDatabase();
    await db.delete('exercise_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- Settings ---

  Future<Map<String, dynamic>?> getSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('cycle_settings', where: 'id = 1');
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final db = await _getDatabase();
    await db.insert('cycle_settings', settings, conflictAlgorithm: ConflictAlgorithm.replace);
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
    return await db.query('pending_deletions');
  }

  Future<List<TrainingCycle>> getUnsyncedCycles() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('training_cycles', where: 'is_synced = 0');
    
    List<TrainingCycle> cycles = [];
    for (var cycleMap in maps) {
      final cycleId = cycleMap['id'] as String;
      
      // Fetch Workouts for this cycle
      final List<Map<String, dynamic>> workoutMaps = await db.query(
        'workouts', 
        where: 'cycle_id = ?', 
        whereArgs: [cycleId],
        orderBy: 'workout_order ASC'
      );
      
      List<Workout> workouts = [];
      for (var workoutMap in workoutMaps) {
        final workoutId = workoutMap['id'] as String;
        
        // Fetch Exercises for this workout
        final List<Map<String, dynamic>> exerciseMaps = await db.query(
          'exercises', 
          where: 'workout_id = ?', 
          whereArgs: [workoutId],
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
    final List<Map<String, dynamic>> maps = await db.query('exercise_logs', where: 'is_synced = 0');
    return maps.map((map) => ExerciseLog.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>?> getUnsyncedSettings() async {
    final db = await _getDatabase();
    final List<Map<String, dynamic>> maps = await db.query('cycle_settings', where: 'is_synced = 0 AND id = 1');
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<void> markCycleSynced(String id) async {
    final db = await _getDatabase();
    await db.update('training_cycles', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markWorkoutSynced(String id) async {
    final db = await _getDatabase();
    await db.update('workouts', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markExerciseSynced(String id) async {
    final db = await _getDatabase();
    await db.update('exercises', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markLogSynced(String id) async {
    final db = await _getDatabase();
    await db.update('exercise_logs', {'is_synced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markSettingsSynced() async {
    final db = await _getDatabase();
    await db.update('cycle_settings', {'is_synced': 1}, where: 'id = 1');
  }

  Future<void> renameExerciseGlobally(String oldName, String newName) async {
    final db = await _getDatabase();
    await db.update(
      'exercises',
      {'name': newName, 'is_synced': 0},
      where: 'name = ?',
      whereArgs: [oldName],
    );
  }
}
