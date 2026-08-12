// lib/features/tracker/sleep/data/sleep_cloud_repository.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/sleep_log.dart';

class SleepCloudRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<SleepLog>?> getAllLogs() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('sleep_logs')
          .select()
          .eq('user_id', uid)
          .order('bedtime', ascending: false);

      return response.map((map) => SleepLog.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Sleep Error (getAllLogs): $e");
      rethrow;
    }
  }

  Future<void> insertLog(SleepLog log) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      final data = log.toMap();
      data['user_id'] = uid;
      data.remove('is_synced');
      await _supabase.from('sleep_logs').upsert(data, onConflict: 'id');
    } catch (e) {
      debugPrint("Cloud Sleep Error (insertLog): $e");
    }
  }

  Future<void> deleteLog(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('sleep_logs').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Sleep Error (deleteLog): $e");
    }
  }
}
