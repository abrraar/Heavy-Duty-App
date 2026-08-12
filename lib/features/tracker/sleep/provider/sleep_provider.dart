// lib/features/tracker/sleep/provider/sleep_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';
import '../data/sleep_local_repository.dart';
import '../data/sleep_cloud_repository.dart';
import '../model/sleep_log.dart';

class SleepProvider with ChangeNotifier {
  SleepLocalRepository? _localRepo;
  final SleepCloudRepository _cloudRepo = SleepCloudRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  List<SleepLog> _logs = [];
  bool _isLoading = false;

  List<SleepLog> get logs => _logs;
  bool get isLoading => _isLoading;

  void initializeForUser(String userId) {
    _localRepo = SleepLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("SleepProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:sleep_sync:$userId');

    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sleep_logs',
      callback: (payload) async {
        debugPrint("Realtime Sleep Log Update: ${payload.eventType}");
        
        final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
        if (recordUserId != userId) return;

        if (payload.newRecord.isNotEmpty) {
          final log = SleepLog.fromMap(payload.newRecord);
          await _localRepo!.insertLog(log);
          
          final index = _logs.indexWhere((l) => l.id == log.id);
          if (index != -1) {
            _logs[index] = log;
          } else {
            _logs.insert(0, log);
            _logs.sort((a, b) => b.bedtime.compareTo(a.bedtime));
          }
          notifyListeners();
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

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("SleepProvider: Realtime Subscribed/Reconnected. Syncing...");
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
      try {
        await _cloudRepo.deleteLog(id);
        await _localRepo!.removeFromDeletionQueue(id);
      } catch (_) {}
    }

    // 2. Push Unsynced Logs
    final unsyncedLogs = await _localRepo!.getUnsyncedLogs();
    for (var log in unsyncedLogs) {
      try {
        await _cloudRepo.insertLog(log);
        await _localRepo!.markLogSynced(log.id);
      } catch (_) {}
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_localRepo == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _logs = await _localRepo!.getAllLogs();
      notifyListeners();

      final cloudLogs = await _cloudRepo.getAllLogs();
      if (cloudLogs != null) {
        final localLogs = await _localRepo!.getAllLogs();
        final localMap = {for (var log in localLogs) log.id: log};
        final cloudIds = cloudLogs.map((l) => l.id).toSet();

        bool logChanged = false;

        // 1. Delete local logs that are synced but missing from cloud
        for (var localLog in localLogs) {
          if (localLog.isSynced == 1 && !cloudIds.contains(localLog.id)) {
            await _localRepo!.deleteLog(localLog.id);
            logChanged = true;
          }
        }

        // 2. Add/Update logs from cloud
        for (var log in cloudLogs) {
          final localLog = localMap[log.id];
          if (localLog == null || localLog.isSynced == 1) {
            await _localRepo!.insertLog(log);
            logChanged = true;
          }
        }
        if (logChanged) _logs = await _localRepo!.getAllLogs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading sleep data: $e");
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> forceRefresh() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();
    
    try {
      debugPrint("SleepProvider: FORCE REFRESH TRIGGERED");
      await _syncLocalToCloud();
      await _loadData(silent: true);
      debugPrint("SleepProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("SleepProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSleepLog(SleepLog log) async {
    if (_localRepo == null) return;
    final localLog = log.copyWith(isSynced: 0);

    _logs.insert(0, localLog);
    _logs.sort((a, b) => b.bedtime.compareTo(a.bedtime));
    notifyListeners();

    try {
      await _localRepo!.insertLog(localLog);
      await _cloudRepo.insertLog(localLog);
      await _localRepo!.markLogSynced(localLog.id);
      final idx = _logs.indexWhere((l) => l.id == localLog.id);
      if (idx != -1) _logs[idx] = localLog.copyWith(isSynced: 1);
    } catch (e) {
      debugPrint("Error saving sleep log: $e");
    }
  }

  Future<void> deleteLog(String id) async {
    if (_localRepo == null) return;

    _logs.removeWhere((l) => l.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteLog(id);
      await _localRepo!.addToDeletionQueue(id, 'sleep_logs');
      await _cloudRepo.deleteLog(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Error deleting sleep log: $e");
    }
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _logs.clear();
    _localRepo = null;
    notifyListeners();
  }

  Duration get averageDuration {
    if (_logs.isEmpty) return Duration.zero;
    final total = _logs.fold(Duration.zero, (prev, log) => prev + log.duration);
    return Duration(minutes: total.inMinutes ~/ _logs.length);
  }

  int get averageQuality {
    if (_logs.isEmpty) return 0;
    final total = _logs.fold(0, (prev, log) => prev + log.quality);
    return total ~/ _logs.length;
  }

  SleepLog? findOverlap(DateTime start, DateTime end) {
    for (var log in _logs) {
      // Logic: new range overlaps existing range if NOT (newEnd <= existingStart OR newStart >= existingEnd)
      if (!(end.isBefore(log.bedtime) || end.isAtSameMomentAs(log.bedtime) || 
            start.isAfter(log.wakeUpTime) || start.isAtSameMomentAs(log.wakeUpTime))) {
        return log;
      }
    }
    return null;
  }
}
