import 'package:flutter/material.dart';
import '../data/ui_local_repository.dart';
import '../data/ui_cloud_repository.dart';
import '../models/ui_settings.dart';

class UiProvider with ChangeNotifier {
  UiLocalRepository? _localRepo;
  final UiCloudRepository _cloudRepo = UiCloudRepository();
  UiSettings _settings = UiSettings();
  bool _isLoading = false;

  UiSettings get settings => _settings;
  bool get isLoading => _isLoading;

  void initializeForUser(String userId) {
    _localRepo = UiLocalRepository(userId: userId);
    _loadData();
  }

  Future<void> _loadData() async {
    if (_localRepo == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Load Local
      final localMap = await _localRepo!.getSettings();
      if (localMap != null) {
        _settings = UiSettings.fromMap(localMap);
        notifyListeners();
      }

      // 2. Sync from Cloud
      final cloudMap = await _cloudRepo.getSettings();
      if (cloudMap != null) {
        _settings = UiSettings.fromMap(cloudMap);
        await _localRepo!.saveSettings(_settings.toMap());
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error loading UI settings: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> forceRefresh() async {
    await _loadData();
  }

  Future<void> updateHomeLayout(List<String> newLayout) async {
    _settings = _settings.copyWith(homeLayout: newLayout, isSynced: 0);
    notifyListeners();

    if (_localRepo != null) {
      try {
        await _localRepo!.saveSettings(_settings.toMap());
        
        // Push to Cloud
        await _cloudRepo.saveSettings(_settings.toMap());
        
        await _localRepo!.markSettingsSynced();
        _settings = _settings.copyWith(isSynced: 1);
        notifyListeners();
      } catch (e) {
        debugPrint("Error saving UI settings: $e");
      }
    }
  }

  void clearUserData() {
    _settings = UiSettings();
    _localRepo = null;
    notifyListeners();
  }
}
