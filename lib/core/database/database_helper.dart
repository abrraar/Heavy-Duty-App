// lib/core/database/database_helper.dart

import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  
  DatabaseHelper._init();

  Future<Database> getDatabaseForUser(String userId) async {
    final dbName = 'user_${userId}_tracker.db';
    return await _initDB(dbName);
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  Future _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future _createDB(Database db, int version) async {
    // 1. Supplement Library Table
    await db.execute('''
      CREATE TABLE supplements (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        serving_unit TEXT,
        weight_per_serving REAL,
        weight_unit TEXT,
        total_stock REAL,
        remaining_stock REAL,
        is_active INTEGER DEFAULT 1,
        notifications_enabled INTEGER DEFAULT 0,
        expiry_date TEXT,
        calories_per_unit REAL,
        protein_per_unit REAL DEFAULT 0.0,
        carbs_per_unit REAL DEFAULT 0.0,
        fats_per_unit REAL DEFAULT 0.0,
        shared_by TEXT,
        is_pinned_to_home INTEGER DEFAULT 0,
        pinned_intake_amount REAL DEFAULT 1.0,
        pinned_use_servings_intake INTEGER DEFAULT 1,
        pinned_restock_amount REAL DEFAULT 0.0,
        pinned_use_servings_restock INTEGER DEFAULT 1,
        reminders_json TEXT,
        ingredients_json TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 2. Stacks Table
    await db.execute('''
      CREATE TABLE stacks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_pinned INTEGER DEFAULT 0,
        is_pinned_to_home INTEGER DEFAULT 0,
        notifications_enabled INTEGER DEFAULT 0,
        reminders_json TEXT,
        shared_by TEXT,
        pinned_record_modes_json TEXT,
        pinned_use_servings_json TEXT,
        pinned_amounts_json TEXT,
        supplement_ids_json TEXT, 
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 3. History Table
    await db.execute('''
      CREATE TABLE history (
        id TEXT PRIMARY KEY,
        supplement_id TEXT NOT NULL,
        supplement_name TEXT NOT NULL,
        type TEXT NOT NULL,
        details TEXT NOT NULL,
        weight_adjustment REAL NOT NULL,
        timestamp TEXT NOT NULL,
        source_id TEXT,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // 4. Hydration Logs Table
    await db.execute('''
      CREATE TABLE hydration_logs (
        id TEXT PRIMARY KEY,
        amount INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 5. Hydration Settings Table
    await db.execute('''
      CREATE TABLE hydration_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        daily_goal INTEGER DEFAULT 3500,
        use_metric INTEGER DEFAULT 1,
        add_value INTEGER DEFAULT 250,
        minus_value INTEGER DEFAULT 250,
        reminders_enabled INTEGER DEFAULT 1,
        is_pinned_to_home INTEGER DEFAULT 1,
        reminders_json TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 6. Sleep Logs Table
    await db.execute('''
      CREATE TABLE sleep_logs (
        id TEXT PRIMARY KEY,
        bedtime TEXT NOT NULL,
        wake_up_time TEXT NOT NULL,
        quality INTEGER NOT NULL,
        type TEXT NOT NULL,
        note TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 7. Sleep Alarm Settings Table
    await db.execute('''
      CREATE TABLE sleep_alarm_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        bedtime_enabled INTEGER DEFAULT 0,
        bedtime_hour INTEGER DEFAULT 22,
        bedtime_minute INTEGER DEFAULT 30,
        bedtime_audio_path TEXT,
        wake_up_enabled INTEGER DEFAULT 0,
        wake_up_hour INTEGER DEFAULT 6,
        wake_up_minute INTEGER DEFAULT 45,
        wake_up_audio_path TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 8. Calorie Logs Table
    await db.execute('''
      CREATE TABLE calorie_logs (
        id TEXT PRIMARY KEY,
        meal_name TEXT NOT NULL,
        food_items TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL DEFAULT 0.0,
        carbs REAL DEFAULT 0.0,
        fats REAL DEFAULT 0.0,
        timestamp TEXT NOT NULL,
        added_supplements_json TEXT,
        added_stacks_json TEXT,
        servings REAL DEFAULT 1.0,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 9. Calorie Settings Table
    await db.execute('''
      CREATE TABLE calorie_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        daily_calorie_goal INTEGER DEFAULT 2800,
        protein_percent INTEGER DEFAULT 30,
        carb_percent INTEGER DEFAULT 50,
        fat_percent INTEGER DEFAULT 20,
        track_macros INTEGER DEFAULT 1,
        show_remaining INTEGER DEFAULT 1,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 10. Saved Meals Table
    await db.execute('''
      CREATE TABLE saved_meals (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        food_items TEXT NOT NULL,
        calories REAL NOT NULL,
        protein REAL DEFAULT 0.0,
        carbs REAL DEFAULT 0.0,
        fats REAL DEFAULT 0.0,
        is_pinned_to_home INTEGER DEFAULT 0,
        notifications_enabled INTEGER DEFAULT 0,
        reminders_json TEXT,
        added_supplements_json TEXT,
        added_stacks_json TEXT,
        servings REAL DEFAULT 1.0,
        multiply_supps INTEGER DEFAULT 1,
        shared_by TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 11. Body Composition Tables
    await db.execute('''
      CREATE TABLE weight_logs (
        id TEXT PRIMARY KEY,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        unit TEXT DEFAULT 'kg',
        is_synced INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE body_fat_logs (
        id TEXT PRIMARY KEY,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        unit TEXT DEFAULT 'percentage',
        is_synced INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE muscle_mass_logs (
        id TEXT PRIMARY KEY,
        value REAL NOT NULL,
        timestamp TEXT NOT NULL,
        unit TEXT DEFAULT 'kg',
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 12. Training Cycles Table
    await db.execute('''
      CREATE TABLE training_cycles (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_default INTEGER DEFAULT 0,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        note TEXT,
        shared_by TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 13. Workouts Table
    await db.execute('''
      CREATE TABLE workouts (
        id TEXT PRIMARY KEY,
        cycle_id TEXT NOT NULL,
        name TEXT NOT NULL,
        workout_order INTEGER NOT NULL,
        status TEXT NOT NULL,
        completed_at TEXT,
        note TEXT,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (cycle_id) REFERENCES training_cycles (id) ON DELETE CASCADE
      )
    ''');

    // 14. Exercises Table
    await db.execute('''
      CREATE TABLE exercises (
        id TEXT PRIMARY KEY,
        workout_id TEXT NOT NULL,
        name TEXT NOT NULL,
        exercise_order INTEGER NOT NULL,
        target_muscles TEXT,
        is_synced INTEGER DEFAULT 1,
        FOREIGN KEY (workout_id) REFERENCES workouts (id) ON DELETE CASCADE
      )
    ''');

    // 15. Exercise Logs Table
    await db.execute('''
      CREATE TABLE exercise_logs (
        id TEXT PRIMARY KEY,
        exercise_id TEXT NOT NULL,
        weight REAL NOT NULL,
        positive_reps INTEGER NOT NULL,
        static_hold_seconds INTEGER DEFAULT 0,
        negative_reps INTEGER DEFAULT 0,
        forced_reps INTEGER DEFAULT 0,
        comment TEXT,
        timestamp TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 16. Exercise Templates Table
    await db.execute('''
      CREATE TABLE exercise_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        target_muscles TEXT,
        intensity INTEGER DEFAULT 3,
        is_default INTEGER DEFAULT 0,
        type TEXT DEFAULT 'isolation',
        about_the_movement TEXT,
        image_url TEXT,
        shared_by TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 17. Cycle Settings Table
    await db.execute('''
      CREATE TABLE cycle_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        weight_unit TEXT DEFAULT 'lbs',
        visible_metrics_json TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 18. Sync Deletions Queue Table
    await db.execute('''
      CREATE TABLE pending_deletions (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL
      )
    ''');

    // 19. UI Settings Table
    await db.execute('''
      CREATE TABLE ui_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        home_layout_json TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 20. Affirmations Table
    await db.execute('''
      CREATE TABLE affirmations (
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        is_custom INTEGER DEFAULT 1,
        display_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        is_synced INTEGER DEFAULT 1
      )
    ''');

    // 21. Affirmation Settings Table
    await db.execute('''
      CREATE TABLE affirmation_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        rotation_minutes INTEGER DEFAULT 60,
        rotation_mode TEXT DEFAULT 'random',
        show_system INTEGER DEFAULT 1,
        show_custom INTEGER DEFAULT 1,
        order_direction TEXT DEFAULT 'asc',
        custom_order_json TEXT,
        is_synced INTEGER DEFAULT 1
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE supplements ADD COLUMN shared_by TEXT');
      await db.execute('ALTER TABLE stacks ADD COLUMN shared_by TEXT');
      await db.execute('ALTER TABLE saved_meals ADD COLUMN shared_by TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE training_cycles ADD COLUMN shared_by TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE exercise_templates ADD COLUMN shared_by TEXT');
    }
  }
}
