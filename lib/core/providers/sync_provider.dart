// lib/core/providers/sync_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';

enum SyncUIState { idle, online, syncing, completed }

class SyncProvider with ChangeNotifier {
  static final SyncProvider _instance = SyncProvider._internal();
  factory SyncProvider() => _instance;
  
  SyncUIState _state = SyncUIState.idle;
  int _totalItems = 0;
  int _completedItems = 0;
  int _activeFeatures = 0;
  bool _isSyncFlowStarted = false;
  Timer? _finalizeTimer;

  SyncUIState get state => _state;
  int get totalItems => _totalItems;
  int get completedItems => _completedItems;

  SyncProvider._internal() {
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() {
    // Reset counters but stay silent (idle)
    // We only wake up the UI if a provider reports > 0 unsynced items
    _totalItems = 0;
    _completedItems = 0;
    _isSyncFlowStarted = false;
    _activeFeatures = 0;
    // Don't notify listeners here to keep UI clean
  }

  void startFeatureSync() {
    _activeFeatures++;
    _finalizeTimer?.cancel();
  }

  void addTotalItems(int count) {
    // IGNORE 0 VALUES: Only increment the total if there is actual work to do.
    if (count <= 0) return;
    
    _totalItems += count;
    
    // Trigger the UI sequence only on the first piece of work found
    if (!_isSyncFlowStarted) {
      _startVisualSequence();
    } else {
      notifyListeners();
    }
  }

  Future<void> _startVisualSequence() async {
    if (_isSyncFlowStarted) return;
    _isSyncFlowStarted = true;

    // 1. Show "Internet Restored"
    _state = SyncUIState.online;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 2));

    // 2. Transition to "Syncing" bar
    // Check if we were cancelled or reset during wait
    if (_isSyncFlowStarted) {
      _state = SyncUIState.syncing;
      notifyListeners();
    }
  }

  void incrementCompleted() {
    _completedItems++;
    if (_completedItems > _totalItems) _totalItems = _completedItems;
    notifyListeners();
  }

  void endFeatureSync() {
    _activeFeatures--;
    if (_activeFeatures <= 0) {
      // Debounce finalize to ensure all features had a chance to report
      _finalizeTimer?.cancel();
      _finalizeTimer = Timer(const Duration(seconds: 2), () {
        if (_activeFeatures <= 0) {
          if (_state == SyncUIState.syncing || _state == SyncUIState.online) {
            finalizeSync();
          } else {
            // If we found 0 items across all features, just reset to idle
            _resetToIdle();
          }
        }
      });
    }
  }

  Future<void> finalizeSync() async {
    if (!_isSyncFlowStarted) return;
    
    // Ensure counter looks full for completion
    if (_completedItems < _totalItems) _completedItems = _totalItems;
    
    _state = SyncUIState.completed;
    notifyListeners();

    await Future.delayed(const Duration(seconds: 3));
    _resetToIdle();
  }

  void _resetToIdle() {
    _state = SyncUIState.idle;
    _totalItems = 0;
    _completedItems = 0;
    _isSyncFlowStarted = false;
    notifyListeners();
  }

  @override
  void dispose() {
    ConnectivityService().removeReconnectListener(_onReconnect);
    _finalizeTimer?.cancel();
    super.dispose();
  }
}
