// lib/core/services/connectivity_service.dart

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final List<VoidCallback> _onReconnectListeners = [];
  bool _wasOffline = false;
  bool _isFirstCheck = true;

  void init() {
    Connectivity().onConnectivityChanged.listen((results) {
      debugPrint("ConnectivityService: Connection state changed: $results");
      
      final bool isCurrentlyOnline = results.any((r) => r != ConnectivityResult.none);

      if (_isFirstCheck) {
        _isFirstCheck = false;
        _wasOffline = !isCurrentlyOnline;
        debugPrint("ConnectivityService: Initial state is ${_wasOffline ? 'OFFLINE' : 'ONLINE'}. Staying silent.");
        return;
      }

      if (isCurrentlyOnline) {
        if (_wasOffline) {
          debugPrint("ConnectivityService: Internet RESTORED. Notifying listeners...");
          // Use a local copy to avoid ConcurrentModificationError
          final listenersCopy = List<VoidCallback>.from(_onReconnectListeners);
          for (var listener in listenersCopy) {
            listener();
          }
        }
        _wasOffline = false;
      } else {
        debugPrint("ConnectivityService: Device went OFFLINE.");
        _wasOffline = true;
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
