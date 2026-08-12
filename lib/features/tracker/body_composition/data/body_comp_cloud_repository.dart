import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/body_comp_log.dart';

class BodyCompCloudRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  String _getTableName(BodyMetricType type) {
    switch (type) {
      case BodyMetricType.weight: return 'weight_logs';
      case BodyMetricType.fat: return 'body_fat_logs';
      case BodyMetricType.muscle: return 'muscle_mass_logs';
    }
  }

  Future<List<BodyCompLog>?> getAllLogs() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<BodyCompLog> allLogs = [];
      
      for (var type in BodyMetricType.values) {
        final List<Map<String, dynamic>> response = await _supabase
            .from(_getTableName(type))
            .select()
            .eq('user_id', uid)
            .order('timestamp', ascending: false);
            
        allLogs.addAll(response.map((map) => BodyCompLog.fromMap(map, type)));
      }
      
      allLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return allLogs;
    } catch (e) {
      debugPrint("Cloud Body Comp Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(BodyCompLog log) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = log.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');
      await _supabase.from(_getTableName(log.type)).upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Body Comp Error (insertLog): $e");
    }
  }

  Future<void> deleteLog(String id, BodyMetricType type) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from(_getTableName(type)).delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Body Comp Error (deleteLog): $e");
    }
  }
}
