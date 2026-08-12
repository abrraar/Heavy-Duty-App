// lib/features/tracker/supplement/model/supplement_item.dart

class SupplementItem {
  final String id;
  final String supplementId;
  final String supplementName;
  final String type;
  final String details;
  final double weightAdjustment;
  final DateTime timestamp;
  final String? sourceId; // NEW: Link to external triggers like Meal Logs
  int isSynced; 

  SupplementItem({
    required this.id,
    required this.supplementId,
    required this.supplementName,
    required this.type,
    required this.details,
    required this.weightAdjustment,
    required this.timestamp,
    required this.isSynced,
    this.sourceId,
  });

  // Convert to Map for Database Insertion
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplement_id': supplementId,
      'supplement_name': supplementName,
      'type': type,
      'details': details,
      'weight_adjustment': weightAdjustment,
      'timestamp': timestamp.toIso8601String(),
      'source_id': sourceId,
      'is_synced': isSynced,
    };
  }

  // Create from Map for Database Retrieval
  factory SupplementItem.fromMap(Map<String, dynamic> map) {
    return SupplementItem(
      id: map['id'] as String,
      supplementId: map['supplement_id'] as String,
      supplementName: map['supplement_name'] as String,
      type: map['type'] as String,
      details: map['details'] as String,
      weightAdjustment: (map['weight_adjustment'] as num).toDouble(),
      timestamp: DateTime.parse(map['timestamp'] as String),
      sourceId: map['source_id'] as String?,
      isSynced: map['is_synced'] as int,
    );
  }
}
