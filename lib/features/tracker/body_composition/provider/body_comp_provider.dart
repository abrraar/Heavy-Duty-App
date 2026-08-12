import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';
import '../model/body_comp_log.dart';
import '../data/body_comp_local_repository.dart';
import '../data/body_comp_cloud_repository.dart';

class BodyCompProvider with ChangeNotifier {
  BodyCompLocalRepository? _localRepo;
  final BodyCompCloudRepository _cloudRepo = BodyCompCloudRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  List<BodyCompLog> _logs = [];
  bool _isLoading = false;

  List<BodyCompLog> get logs => _logs;
  bool get isLoading => _isLoading;

  void initializeForUser(String userId) {
    _localRepo = BodyCompLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscriptions(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    debugPrint("BodyCompProvider: Reconnected. Triggering sync...");
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscriptions(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:body_comp_sync:$userId');

    final tables = ['weight_logs', 'body_fat_logs', 'muscle_mass_logs'];

    for (var table in tables) {
      _realtimeChannel!.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (payload) async {
          debugPrint("Realtime $table Update: ${payload.eventType}");
          
          final String? recordUserId = payload.newRecord['user_id'] ?? payload.oldRecord['user_id'];
          if (recordUserId != userId) return;

          final type = _getTypeFromTable(table);

          if (payload.newRecord.isNotEmpty) {
            final log = BodyCompLog.fromMap(payload.newRecord, type);
            
            final localLogs = await _localRepo!.getAllLogs();
            final localIdx = localLogs.indexWhere((l) => l.id == log.id);

            if (localIdx == -1 || localLogs[localIdx].isSynced == 1) {
              await _localRepo!.insertLog(log);
              
              final index = _logs.indexWhere((l) => l.id == log.id);
              if (index != -1) {
                _logs[index] = log;
              } else {
                _logs.add(log);
                _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
              }
              notifyListeners();
            }
          } else if (payload.eventType == PostgresChangeEvent.delete) {
            final String? id = payload.oldRecord['id'];
            if (id != null) {
              await _localRepo!.deleteLog(id, type);
              _logs.removeWhere((l) => l.id == id);
              notifyListeners();
            }
          }
        },
      );
    }

    _realtimeChannel!.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint("BodyCompProvider: Realtime Subscribed/Reconnected. Syncing...");
        await _syncLocalToCloud();
        await _loadData(silent: true);
      }
    });
  }

  BodyMetricType _getTypeFromTable(String table) {
    if (table == 'weight_logs') return BodyMetricType.weight;
    if (table == 'body_fat_logs') return BodyMetricType.fat;
    return BodyMetricType.muscle;
  }

  String _getTableFromType(BodyMetricType type) {
    if (type == BodyMetricType.weight) return 'weight_logs';
    if (type == BodyMetricType.fat) return 'body_fat_logs';
    return 'muscle_mass_logs';
  }

  Future<void> _syncLocalToCloud() async {
    if (_localRepo == null) return;

    // 1. Push Unsynced Deletions
    final deletions = await _localRepo!.getPendingDeletions();
    for (var del in deletions) {
      final id = del['id'] as String;
      final table = del['table_name'] as String;
      final type = _getTypeFromTable(table);
      try {
        await _cloudRepo.deleteLog(id, type);
        await _localRepo!.removeFromDeletionQueue(id);
      } catch (_) {}
    }

    // 2. Push Unsynced Logs
    final unsyncedLogs = await _localRepo!.getUnsyncedLogs();
    for (var log in unsyncedLogs) {
      try {
        await _cloudRepo.insertLog(log);
        await _localRepo!.markLogSynced(log.id, log.type);
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
        final localMap = {for (var l in localLogs) l.id: l};
        final cloudIds = cloudLogs.map((l) => l.id).toSet();

        bool logChanged = false;

        // 1. Delete local logs that are synced but missing from cloud
        for (var localLog in localLogs) {
          if (localLog.isSynced == 1 && !cloudIds.contains(localLog.id)) {
            await _localRepo!.deleteLog(localLog.id, localLog.type);
            logChanged = true;
          }
        }

        // 2. Add/Update logs from cloud
        for (var log in cloudLogs) {
          final localL = localMap[log.id];
          if (localL == null || localL.isSynced == 1) {
            await _localRepo!.insertLog(log);
            logChanged = true;
          }
        }
        if (logChanged) _logs = await _localRepo!.getAllLogs();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading body comp data: $e");
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
      debugPrint("BodyCompProvider: FORCE REFRESH TRIGGERED");
      await _syncLocalToCloud();
      await _loadData(silent: true);
      debugPrint("BodyCompProvider: Force Refresh Complete.");
    } catch (e) {
      debugPrint("BodyCompProvider: Force Refresh Error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLog(BodyCompLog log) async {
    if (_localRepo == null) return;
    final localLog = log.copyWith(isSynced: 0);
    _logs.add(localLog);
    _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    notifyListeners();

    try {
      await _localRepo!.insertLog(localLog);
      _syncBodyCompLog(localLog);
    } catch (e) {
      debugPrint("Error saving body comp log locally: $e");
    }
  }

  Future<void> _syncBodyCompLog(BodyCompLog log) async {
    try {
      await _cloudRepo.insertLog(log);
      await _localRepo!.markLogSynced(log.id, log.type);
      final idx = _logs.indexWhere((l) => l.id == log.id);
      if (idx != -1) {
        _logs[idx] = log.copyWith(isSynced: 1);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Background Sync Error (Body Comp Add): $e");
    }
  }

  Future<void> deleteLog(String id, BodyMetricType type) async {
    if (_localRepo == null) return;
    _logs.removeWhere((l) => l.id == id);
    notifyListeners();

    try {
      await _localRepo!.deleteLog(id, type);
      await _localRepo!.addToDeletionQueue(id, _getTableFromType(type));
      _syncBodyCompDelete(id, type);
    } catch (e) {
      debugPrint("Error deleting body comp log locally: $e");
    }
  }

  Future<void> _syncBodyCompDelete(String id, BodyMetricType type) async {
    try {
      await _cloudRepo.deleteLog(id, type);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) {
      debugPrint("Background Sync Error (Body Comp Delete): $e");
    }
  }

  void clearUserData() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _realtimeChannel?.unsubscribe();
    _logs.clear();
    _localRepo = null;
    notifyListeners();
  }
}
