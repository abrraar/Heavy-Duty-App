import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/training_cycle.dart';
import '../model/workout.dart';
import '../model/exercise.dart';
import '../model/exercise_log.dart';

class CycleCloudRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Deep Retrieval ---

  Future<List<TrainingCycle>?> getAllCycles() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      // Standard Relational Fetch
      final List<Map<String, dynamic>> response = await _supabase
          .from('training_cycles')
          .select('''
            *,
            workouts (
              *,
              exercises (*)
            )
          ''')
          .eq('user_id', uid);

      return response.map((cycleMap) {
        final List<dynamic> workoutData = cycleMap['workouts'] ?? [];
        final workouts = workoutData.map((wMap) {
          final List<dynamic> exerciseData = wMap['exercises'] ?? [];
          final exercises = exerciseData.map((eMap) => Exercise.fromMap(eMap)).toList();
          return Workout.fromMap(wMap, exercises);
        }).toList();
        
        return TrainingCycle.fromMap(cycleMap, workouts);
      }).toList();
    } catch (e) {
      debugPrint("Cloud Cycle Error (getAllCycles): $e");
      rethrow;
    }
  }

  // --- Individual Syncs ---

  Future<void> insertCycle(TrainingCycle cycle) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = cycle.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');
      await _supabase.from('training_cycles').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Cycle Error (insertCycle): $e");
    }
  }

  Future<void> insertWorkout(Workout workout) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = workout.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');
      await _supabase.from('workouts').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Cycle Error (insertWorkout): $e");
    }
  }

  Future<void> insertExercise(Exercise exercise) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = exercise.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');
      await _supabase.from('exercises').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Cycle Error (insertExercise): $e");
    }
  }

  Future<void> deleteWorkout(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('workouts').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Cycle Error (deleteWorkout): $e");
    }
  }

  Future<void> deleteExercise(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('exercises').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Cycle Error (deleteExercise): $e");
    }
  }

  Future<void> deleteCycle(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('training_cycles').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Cycle Error (deleteCycle): $e");
    }
  }

  // --- Logs ---

  Future<List<ExerciseLog>?> getAllLogs() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('exercise_logs')
          .select()
          .eq('user_id', uid);

      return response.map((map) => ExerciseLog.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Cycle Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(ExerciseLog log) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = log.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');
      await _supabase.from('exercise_logs').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Cycle Error (insertLog): $e");
    }
  }

  Future<void> deleteLog(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('exercise_logs').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Cycle Error (deleteLog): $e");
    }
  }

  // --- Settings ---

  Future<Map<String, dynamic>?> getSettings() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('cycle_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint("Cloud Cycle Error (getSettings): $e");
      return null;
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = Map<String, dynamic>.from(settings);
      data['user_id'] = uid;
      // Remove local DB specific fields
      data.remove('id'); 
      data.remove('is_synced');
      
      // Upsert using user_id as the unique constraint to ensure we update existing record
      await _supabase.from('cycle_settings').upsert(
        data, 
        onConflict: 'user_id'
      );
    } catch (e) {
      debugPrint("Cloud Cycle Error (saveSettings): $e");
    }
  }
}
