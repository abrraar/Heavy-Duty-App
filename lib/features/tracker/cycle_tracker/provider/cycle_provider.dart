import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';
import '../model/training_cycle.dart';
import '../model/workout.dart';
import '../model/exercise.dart';
import '../model/exercise_log.dart';
import '../model/cycle_settings.dart';
import '../data/cycle_local_repository.dart';
import '../data/cycle_cloud_repository.dart';

class CycleProvider with ChangeNotifier {
  CycleLocalRepository? _localRepo;
  final CycleCloudRepository _cloudRepo = CycleCloudRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  List<TrainingCycle> _cycles = [];
  final List<ExerciseLog> _logs = [];
  CycleSettings _settings = CycleSettings();
  bool _isLoading = false;

  Set<String> get visibleMetrics => _settings.visibleMetrics;

  void setVisibleMetrics(Set<String> metrics) {
    updateSettings(_settings.copyWith(visibleMetrics: metrics));
  }

  // Performance Caches
  final Map<String, String> _exerciseNameCache = {};
  List<Workout> _cachedWorkouts = [];
  List<Exercise> _cachedExercises = [];

  List<TrainingCycle> get cycles => _cycles;
  List<ExerciseLog> get logs => _logs;
  CycleSettings get settings => _settings;
  bool get isLoading => _isLoading;

  // Helpers for UI compatibility
  List<Workout> get workouts => _cachedWorkouts;
  List<Exercise> get exercises => _cachedExercises;

  String? getExerciseName(String id) => _exerciseNameCache[id];

  TrainingCycle? get activeCycle {
    try {
      return _cycles.firstWhere((c) => c.status == CycleStatus.active);
    } catch (_) {
      return null;
    }
  }

  List<TrainingCycle> get cycleHistory => _cycles.where((c) => c.status == CycleStatus.finished || c.status == CycleStatus.incomplete).toList();
  List<TrainingCycle> get libraryTemplates => _cycles.where((c) => c.status == CycleStatus.template).toList();

  void initializeForUser(String userId) {
    _localRepo = CycleLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("CycleProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:cycle_sync:$userId');

    // 1. Listen for Training Cycles (HIT_cycles)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'HIT_cycles',
      callback: (payload) async {
        debugPrint("Realtime Training Cycle Update: ${payload.eventType}");
        
        // Manual filter to ensure message reaches device even if server filters are finicky
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final cycleData = payload.newRecord;
          final localCycles = await _localRepo!.getAllCycles();
          final localIdx = localCycles.indexWhere((c) => c.id == cycleData['id']);
          
          if (localIdx == -1 || localCycles[localIdx].isSynced == 1) {
            final cycle = TrainingCycle.fromMap(cycleData, localIdx != -1 ? localCycles[localIdx].workouts : []);
            await _localRepo!.insertCycle(cycle);
            await _loadData(silent: true);
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteCycle(id);
            _cycles.removeWhere((c) => c.id == id);
            _rebuildCaches();
            notifyListeners();
          }
        }
      },
    );

    // 1b. Listen for Workouts (HIT_workouts)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'HIT_workouts',
      callback: (payload) async {
        debugPrint("Realtime Workout Update: ${payload.eventType}");
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final workout = Workout.fromMap(payload.newRecord);
          await _localRepo!.insertWorkout(workout);
          await _loadData(silent: true);
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteWorkout(id);
            await _loadData(silent: true);
          }
        }
      },
    );

    // 1c. Listen for Exercises (HIT_exercises)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'HIT_exercises',
      callback: (payload) async {
        debugPrint("Realtime Exercise Update: ${payload.eventType}");
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final exercise = Exercise.fromMap(payload.newRecord);
          await _localRepo!.insertExercise(exercise);
          await _loadData(silent: true);
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteExercise(id);
            await _loadData(silent: true);
          }
        }
      },
    );

    // 2. Listen for Exercise Logs
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'exercise_logs',
      callback: (payload) async {
        debugPrint("Realtime Exercise Log Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final log = ExerciseLog.fromMap(payload.newRecord);
          
          final localLogs = await _localRepo!.getAllLogs();
          final localIdx = localLogs.indexWhere((l) => l.id == log.id);
          
          if (localIdx == -1 || localLogs[localIdx].isSynced == 1) {
            await _localRepo!.insertLog(log);
            
            final index = _logs.indexWhere((l) => l.id == log.id);
            if (index != -1) {
              _logs[index] = log;
            } else {
              _logs.insert(0, log);
              _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            }
            notifyListeners();
          }
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteLog(id);
            _logs.removeWhere((l) => l.id == id);
            notifyListeners();
          }
        }
      },
    );

    // 3. Listen for Cycle Settings (HIT_settings)
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'HIT_settings',
      callback: (payload) async {
        debugPrint("Realtime Cycle Settings Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final settings = CycleSettings.fromMap(payload.newRecord);
          if (_settings.isSynced == 1) {
            await _localRepo!.saveSettings(settings.toMap());
            _settings = settings;
            notifyListeners();
          }
        }
      },
    );

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("CycleProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncLocalToCloud();
        await _loadData(silent: true);
      }
    });
  }

  Future<void> _syncLocalToCloud() async {
    if (_localRepo == null) return;

    // 1. Push Unsynced Deletions
    final deletions = await _localRepo!.getPendingDeletions();
    for (var del in deletions) {
      final id = del['id'] as String;
      final table = del['table_name'] as String;
      try {
        if (table == 'HIT_cycles') await _cloudRepo.deleteCycle(id);
        if (table == 'HIT_workouts') await _cloudRepo.deleteWorkout(id);
        if (table == 'HIT_exercises') await _cloudRepo.deleteExercise(id);
        if (table == 'exercise_logs') await _cloudRepo.deleteLog(id);
        await _localRepo!.removeFromDeletionQueue(id);
      } catch (_) {}
    }

    // 2. Push Unsynced Cycles (Deep Sync)
    final unsyncedCycles = await _localRepo!.getUnsyncedCycles();
    for (var cycle in unsyncedCycles) {
      if (!cycle.isDefault) {
        try {
          _syncCycle(cycle);
        } catch (_) {}
      }
    }

    // 3. Push Unsynced Logs
    final unsyncedLogs = await _localRepo!.getUnsyncedLogs();
    for (var log in unsyncedLogs) {
      try {
        await _cloudRepo.insertLog(log);
        await _localRepo!.markLogSynced(log.id);
      } catch (_) {}
    }

    // 4. Push Unsynced Settings
    final unsyncedSettings = await _localRepo!.getUnsyncedSettings();
    if (unsyncedSettings != null) {
      try {
        await _cloudRepo.saveSettings(unsyncedSettings);
        await _localRepo!.markSettingsSynced();
      } catch (_) {}
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("CycleProvider: FORCE REFRESH TRIGGERED");
      
      // 1. First, try to push anything unsynced (so we don't lose local data)
      await _syncLocalToCloud();
      
      // 2. Perform a fresh load (which pulls from cloud)
      await _loadData(silent: true);
      
      debugPrint("CycleProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("CycleProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_localRepo == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // 1. Load Everything from Local first for immediate UI display
      final settingsMap = await _localRepo!.getSettings();
      if (settingsMap != null) {
        _settings = CycleSettings.fromMap(settingsMap);
      }

      _cycles = await _localRepo!.getAllCycles();
      debugPrint("CycleProvider: Loaded ${_cycles.length} cycles from local.");
      
      // Auto-initialize Mentzer defaults if missing or outdated
      bool needsInit = false;
      
      final ideal = _cycles.cast<TrainingCycle?>().firstWhere((c) => c?.name == "IDEAL ROUTINE" && c?.isDefault == true, orElse: () => null);
      if (ideal == null || ideal.workouts.isEmpty) {
        needsInit = true;
      } else {
        // Check for new naming convention ("for pre-exhaust")
        final firstW = ideal.workouts.first;
        if (firstW.exercises.isEmpty || !firstW.exercises.first.name.contains("pre-exhaust")) {
          needsInit = true;
        }
      }

      if (!needsInit) {
        final consolidated = _cycles.cast<TrainingCycle?>().firstWhere((c) => c?.name == "CONSOLIDATED" && c?.isDefault == true, orElse: () => null);
        if (consolidated == null || consolidated.workouts.length != 2) {
          needsInit = true;
        } else {
          final firstW = consolidated.workouts.first;
          if (firstW.exercises.isEmpty || !firstW.exercises.first.name.contains("alternated")) {
            needsInit = true;
          }
        }
      }
      
      if (!needsInit) {
        final beginner = _cycles.any((c) => c.name == "BEGINNER ROUTINE" && c.isDefault && c.workouts.isNotEmpty);
        if (!beginner) needsInit = true;
      }

      if (!needsInit) {
        final productive = _cycles.any((c) => c.name == "MENTZER PRODUCTIVE ROUTINE" && c.isDefault && c.workouts.isNotEmpty);
        if (!productive) needsInit = true;
      }

      if (!needsInit) {
        final dorian = _cycles.any((c) => c.name == "ONE-SET HEAVY DUTY (DORIAN YATES)" && c.isDefault && c.workouts.isNotEmpty);
        if (!dorian) needsInit = true;
      }
      
      if (needsInit) {
        debugPrint("CycleProvider: Mentzer defaults missing or outdated. Re-initializing...");
        await _initializeMentzerDefaults();
        _cycles = await _localRepo!.getAllCycles();
      }

      final allLogs = await _localRepo!.getAllLogs(); 
      _logs.clear();
      _logs.addAll(allLogs);
      notifyListeners();

      // 2. Sync from Cloud to Local
      debugPrint("CycleProvider: Syncing from cloud...");
      
      // Sync Settings
      final cloudSettingsMap = await _cloudRepo.getSettings();
      if (cloudSettingsMap != null) {
        if (_settings.isSynced == 1) {
          _settings = CycleSettings.fromMap(cloudSettingsMap);
          // Always use our model's toMap for local storage to ensure schema compatibility (id: 1)
          await _localRepo!.saveSettings(_settings.toMap());
        }
      } else {
        // If settings don't exist in cloud, push our local ones
        _syncSettings(_settings);
      }

      final cloudCycles = await _cloudRepo.getAllCycles();
      if (cloudCycles != null) {
        final localCycles = await _localRepo!.getAllCycles();

        // 2a. Deep Pruning: Collect all IDs from the cloud to find orphans
        final cloudCycleIds = cloudCycles.map((c) => c.id).toSet();
        final cloudWorkoutIds = cloudCycles.expand((c) => c.workouts.map((w) => w.id)).toSet();
        final cloudExerciseIds = cloudCycles.expand((c) => c.workouts.expand((w) => w.exercises.map((e) => e.id))).toSet();

        // Prune Cycles
        for (var localC in localCycles) {
          if (localC.isSynced == 1 && !localC.isDefault && !cloudCycleIds.contains(localC.id)) {
            debugPrint("CycleProvider: Pruning deleted cycle: ${localC.name}");
            await _localRepo!.deleteCycle(localC.id);
          } else if (!localC.isDefault) {
            // Prune Workouts within existing non-default cycles
            for (var localW in localC.workouts) {
              if (localW.isSynced == 1 && !cloudWorkoutIds.contains(localW.id)) {
                debugPrint("CycleProvider: Pruning deleted workout: ${localW.name}");
                await _localRepo!.deleteWorkout(localW.id);
              }
              
              // Prune Exercises within existing workouts
              for (var localE in localW.exercises) {
                if (localE.isSynced == 1 && !cloudExerciseIds.contains(localE.id)) {
                  debugPrint("CycleProvider: Pruning deleted exercise: ${localE.name}");
                  await _localRepo!.deleteExercise(localE.id);
                }
              }
            }
          }
        }

        // 2b. Pulling: Add/Update from Cloud
        for (var c in cloudCycles) {
          await _localRepo!.insertCycle(c);
        }
      }
      
      // 3. Pull and Prune Logs
      final cloudLogs = await _cloudRepo.getAllLogs();
      if (cloudLogs != null) {
        final localLogs = await _localRepo!.getAllLogs();
        final localLogMap = {for (var l in localLogs) l.id: l};

        // 3a. Pruning Logs
        final cloudLogIds = cloudLogs.map((l) => l.id).toSet();
        for (var localL in localLogs) {
          if (localL.isSynced == 1 && !cloudLogIds.contains(localL.id)) {
            await _localRepo!.deleteLog(localL.id);
          }
        }

        // 3b. Pulling Logs
        for (var l in cloudLogs) {
          final localL = localLogMap[l.id];
          if (localL == null || localL.isSynced == 1) {
            await _localRepo!.insertLog(l);
          }
        }
      }

      // 4. Final Memory Refresh
      _cycles = await _localRepo!.getAllCycles();
      final allLogsRefresh = await _localRepo!.getAllLogs();
      _logs.clear();
      _logs.addAll(allLogsRefresh);
      _rebuildCaches();
      debugPrint("CycleProvider: Cloud sync and pruning complete.");
    } catch (e) {
      debugPrint("CycleProvider: Error loading data: $e");
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _rebuildCaches() {
    _exerciseNameCache.clear();
    _cachedWorkouts = [];
    _cachedExercises = [];
    
    for (var cycle in _cycles) {
      for (var workout in cycle.workouts) {
        _cachedWorkouts.add(workout);
        for (var exercise in workout.exercises) {
          _cachedExercises.add(exercise);
          _exerciseNameCache[exercise.id] = exercise.name;
        }
      }
    }
  }

  // --- Actions ---

  Future<void> addCycle(TrainingCycle cycle) async {
    if (_localRepo == null) return;
    
    final localCycle = cycle.copyWith(isSynced: 0);
    _cycles.add(localCycle);
    _rebuildCaches();
    notifyListeners();

    try {
      await _localRepo!.insertCycle(localCycle);
      // Only sync custom cycles to the cloud (Templates stay local)
      if (!cycle.isDefault) {
        _syncCycle(localCycle);
      }
    } catch (e) {
      debugPrint("Error saving new cycle locally: $e");
    }
  }

  Future<void> _syncCycle(TrainingCycle cycle) async {
    try {
      // 1. Push Cycle Header
      await _cloudRepo.insertCycle(cycle);
      await _localRepo!.markCycleSynced(cycle.id);
      
      // 2. Push Workouts & Exercises with Individual Error Isolation
      for (var workout in cycle.workouts) {
        try {
          await _cloudRepo.insertWorkout(workout);
          await _localRepo!.markWorkoutSynced(workout.id);
          
          for (var exercise in workout.exercises) {
            try {
              await _cloudRepo.insertExercise(exercise);
              await _localRepo!.markExerciseSynced(exercise.id);
            } catch (e) {
              debugPrint("Background Sync Error (Exercise ${exercise.id}): $e");
            }
          }
        } catch (e) {
          debugPrint("Background Sync Error (Workout ${workout.id}): $e");
        }
      }

      final idx = _cycles.indexWhere((c) => c.id == cycle.id);
      if (idx != -1) {
        _cycles[idx] = _cycles[idx].copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Cycle Root): $e");
    }
  }

  Future<void> activateCycle(String templateId) async {
    if (_localRepo == null) return;
    
    // 1. Deactivate current active cycle if any
    for (int i = 0; i < _cycles.length; i++) {
      if (_cycles[i].status == CycleStatus.active) {
        final current = _cycles[i];
        final newStatus = current.isReadyToFinish ? CycleStatus.finished : CycleStatus.incomplete;
        
        final finishedCycle = current.copyWith(
          status: newStatus,
          completedAt: DateTime.now(),
          isSynced: 0
        );
        _cycles[i] = finishedCycle;
        await _localRepo!.insertCycle(finishedCycle);
        _syncCycle(finishedCycle);
      }
    }

    // 2. Find the template to duplicate
    final template = _cycles.firstWhere((c) => c.id == templateId);
    
    // 3. Create a NEW instance of the cycle
    final newCycleId = Uuid().v4();
    final newActiveCycle = template.copyWith(
      id: newCycleId,
      status: CycleStatus.active,
      startedAt: DateTime.now(),
      isDefault: false,
      isSynced: 0,
      workouts: template.workouts.map((tw) {
        final nwId = Uuid().v4();
        return tw.copyWith(
          id: nwId,
          cycleId: newCycleId,
          status: WorkoutStatus.pending,
          completedAt: null,
          exercises: tw.exercises.map((te) => te.copyWith(
            id: Uuid().v4(),
            workoutId: nwId,
          )).toList(),
        );
      }).toList(),
    );

    // 5. Save the new active cycle
    await addCycle(newActiveCycle);
    
    _rebuildCaches();
    notifyListeners();
  }

  Future<void> addWorkout(Workout workout) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE: Update memory state immediately
    final cycleIdx = _cycles.indexWhere((c) => c.id == workout.cycleId);
    if (cycleIdx != -1) {
      final updatedCycle = _cycles[cycleIdx].copyWith(
        workouts: [..._cycles[cycleIdx].workouts, workout],
      );
      _cycles[cycleIdx] = updatedCycle;
      _rebuildCaches();
      notifyListeners();
      
      // 2. Persistent Save
      try {
        await _localRepo!.insertWorkout(workout);
        await _cloudRepo.insertWorkout(workout);
        await _localRepo!.markWorkoutSynced(workout.id);
      } catch (e) {
        debugPrint("Error saving workout: $e");
      }
    }
  }

  Future<void> addExercise(Exercise exercise) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE: Find parent workout and update memory state
    bool found = false;
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == exercise.workoutId);
      if (wIdx != -1) {
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(
          exercises: [..._cycles[i].workouts[wIdx].exercises, exercise],
        );
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        final updatedCycle = _cycles[i].copyWith(workouts: updatedWorkouts);
        _cycles[i] = updatedCycle;
        _rebuildCaches();
        notifyListeners();
        found = true;
        break;
      }
    }

    // 2. Persistent Save
    if (found) {
      try {
        await _localRepo!.insertExercise(exercise);
        await _cloudRepo.insertExercise(exercise);
        await _localRepo!.markExerciseSynced(exercise.id);
      } catch (e) {
        debugPrint("Error saving exercise: $e");
      }
    }
  }

  Future<void> deleteWorkout(String id) async {
    if (_localRepo == null) return;
    
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == id);
      if (wIdx != -1) {
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts)..removeAt(wIdx);
        final updatedCycle = _cycles[i].copyWith(workouts: updatedWorkouts);
        _cycles[i] = updatedCycle;
        _rebuildCaches();
        notifyListeners();
        
        await _localRepo!.deleteWorkout(id);
        await _localRepo!.addToDeletionQueue(id, 'HIT_workouts');
        _syncWorkoutDelete(id);
        break;
      }
    }
  }

  Future<void> _syncWorkoutDelete(String id) async {
    try {
      await _cloudRepo.deleteWorkout(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (_) {}
  }

  Future<void> deleteExercise(String id) async {
    if (_localRepo == null) return;
    
    bool found = false;
    for (int i = 0; i < _cycles.length; i++) {
      for (int j = 0; j < _cycles[i].workouts.length; j++) {
        final List<Exercise> exList = _cycles[i].workouts[j].exercises;
        final exIdx = exList.indexWhere((e) => e.id == id);
        if (exIdx != -1) {
          final updatedExercises = List<Exercise>.from(exList)..removeAt(exIdx);
          final updatedWorkout = _cycles[i].workouts[j].copyWith(exercises: updatedExercises);
          final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
          updatedWorkouts[j] = updatedWorkout;
          
          final updatedCycle = _cycles[i].copyWith(workouts: updatedWorkouts);
          _cycles[i] = updatedCycle;
          _rebuildCaches();
          notifyListeners();
          
          await _localRepo!.deleteExercise(id);
          await _localRepo!.addToDeletionQueue(id, 'HIT_exercises');
          _syncExerciseDelete(id);
          found = true;
          break;
        }
      }
      if (found) break;
    }
  }

  Future<void> _syncExerciseDelete(String id) async {
    try {
      await _cloudRepo.deleteExercise(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (_) {}
  }

  Future<void> deleteCycle(String id) async {
    if (_localRepo == null) return;
    
    _cycles.removeWhere((c) => c.id == id);
    _rebuildCaches();
    notifyListeners();

    await _localRepo!.deleteCycle(id);
    await _localRepo!.addToDeletionQueue(id, 'HIT_cycles');
    _syncCycleDelete(id);
  }

  Future<void> _syncCycleDelete(String id) async {
    try {
      await _cloudRepo.deleteCycle(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Cycle Delete): $e");
    }
  }

  Future<void> finishCycle(String cycleId) async {
    if (_localRepo == null) return;
    
    final index = _cycles.indexWhere((c) => c.id == cycleId);
    if (index != -1) {
      final finishedCycle = _cycles[index].copyWith(
        status: CycleStatus.finished,
        completedAt: DateTime.now(),
        isSynced: 0
      );
      _cycles[index] = finishedCycle;
      
      await _localRepo!.insertCycle(finishedCycle);
      _syncCycle(finishedCycle);
      
      _rebuildCaches();
      notifyListeners();
      debugPrint("CycleProvider: Cycle '$cycleId' marked as FINISHED.");
    }
  }

  Future<void> addExerciseLog(ExerciseLog log) async {
    if (_localRepo == null) return;
    final localLog = log.copyWith(isSynced: 0);

    _logs.insert(0, localLog);
    notifyListeners();
    await _localRepo!.insertLog(localLog);
    _syncExerciseLog(localLog);
  }

  Future<void> _syncExerciseLog(ExerciseLog log) async {
    try {
      debugPrint("CycleProvider: Attempting Cloud Sync for Log: ${log.id}");
      await _cloudRepo.insertLog(log);
      debugPrint("CycleProvider: Cloud Sync Success for Log: ${log.id}");
      await _localRepo!.markLogSynced(log.id);
      
      // Update in-memory sync status
      final idx = _logs.indexWhere((l) => l.id == log.id);
      if (idx != -1) {
        _logs[idx] = _logs[idx].copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("CycleProvider: Cloud Sync Failed for Log: ${log.id} - Error: $e");
    }
  }

  Future<void> upsertExerciseLog(ExerciseLog log) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE
    final localLog = log.copyWith(isSynced: 0);
    final index = _logs.indexWhere((l) => l.id == localLog.id);
    if (index != -1) {
      _logs[index] = localLog;
    } else {
      _logs.insert(0, localLog);
      _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }
    
    notifyListeners();

    // 2. PERSIST LOCAL
    await _localRepo!.insertLog(localLog); 

    // 3. BACKGROUND SYNC
    _syncExerciseLog(localLog);

    // 4. CHECK COMPLETION (Updates UI via _updateWorkoutInCycle)
    await _checkWorkoutCompletion(localLog.exerciseId);
  }

  Future<void> deleteExerciseLog(String logId) async {
    if (_localRepo == null) return;
    
    final logIdx = _logs.indexWhere((l) => l.id == logId);
    if (logIdx != -1) {
      final log = _logs[logIdx];
      final exId = log.exerciseId;
      _logs.removeAt(logIdx);
      notifyListeners();
      
      await _localRepo!.deleteLog(logId);
      await _localRepo!.addToDeletionQueue(logId, 'exercise_logs');
      _syncExerciseLogDelete(logId);
      
      // Check if workout completion status needs to change
      await _checkWorkoutCompletion(exId);
    }
  }

  Future<void> _syncExerciseLogDelete(String id) async {
    try {
      await _cloudRepo.deleteLog(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Exercise Log Delete): $e");
    }
  }

  Future<void> _checkWorkoutCompletion(String exerciseId) async {
    try {
      Workout? targetWorkout;
      TrainingCycle? targetCycle;
      
      // 1. Locate the specific Workout/Cycle for this exercise instance.
      // We prioritize searching in the Active cycle to avoid colliding with deterministic IDs in history.
      final active = activeCycle;
      if (active != null) {
        for (var w in active.workouts) {
          if (w.exercises.any((e) => e.id == exerciseId)) {
            targetWorkout = w;
            targetCycle = active;
            break;
          }
        }
      }

      // If not in active cycle, search everywhere (Fallback)
      if (targetWorkout == null) {
        for (var c in _cycles) {
          for (var w in c.workouts) {
            if (w.exercises.any((e) => e.id == exerciseId)) {
              targetWorkout = w;
              targetCycle = c;
              break;
            }
          }
          if (targetWorkout != null) break;
        }
      }

      if (targetWorkout == null || targetCycle == null) {
        debugPrint("CycleProvider: Target workout/cycle not found for instance ID $exerciseId");
        return;
      }

      bool allExercisesFinished = true;
      for (var ex in targetWorkout.exercises) {
        // Find latest log for THIS specific exercise instance ID
        final exLogs = _logs.where((l) => l.exerciseId == ex.id).toList();
        
        bool hasValidLog = false;
        for (var l in exLogs) {
          // A valid HIT set must have a base load (Weight) AND at least one intensifier value
          final hasBaseLoad = l.weightKg > 0 || l.weightLbs > 0;
          final hasIntensifier = l.positiveReps > 0 || 
                               l.staticHoldSeconds > 0 || 
                               l.negativeReps > 0 || 
                               l.forcedReps > 0;
          
          if (hasBaseLoad && hasIntensifier) {
            hasValidLog = true;
            break;
          }
        }
        
        if (!hasValidLog) {
          allExercisesFinished = false;
          break;
        }
      }

      final bool isCurrentlyCompleted = targetWorkout.status == WorkoutStatus.completed;

      if (allExercisesFinished && !isCurrentlyCompleted && targetWorkout.exercises.isNotEmpty) {
        // --- 1. TRANSITION TO COMPLETED ---
        debugPrint("CycleProvider: All exercises finished. Updating workout '${targetWorkout.name}' to COMPLETED.");
        final updatedWorkout = targetWorkout.copyWith(
          status: WorkoutStatus.completed,
          completedAt: DateTime.now(),
        );
        await _updateWorkoutInCycle(targetCycle!, updatedWorkout);
      } 
      else if ((!allExercisesFinished || targetWorkout.exercises.isEmpty) && isCurrentlyCompleted) {
        // --- 2. REVERT TO PENDING ---
        debugPrint("CycleProvider: Exercise removed or invalidated. Reverting workout '${targetWorkout.name}' to PENDING.");
        final updatedWorkout = targetWorkout.copyWith(
          status: WorkoutStatus.pending,
          completedAt: null,
        );

        final cIdx = _cycles.indexWhere((c) => c.id == targetCycle!.id);
        if (cIdx != -1) {
          final updatedWorkouts = List<Workout>.from(_cycles[cIdx].workouts);
          final wIdx = updatedWorkouts.indexWhere((w) => w.id == updatedWorkout.id);
          if (wIdx != -1) {
            updatedWorkouts[wIdx] = updatedWorkout;
          }

          TrainingCycle updatedCycle = _cycles[cIdx].copyWith(
            workouts: updatedWorkouts,
            isSynced: 0,
          );

          // If the cycle was already FINISHED, it now becomes INCOMPLETE because a workout was invalidated
          if (updatedCycle.status == CycleStatus.finished) {
            updatedCycle = updatedCycle.copyWith(status: CycleStatus.incomplete);
            debugPrint("CycleProvider: Cycle '${updatedCycle.id}' status reverted to INCOMPLETE.");
          }

          _cycles[cIdx] = updatedCycle;
          _rebuildCaches();
          notifyListeners();

          await _localRepo!.insertCycle(updatedCycle);
          _syncCycle(updatedCycle);
        }
      }
    } catch (e) {
      debugPrint("CycleProvider Error in _checkWorkoutCompletion: $e");
    }
  }

  Future<void> _updateWorkoutInCycle(TrainingCycle targetCycle, Workout updatedWorkout) async {
    // 1. UPDATE MEMORY IMMEDIATELY
    final cIdx = _cycles.indexWhere((c) => c.id == targetCycle.id);
    if (cIdx != -1) {
      final wIdx = _cycles[cIdx].workouts.indexWhere((w) => w.id == updatedWorkout.id);
      if (wIdx != -1) {
        final updatedWorkouts = List<Workout>.from(_cycles[cIdx].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        _cycles[cIdx] = _cycles[cIdx].copyWith(workouts: updatedWorkouts);
        _rebuildCaches();
        notifyListeners();
      }
    }

    // 2. SAVE LOCAL
    await _localRepo!.insertWorkout(updatedWorkout.copyWith(isSynced: 0));
    
    // 3. SYNC CLOUD
    try {
      await _cloudRepo.insertWorkout(updatedWorkout);
      await _localRepo!.markWorkoutSynced(updatedWorkout.id);
    } catch (_) {}
  }
  Future<void> updateWorkoutOrder(String cycleId, List<Workout> workouts) async {
    if (_localRepo == null) return;
    
    final idx = _cycles.indexWhere((c) => c.id == cycleId);
    if (idx != -1) {
      final updatedWorkouts = workouts.asMap().entries.map((entry) {
        return entry.value.copyWith(order: entry.key);
      }).toList();
      
      final updatedCycle = _cycles[idx].copyWith(workouts: updatedWorkouts, isSynced: 0);
      _cycles[idx] = updatedCycle;
      _rebuildCaches();
      notifyListeners();
      
      await _localRepo!.insertCycle(updatedCycle);
      if (!updatedCycle.isDefault) {
        _syncCycle(updatedCycle);
      }
    }
  }

  Future<void> updateWorkoutName(String workoutId, String newName) async {
    if (_localRepo == null) return;
    
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(name: newName.toUpperCase());
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        _cycles[i] = _cycles[i].copyWith(workouts: updatedWorkouts, isSynced: 0);
        _rebuildCaches();
        notifyListeners();
        
        await _localRepo!.insertWorkout(updatedWorkout.copyWith(isSynced: 0));
        if (!_cycles[i].isDefault) {
          _syncWorkout(updatedWorkout);
        }
        break;
      }
    }
  }

  Future<void> updateWorkoutNote(String workoutId, String note) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(note: note);
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        _cycles[i] = _cycles[i].copyWith(workouts: updatedWorkouts, isSynced: 0);
        _rebuildCaches();
        notifyListeners();
        
        // 2. PERSIST LOCAL & SYNC
        await _localRepo!.insertWorkout(updatedWorkout.copyWith(isSynced: 0));
        if (!_cycles[i].isDefault) {
          _syncWorkout(updatedWorkout);
        }
        break;
      }
    }
  }

  Future<void> _syncWorkout(Workout workout) async {
    try {
      await _cloudRepo.insertWorkout(workout);
      await _localRepo!.markWorkoutSynced(workout.id);
    } catch (_) {}
  }

  Future<void> updateCycleNote(String cycleId, String note) async {
    if (_localRepo == null) return;
    
    // 1. OPTIMISTIC UPDATE
    final index = _cycles.indexWhere((c) => c.id == cycleId);
    if (index != -1) {
      final updatedCycle = _cycles[index].copyWith(note: note, isSynced: 0);
      _cycles[index] = updatedCycle;
      
      _rebuildCaches();
      notifyListeners();

      // 2. PERSIST LOCAL
      await _localRepo!.insertCycle(updatedCycle);
      
      // 3. SYNC
      if (!updatedCycle.isDefault) {
        _syncCycle(updatedCycle);
      }
    }
  }

  Future<void> updateCycleName(String cycleId, String newName) async {
    if (_localRepo == null) return;
    
    final index = _cycles.indexWhere((c) => c.id == cycleId);
    if (index != -1) {
      final updatedCycle = _cycles[index].copyWith(name: newName.toUpperCase(), isSynced: 0);
      _cycles[index] = updatedCycle;
      
      _rebuildCaches();
      notifyListeners();

      await _localRepo!.insertCycle(updatedCycle);
      if (!updatedCycle.isDefault) {
        _syncCycle(updatedCycle);
      }
    }
  }

  Future<void> updateSettings(CycleSettings settings) async {
    if (_localRepo == null) return;
    final localSettings = settings.copyWith(isSynced: 0);
    _settings = localSettings;
    notifyListeners();
    await _localRepo!.saveSettings(localSettings.toMap());
    _syncSettings(localSettings);
  }

  Future<void> _syncSettings(CycleSettings settings) async {
    try {
      await _cloudRepo.saveSettings(settings.toMap());
      await _localRepo!.markSettingsSynced();
      if (_settings.isSynced == 0) {
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Cycle Settings): $e");
    }
  }

  Future<void> renameExerciseGlobally(String oldName, String newName) async {
    if (_localRepo == null) return;
    
    bool changed = false;
    final upperOld = oldName.trim().toUpperCase();
    final upperNew = newName.trim().toUpperCase();

    if (upperOld == upperNew) return;

    // 1. Update in memory
    for (int i = 0; i < _cycles.length; i++) {
      final updatedWorkouts = _cycles[i].workouts.map((workout) {
        final updatedExercises = workout.exercises.map((exercise) {
          if (exercise.name.trim().toUpperCase() == upperOld) {
            changed = true;
            return exercise.copyWith(name: upperNew, isSynced: 0);
          }
          return exercise;
        }).toList();
        return workout.copyWith(exercises: updatedExercises);
      }).toList();
      
      if (changed) {
        _cycles[i] = _cycles[i].copyWith(workouts: updatedWorkouts);
      }
    }

    if (changed) {
      _rebuildCaches();
      notifyListeners();

      // 2. Update in Local DB
      await _localRepo!.renameExerciseGlobally(upperOld, upperNew);

      // 3. Trigger Sync for affected exercises
      // We loop through all exercises in memory that were changed and sync them
      for (var cycle in _cycles) {
        for (var workout in cycle.workouts) {
          for (var exercise in workout.exercises) {
            if (exercise.name == upperNew && exercise.isSynced == 0) {
               _cloudRepo.insertExercise(exercise).then((_) {
                 _localRepo?.markExerciseSynced(exercise.id);
               }).catchError((_) {});
            }
          }
        }
      }
    }
  }

  // --- Conversion Helpers ---
  static const double _kgToLbsMultiplier = 2.205;

  double getWeightForDisplay(ExerciseLog log) {
    return _settings.weightUnit == WeightUnit.kgs ? log.weightKg : log.weightLbs;
  }

  // Use this when the user is typing a value in the current unit
  // Returns a Map with both values calculated and truncated to 3 decimals
  Map<String, double> calculateDualWeights(double inputValue) {
    // 1. Convert input to string with high precision, then truncate to exactly 3 decimals
    String inputStr = inputValue.toStringAsFixed(10);
    int dotIdx = inputStr.indexOf('.');
    double cleanInput = double.parse(inputStr.substring(0, dotIdx + 4));

    if (_settings.weightUnit == WeightUnit.kgs) {
      double rawLbs = cleanInput * _kgToLbsMultiplier;
      String lbsStr = rawLbs.toStringAsFixed(10);
      int lbsDotIdx = lbsStr.indexOf('.');
      
      return {
        'kg': cleanInput,
        'lbs': double.parse(lbsStr.substring(0, lbsDotIdx + 4)),
      };
    } else {
      double rawKg = cleanInput / _kgToLbsMultiplier;
      String kgStr = rawKg.toStringAsFixed(10);
      int kgDotIdx = kgStr.indexOf('.');

      return {
        'kg': double.parse(kgStr.substring(0, kgDotIdx + 4)),
        'lbs': cleanInput,
      };
    }
  }

  double convertToDisplay(double valueInLbs) {
    if (_settings.weightUnit == WeightUnit.kgs) {
      return valueInLbs / _kgToLbsMultiplier;
    }
    return valueInLbs;
  }

  Future<void> updateExerciseOrder(String workoutId, List<Exercise> exercises) async {
    if (_localRepo == null) return;
    
    for (int i = 0; i < _cycles.length; i++) {
      final wIdx = _cycles[i].workouts.indexWhere((w) => w.id == workoutId);
      if (wIdx != -1) {
        final updatedExercises = exercises.asMap().entries.map((entry) {
          return entry.value.copyWith(order: entry.key);
        }).toList();
        
        final updatedWorkout = _cycles[i].workouts[wIdx].copyWith(exercises: updatedExercises);
        final updatedWorkouts = List<Workout>.from(_cycles[i].workouts);
        updatedWorkouts[wIdx] = updatedWorkout;
        
        final updatedCycle = _cycles[i].copyWith(workouts: updatedWorkouts, isSynced: 0);
        _cycles[i] = updatedCycle;
        _rebuildCaches();
        notifyListeners();
        
        await _localRepo!.insertCycle(updatedCycle);
        if (!updatedCycle.isDefault) {
          _syncCycle(updatedCycle);
        }
        break;
      }
    }
  }

  double calculateCyclePerformance(String cycleId) {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: "None"));
    if (cycle.id.isEmpty || cycle.startedAt == null) return 0.0;

    double totalGrowth = 0.0;
    int exerciseCount = 0;

    for (var workout in cycle.workouts) {
      for (var exercise in workout.exercises) {
        // Filter logs specifically to this cycle's timeframe
        final cycleLogs = _logs.where((l) {
          final cachedName = getExerciseName(l.exerciseId);
          final bool isSameExercise = cachedName?.trim().toUpperCase() == exercise.name.trim().toUpperCase();
          final bool isWithinCycle = l.timestamp.isAfter(cycle.startedAt!) || l.timestamp.isAtSameMomentAs(cycle.startedAt!);
          return isSameExercise && isWithinCycle;
        }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        if (cycleLogs.length < 2) continue;

        // Compare first session of THIS cycle with latest session of THIS cycle
        final baseline = cycleLogs.first.weightKg * cycleLogs.first.positiveReps;
        final latest = cycleLogs.last.weightKg * cycleLogs.last.positiveReps;

        if (baseline > 0) {
          totalGrowth += (latest / baseline) - 1;
          exerciseCount++;
        }
      }
    }

    return exerciseCount > 0 ? totalGrowth / exerciseCount : 0.0;
  }

  // --- Progression Analysis: Strength (Brzycki) & Volume ---

  double _calculateBrzycki1RM(double weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0.0;
    // Brzycki Formula: 1RM = Weight / (1.0278 - (0.0278 * Reps))
    // Note: Formula is most accurate for reps < 10, but we use it as a general strength estimator.
    return weight / (1.0278 - (0.0278 * reps));
  }

  double _calculateVolume(double weight, int reps) {
    return weight * reps;
  }

  /// Returns a map with 'strength' and 'volume' progression percentages.
  Map<String, double> calculateExerciseProgression(String exerciseName, {String? targetCycleId}) {
    final allLogs = _logs.where((l) {
      final cachedName = getExerciseName(l.exerciseId);
      return cachedName?.trim().toUpperCase() == exerciseName.trim().toUpperCase();
    }).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (allLogs.isEmpty) return {"strength": 0.0, "volume": 0.0};

    final List<TrainingCycle> relevantCycles = _cycles.where((c) {
      return c.workouts.any((w) => w.exercises.any((e) => e.name.trim().toUpperCase() == exerciseName.trim().toUpperCase()));
    }).toList()..sort((a, b) => (a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    if (relevantCycles.isEmpty) return {"strength": 0.0, "volume": 0.0};

    int targetIdx = relevantCycles.length - 1;
    if (targetCycleId != null) {
      targetIdx = relevantCycles.indexWhere((c) => c.id == targetCycleId);
    }

    if (targetIdx <= 0) return {"strength": 0.0, "volume": 0.0};

    final targetCycle = relevantCycles[targetIdx];
    final targetCycleLogs = allLogs.where((l) {
      return targetCycle.workouts.any((w) => w.exercises.any((e) => e.id == l.exerciseId));
    }).toList();

    if (targetCycleLogs.isEmpty) return {"strength": 0.0, "volume": 0.0};
    final latestLog = targetCycleLogs.last;

    final previousCycle = relevantCycles[targetIdx - 1];
    final previousCycleLogs = allLogs.where((l) {
      return previousCycle.workouts.any((w) => w.exercises.any((e) => e.id == l.exerciseId));
    }).toList();

    if (previousCycleLogs.isEmpty) return {"strength": 0.0, "volume": 0.0};
    final baselineLog = previousCycleLogs.last;

    if (latestLog.weightKg <= 0 || latestLog.positiveReps <= 0 || baselineLog.weightKg <= 0 || baselineLog.positiveReps <= 0) {
      return {"strength": 0.0, "volume": 0.0};
    }

    // Strength (Brzycki)
    final double current1RM = _calculateBrzycki1RM(latestLog.weightKg, latestLog.positiveReps);
    final double baseline1RM = _calculateBrzycki1RM(baselineLog.weightKg, baselineLog.positiveReps);
    final double strengthProg = (current1RM / baseline1RM) - 1;

    // Volume
    final double currentVol = _calculateVolume(latestLog.weightKg, latestLog.positiveReps);
    final double baselineVol = _calculateVolume(baselineLog.weightKg, baselineLog.positiveReps);
    final double volumeProg = (currentVol / baselineVol) - 1;

    return {
      "strength": strengthProg,
      "volume": volumeProg,
    };
  }

  Map<String, double> calculateWorkoutProgression(Workout workout, {String? targetCycleId}) {
    double totalStrength = 0.0;
    double totalVolume = 0.0;
    
    for (var exercise in workout.exercises) {
      final prog = calculateExerciseProgression(exercise.name, targetCycleId: targetCycleId ?? workout.cycleId);
      totalStrength += prog['strength']!;
      totalVolume += prog['volume']!;
    }
    
    return {
      "strength": totalStrength,
      "volume": totalVolume,
    };
  }

  Map<String, double> calculateCycleProgression(String cycleId) {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: ""));
    if (cycle.id.isEmpty) return {"strength": 0.0, "volume": 0.0};

    double totalStrength = 0.0;
    double totalVolume = 0.0;
    
    for (var workout in cycle.workouts) {
      final prog = calculateWorkoutProgression(workout, targetCycleId: cycleId);
      totalStrength += prog['strength']!;
      totalVolume += prog['volume']!;
    }
    
    return {
      "strength": totalStrength,
      "volume": totalVolume,
    };
  }

  // --- UI Compatibility Overrides (Maintains existing single-value calls if any) ---

  double calculateExerciseProgress(String exerciseName, {String? targetCycleId}) {
    return calculateExerciseProgression(exerciseName, targetCycleId: targetCycleId)['strength']!;
  }

  double calculateWorkoutProgress(Workout workout, {String? targetCycleId}) {
    return calculateWorkoutProgression(workout, targetCycleId: targetCycleId)['strength']!;
  }

  double calculateCycleProgress(String cycleId) {
    return calculateCycleProgression(cycleId)['strength']!;
  }

  Future<void> _initializeMentzerDefaults() async {
    // Mike Mentzer's Ideal Routine
    const idealCycleId = "mentzer_ideal_routine";
    final idealCycle = TrainingCycle(
      id: idealCycleId,
      name: "IDEAL ROUTINE", 
      description: "4 SESSIONS • THE CLASSIC HIT PROTOCOL", 
      isDefault: true,
      isSynced: 1, 
      workouts: [
        _createDefaultWorkout(idealCycleId, "mentzer_ideal_w1", "WORKOUT ONE: CHEST & BACK", 0, [
          "Dumbbell Flyes", 
          "Incline Presses", 
          "Straight-Arm Lat Machine Pulldowns", 
          "Palms-Up Pulldowns", 
          "Deadlifts"
        ]),
        _createDefaultWorkout(idealCycleId, "mentzer_ideal_w2", "WORKOUT TWO: LEGS & ABS", 1, [
          "Leg Extensions", 
          "Leg Presses", 
          "Standing Calf Raises", 
          "Sit-Ups"
        ]),
        _createDefaultWorkout(idealCycleId, "mentzer_ideal_w3", "WORKOUT THREE: SHOULDERS & ARMS", 2, [
          "Dumbbell Lateral Raises", 
          "Bent-Over Dumbbell Laterals", 
          "Palms-Up Pulldowns", 
          "Triceps Pressdowns", 
          "Dips"
        ]),
        _createDefaultWorkout(idealCycleId, "mentzer_ideal_w4", "WORKOUT FOUR: LEGS & ABS", 3, [
          "Leg Extensions", 
          "Leg Presses", 
          "Standing Calf Raises", 
          "Sit-Ups"
        ]),
      ],
    );

    await addCycle(idealCycle);

    // Consolidated Routine
    const consolidatedCycleId = "mentzer_consolidated_routine";
    final consolidatedCycle = TrainingCycle(
      id: consolidatedCycleId,
      name: "CONSOLIDATED", 
      description: "2 SESSIONS • MAX RECOVERY", 
      isDefault: true,
      isSynced: 1, 
      workouts: [
        _createDefaultWorkout(consolidatedCycleId, "mentzer_cons_w1", "WORKOUT ONE", 0, [
          "Squats", 
          "Palms-Up Pulldowns", 
          "Dips"
        ]),
        _createDefaultWorkout(consolidatedCycleId, "mentzer_cons_w2", "WORKOUT TWO", 1, [
          "Deadlifts", 
          "Press Behind Neck", 
          "Standing Calf Raises"
        ]),
      ],
    );

    await addCycle(consolidatedCycle);

    // Beginner Routine
    const beginnerCycleId = "mentzer_beginner_routine";
    final beginnerExercises = [
      "Squats", 
      "Barbell Rows", 
      "Bench Press", 
      "Press Behind Neck", 
      "Deadlifts", 
      "Standing Barbell Curls", 
      "Standing Calf Raises", 
      "Sit-Ups"
    ];

    final beginnerCycle = TrainingCycle(
      id: beginnerCycleId,
      name: "BEGINNER ROUTINE",
      description: "5 DAYS • FUNDAMENTAL HIT MOVEMENTS",
      isDefault: true,
      isSynced: 1,
      workouts: List.generate(5, (i) => _createDefaultWorkout(
        beginnerCycleId, 
        "mentzer_beg_w${i + 1}", 
        "DAY ${i + 1}", 
        i, 
        beginnerExercises
      )),
    );

    await addCycle(beginnerCycle);

    // Mentzer Productive Routine
    const productiveCycleId = "mentzer_productive_routine";
    final productiveCycle = TrainingCycle(
      id: productiveCycleId,
      name: "MENTZER PRODUCTIVE ROUTINE",
      description: "2 SESSIONS • HIGH INTENSITY SUPERSETS",
      isDefault: true,
      isSynced: 1,
      workouts: [
        _createDefaultWorkout(productiveCycleId, "mentzer_prod_w1", "WORKOUT ONE (MONDAY)", 0, [
          "Leg Extensions",
          "Squats",
          "Leg Curls",
          "Standing Calf Raises",
          "Toe Presses",
          "Dumbbell Flyes",
          "Incline Presses",
          "Dips",
          "Triceps Pressdowns",
          "Dips",
          "Lying Triceps Extensions"
        ]),
        _createDefaultWorkout(productiveCycleId, "mentzer_prod_w2", "WORKOUT TWO (WEDNESDAY)", 1, [
          "Nautilus Machine Pullovers",
          "Palms-Up Pulldowns",
          "Bent-Over Barbell Rows",
          "Shrugs",
          "Upright Rows",
          "Dumbbell Lateral Raises",
          "Machine Presses",
          "One-Arm Dumbbell Rows",
          "Standing Barbell Curls",
          "Concentration Curls"
        ]),
      ],
    );

    await addCycle(productiveCycle);

    // Mike Mentzer's One-Set Heavy Duty (Dorian Yates)
    const dorianCycleId = "mentzer_dorian_yates_routine";
    final dorianCycle = TrainingCycle(
      id: dorianCycleId,
      name: "ONE-SET HEAVY DUTY (DORIAN YATES)",
      description: "3 SESSIONS • THE 1992 OLYMPIA PROTOCOL",
      isDefault: true,
      isSynced: 1,
      workouts: [
        _createDefaultWorkout(dorianCycleId, "mentzer_dorian_w1", "MONDAY'S WORKOUT", 0, [
          "Dumbbell Flyes",
          "Machine Incline Presses",
          "Nautilus Lateral Raises",
          "Nautilus Rear Delt Raises",
          "Nautilus Machine Triceps Extensions",
          "Triceps Pressdowns"
        ]),
        _createDefaultWorkout(dorianCycleId, "mentzer_dorian_w2", "WEDNESDAY'S WORKOUT", 1, [
          "Nautilus Machine Pullovers",
          "Palms-Up Pulldowns",
          "Hammer Rows",
          "Hammer Shrugs",
          "Nautilus Machine Curls",
          "Preacher Curls"
        ]),
        _createDefaultWorkout(dorianCycleId, "mentzer_dorian_w3", "FRIDAY'S WORKOUT", 2, [
          "Leg Extensions",
          "Leg Presses",
          "Squats",
          "Leg Curls",
          "Stiff-Legged Deadlifts",
          "Standing Calf Raises"
        ]),
      ],
    );

    await addCycle(dorianCycle);
  }

  Workout _createDefaultWorkout(String cycleId, String workoutId, String name, int order, List<String> exerciseNames) {
    return Workout(
      id: workoutId,
      cycleId: cycleId,
      name: name,
      order: order,
      isSynced: 1,
      exercises: exerciseNames.asMap().entries.map((entry) {
        return Exercise(
          id: "${workoutId}_ex_${entry.key}", // Deterministic Exercise IDs
          workoutId: workoutId,
          name: entry.value,
          order: entry.key,
          isSynced: 1,
        );
      }).toList(),
    );
  }

  String? findMatchingTemplate(String cycleId) {
    final targetCycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: ""));
    if (targetCycle.id.isEmpty) return null;

    final templates = _cycles.where((c) => c.status == CycleStatus.template).toList();
    
    for (var template in templates) {
      if (template.workouts.length != targetCycle.workouts.length) continue;
      
      bool allWorkoutsMatch = true;
      // Sort both by order to ensure we compare correctly
      final tWorkouts = [...template.workouts]..sort((a, b) => a.order.compareTo(b.order));
      final cWorkouts = [...targetCycle.workouts]..sort((a, b) => a.order.compareTo(b.order));

      for (int i = 0; i < tWorkouts.length; i++) {
        final tw = tWorkouts[i];
        final cw = cWorkouts[i];

        if (tw.exercises.length != cw.exercises.length) {
          allWorkoutsMatch = false;
          break;
        }

        final tEx = [...tw.exercises]..sort((a, b) => a.order.compareTo(b.order));
        final cEx = [...cw.exercises]..sort((a, b) => a.order.compareTo(b.order));

        for (int j = 0; j < tEx.length; j++) {
          if (tEx[j].name.trim().toUpperCase() != cEx[j].name.trim().toUpperCase()) {
            allWorkoutsMatch = false;
            break;
          }
        }
        if (!allWorkoutsMatch) break;
      }

      if (allWorkoutsMatch) return template.name;
    }
    return null;
  }

  Future<void> saveCycleAsTemplate(String cycleId, String name) async {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId);
    
    final templateId = const Uuid().v4();
    final template = TrainingCycle(
      id: templateId,
      name: name.toUpperCase(),
      description: "CUSTOM ARCHITECTURE",
      status: CycleStatus.template,
      isDefault: false,
      isSynced: 0,
      workouts: cycle.workouts.map((w) {
        final nwId = const Uuid().v4();
        return w.copyWith(
          id: nwId,
          cycleId: templateId,
          status: WorkoutStatus.pending,
          completedAt: null,
          isSynced: 0,
          exercises: w.exercises.map((e) => e.copyWith(
            id: const Uuid().v4(),
            workoutId: nwId,
            isSynced: 0,
          )).toList(),
        );
      }).toList(),
    );

    await addCycle(template);
  }

  bool isUnmodifiedDefault(String cycleId) {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId, orElse: () => TrainingCycle(name: ""));
    if (cycle.id.isEmpty) return false;

    // A cycle is an unmodified default if its structure matches one of the internal Mentzer routines
    final matchingName = findMatchingTemplate(cycleId);
    if (matchingName == null) return false;

    final systemNames = [
      "IDEAL ROUTINE", 
      "CONSOLIDATED", 
      "BEGINNER ROUTINE", 
      "MENTZER PRODUCTIVE ROUTINE", 
      "ONE-SET HEAVY DUTY (DORIAN YATES)"
    ];
    
    return systemNames.contains(matchingName);
  }

  Future<String?> generateShareableLink(String cycleId, String userName) async {
    final cycle = _cycles.firstWhere((c) => c.id == cycleId);
    
    final Map<String, dynamic> shareData = {
      'name': cycle.name,
      'description': cycle.description ?? "SHARED HIT ROUTINE",
      'sender': userName,
      'workouts': cycle.workouts.map((w) => {
        'name': w.name,
        'order': w.order,
        'exercises': w.exercises.map((e) => {
          'name': e.name,
          'order': e.order,
          'target_muscles': e.targetMuscles,
        }).toList(),
      }).toList(),
    };

    try {
      final response = await _supabase.from('shared_data').insert({
        'data': shareData,
      }).select('id').single();

      final shareId = response['id'] as String;
      // Using the actual confirmed domain: heavydutyapp.org
      return "https://heavydutyapp.org/share/cycle?id=$shareId&from=${Uri.encodeComponent(userName)}";
    } catch (e) {
      debugPrint("Error generating share link: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchSharedCycle(String shareId) async {
    try {
      final response = await _supabase
          .from('shared_data')
          .select()
          .eq('id', shareId)
          .single();
      
      final createdAt = DateTime.parse(response['created_at']);
      final now = DateTime.now();
      
      if (now.difference(createdAt).inDays >= 7) {
        return {'expired': true};
      }

      return response['data'] as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error fetching shared cycle: $e");
      return null;
    }
  }

  Future<void> importSharedCycle(Map<String, dynamic> data) async {
    if (_localRepo == null) return;

    final String cycleName = (data['name'] as String).toUpperCase();
    final List workoutsData = data['workouts'] as List;

    final newCycleId = const Uuid().v4();
    final newCycle = TrainingCycle(
      id: newCycleId,
      name: "$cycleName (SHARED)",
      description: data['description'] ?? "SHARED HIT ROUTINE",
      status: CycleStatus.template,
      sharedBy: data['sender'] as String?,
      isDefault: false,
      isSynced: 0,
      workouts: workoutsData.asMap().entries.map((wEntry) {
        final w = wEntry.value;
        final nwId = const Uuid().v4();
        final List exercisesData = w['exercises'] as List;

        return Workout(
          id: nwId,
          cycleId: newCycleId,
          name: (w['name'] as String).toUpperCase(),
          order: wEntry.key,
          status: WorkoutStatus.pending,
          isSynced: 0,
          exercises: exercisesData.asMap().entries.map((eEntry) {
            final e = eEntry.value;
            return Exercise(
              id: const Uuid().v4(),
              workoutId: nwId,
              name: (e['name'] as String).toUpperCase(),
              order: eEntry.key,
              targetMuscles: e['target_muscles'],
              isSynced: 0,
            );
          }).toList(),
        );
      }).toList(),
    );

    await addCycle(newCycle);
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _cycles.clear();
    _logs.clear();
    _localRepo = null;
    notifyListeners();
  }
}
