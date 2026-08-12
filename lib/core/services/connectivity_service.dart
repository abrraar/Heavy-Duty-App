// lib/core/services/connectivity_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final List<VoidCallback> _onReconnectListeners = [];

  void init() {
    Connectivity().onConnectivityChanged.listen((results) {
      debugPrint("Connectivity Changed: $results");
      if (results.any((r) => r != ConnectivityResult.none)) {
        debugPrint("ConnectivityService: Internet restored. Notifying listeners...");
        // Use a local copy to avoid ConcurrentModificationError if a listener removes itself
        final listenersCopy = List<VoidCallback>.from(_onReconnectListeners);
        for (var listener in listenersCopy) {
          listener();
        }
      }
    });
  }

  void addReconnectListener(VoidCallback listener) {
    if (!_onReconnectListeners.contains(listener)) {
      _onReconnectListeners.add(listener);
    }
  }

  void removeReconnectListener(VoidCallback listener) {
    _onReconnectListeners.remove(listener);
  }
}
