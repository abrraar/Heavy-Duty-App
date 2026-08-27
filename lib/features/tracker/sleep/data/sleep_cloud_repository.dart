// lib/features/tracker/sleep/data/sleep_cloud_repository.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/sleep_log.dart';
import '../model/sleep_settings.dart';

class SleepCloudRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // --- Settings ---

  Future<SleepSettings?> getSettings() async {
    final uid = _currentUserId;
    if (uid == null) return null;

    try {
      final response = await _supabase
          .from('sleep_settings')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (response != null) return SleepSettings.fromMap(response);
    } catch (e) {
      debugPrint("Cloud Sleep Error (getSettings): $e");
    }
    return null;
  }

  Future<void> saveSettings(SleepSettings settings) async {
    final uid = _currentUserId;
    if (uid == null) return;

    final data = settings.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    await _supabase.from('sleep_settings').upsert(data, onConflict: 'user_id');
  }

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

    final data = log.toMap();
    data['user_id'] = uid;
    data.remove('is_synced');
    await _supabase.from('sleep_logs').upsert(data, onConflict: 'id');
  }

  Future<void> deleteLog(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    await _supabase.from('sleep_logs').delete().eq('id', id).eq('user_id', uid);
  }
}
