// lib/features/tracker/supplement/model/supplement_stack.dart

import 'dart:convert';
import 'package:heavy_duty/features/tracker/supplement/model/supplement.dart';

class SupplementStack {
  final String id;
  final String name;
  final List<Supplement> items;
  final bool isPinned; // Internal list pinning
  final bool isPinnedToHome; // NEW: Quick log on home screen
  final bool notificationsEnabled;
  final List<SupplementReminder> reminders;

  final String? sharedBy;

  // NEW: Snapshot fields to store specific card configurations
  final Map<String, bool>
  pinnedRecordModes; // itemID -> true (Record) / false (Restock)
  final Map<String, bool>
  pinnedUseServings; // itemID -> true (Servings) / false (Weight)
  final Map<String, double> pinnedAmounts; // itemID -> value (e.g. 5.0)

  SupplementStack({
    required this.id,
    required this.name,
    required this.items,
    this.isPinned = false,
    this.isPinnedToHome = false,
    this.notificationsEnabled = false,
    this.reminders = const [],
    this.sharedBy,
    this.pinnedRecordModes = const {},
    this.pinnedUseServings = const {},
    this.pinnedAmounts = const {},
  });

  // Maps the main shell details of a stack directly to rows inside your SQL 'stacks' table
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_pinned': isPinned ? 1 : 0,
      'is_pinned_to_home': isPinnedToHome ? 1 : 0,
      'notifications_enabled': notificationsEnabled ? 1 : 0,
      'reminders_json': jsonEncode(reminders.map((r) => r.toMap()).toList()),
      'shared_by': sharedBy,
      'pinned_record_modes_json': jsonEncode(pinnedRecordModes),
      'pinned_use_servings_json': jsonEncode(pinnedUseServings),
      'pinned_amounts_json': jsonEncode(
        pinnedAmounts.map((key, value) => MapEntry(key, value.toString())),
      ),
      // NEW: Extract only the IDs from your items and encode them as a list of strings
      'supplement_ids_json': jsonEncode(items.map((item) => item.id).toList()),
    };
  }

  // Decodes your relational database row variables back into clean nested models
  factory SupplementStack.fromMap(
    Map<String, dynamic> map,
    List<Supplement> parsedItems,
  ) {
    final List<dynamic> decodedReminders = map['reminders_json'] != null
        ? jsonDecode(map['reminders_json'] as String)
        : [];

    final Map<String, dynamic> rawModes =
        map['pinned_record_modes_json'] != null
        ? jsonDecode(map['pinned_record_modes_json'] as String)
        : {};
    final Map<String, dynamic> rawServings =
        map['pinned_use_servings_json'] != null
        ? jsonDecode(map['pinned_use_servings_json'] as String)
        : {};
    final Map<String, dynamic> rawAmounts = map['pinned_amounts_json'] != null
        ? jsonDecode(map['pinned_amounts_json'] as String)
        : {};

    return SupplementStack(
      id: map['id'] as String,
      name: map['name'] as String,
      isPinned: (map['is_pinned'] as int? ?? 0) == 1,
      isPinnedToHome: (map['is_pinned_to_home'] as int? ?? 0) == 1,
      notificationsEnabled: (map['notifications_enabled'] as int? ?? 0) == 1,
      items: parsedItems, // Re-connected using the repository layer matching logic below
      reminders: decodedReminders
          .map((r) => SupplementReminder.fromMap(r as Map<String, dynamic>))
          .toList(),
      sharedBy: map['shared_by'] as String?,
      pinnedRecordModes: rawModes.map((key, value) => MapEntry(key, value as bool)),
      pinnedUseServings: rawServings.map((key, value) => MapEntry(key, value as bool)),
      pinnedAmounts: rawAmounts.map((key, value) => MapEntry(key, double.parse(value.toString()))),
    );
  }

  SupplementStack copyWith({
    String? name,
    List<Supplement>? items,
    bool? isPinned,
    bool? isPinnedToHome,
    bool? notificationsEnabled,
    List<SupplementReminder>? reminders,
    String? sharedBy,
    Map<String, bool>? pinnedRecordModes,
    Map<String, bool>? pinnedUseServings,
    Map<String, double>? pinnedAmounts,
  }) {
    return SupplementStack(
      id: this.id,
      name: name ?? this.name,
      items: items ?? this.items,
      isPinned: isPinned ?? this.isPinned,
      isPinnedToHome: isPinnedToHome ?? this.isPinnedToHome,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminders: reminders ?? this.reminders,
      sharedBy: sharedBy ?? this.sharedBy,
      pinnedRecordModes: pinnedRecordModes ?? this.pinnedRecordModes,
      pinnedUseServings: pinnedUseServings ?? this.pinnedUseServings,
      pinnedAmounts: pinnedAmounts ?? this.pinnedAmounts,
    );
  }
}
