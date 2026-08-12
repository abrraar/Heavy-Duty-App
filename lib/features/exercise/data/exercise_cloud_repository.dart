import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/exercise_template.dart';

class ExerciseCloudRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get _currentUserId => _supabase.auth.currentUser?.id;

  Future<List<ExerciseTemplate>> getAllTemplates() async {
    final uid = _currentUserId;
    if (uid == null) return [];

    try {
      final List<Map<String, dynamic>> response = await _supabase
          .from('exercise_templates')
          .select()
          .eq('user_id', uid)
          .order('name', ascending: true);

      return response.map((map) => ExerciseTemplate.fromMap(map)).toList();
    } catch (e) {
      debugPrint("Cloud Exercise Error (getAllTemplates): $e");
      return [];
    }
  }

  Future<void> insertTemplate(ExerciseTemplate template) async {
    final uid = _currentUserId;
    if (uid == null) {
      debugPrint("Cloud Exercise Error: No authenticated user session found.");
      return;
    }

    try {
      final Map<String, dynamic> data = {
        'id': template.id,
        'user_id': uid,
        'name': template.name,
        'target_muscles': template.targetMuscles,
        'intensity': template.intensity,
        'is_default': template.isDefault,
        'type': template.type.name,
        'about_the_movement': template.aboutTheMovement,
        'image_url': template.imageUrl,
      };
      
      // Standard upsert - Supabase handles the conflict using the Primary Key (id)
      await _supabase.from('exercise_templates').upsert(data);
          
      debugPrint("Cloud Exercise: Successfully saved ${template.name} to cloud.");
    } catch (e) {
      debugPrint("Cloud Exercise Error (insertTemplate): $e");
      // Re-throw so the provider knows the sync failed and keeps it marked as unsynced
      rethrow;
    }
  }

  Future<void> deleteTemplate(String id) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await _supabase.from('exercise_templates').delete().eq('id', id).eq('user_id', uid);
    } catch (e) {
      debugPrint("Cloud Exercise Error (deleteTemplate): $e");
    }
  }
}
