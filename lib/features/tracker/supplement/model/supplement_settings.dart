// lib/features/tracker/supplement/model/supplement_settings.dart

class SupplementSettings {
  final bool showExpired;
  final bool hideEmptyStock;
  final List<String> pinnedOrder; // IDs of pinned supplements and stacks in order
  final int isSynced;
  final String? userId;

  SupplementSettings({
    this.showExpired = true,
    this.hideEmptyStock = false,
    this.pinnedOrder = const [],
    this.isSynced = 1,
    this.userId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': 1, // Singleton row in SQLite
      'user_id': userId,
      'show_expired': showExpired ? 1 : 0,
      'hide_empty_stock': hideEmptyStock ? 1 : 0,
      'pinned_order_json': pinnedOrder.join(','),
      'is_synced': isSynced,
    };
  }

  factory SupplementSettings.fromMap(Map<String, dynamic> map) {
    bool toBool(dynamic val) {
      if (val is bool) return val;
      if (val is int) return val == 1;
      return true;
    }

    String orderRaw = map['pinned_order_json'] ?? '';

    return SupplementSettings(
      showExpired: toBool(map['show_expired']),
      hideEmptyStock: toBool(map['hide_empty_stock']),
      pinnedOrder: orderRaw.isEmpty ? [] : orderRaw.split(','),
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 1,
      userId: map['user_id'] as String?,
    );
  }

  SupplementSettings copyWith({
    bool? showExpired,
    bool? hideEmptyStock,
    List<String>? pinnedOrder,
    int? isSynced,
    String? userId,
  }) {
    return SupplementSettings(
      showExpired: showExpired ?? this.showExpired,
      hideEmptyStock: hideEmptyStock ?? this.hideEmptyStock,
      pinnedOrder: pinnedOrder ?? this.pinnedOrder,
      isSynced: isSynced ?? this.isSynced,
      userId: userId ?? this.userId,
    );
  }

}
