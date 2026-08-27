import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:heavy_duty/core/services/connectivity_service.dart';
import '../model/affirmation.dart';
import '../model/affirmation_settings.dart';
import '../data/affirmation_local_repository.dart';
import '../data/affirmation_cloud_repository.dart';

import 'package:heavy_duty/core/providers/sync_provider.dart';

class AffirmationProvider with ChangeNotifier {
  AffirmationLocalRepository? _localRepo;
  final AffirmationCloudRepository _cloudRepo = AffirmationCloudRepository();
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;

  List<Affirmation> _customAffirmations = [];
  Affirmation? _currentAffirmation;
  AffirmationSettings _settings = AffirmationSettings();
  bool _isLoading = false;
  Timer? _rotationTimer;
  int _currentIndex = 0;

  List<Affirmation> get customAffirmations => _customAffirmations;
  AffirmationSettings get settings => _settings;
  Affirmation? get currentAffirmation => _currentAffirmation;
  bool get isLoading => _isLoading;

  final List<Affirmation> _defaultAffirmations = [
    Affirmation(id: 'def_1', text: "Learning and moving ahead is accomplished by trial and error. We begin by taking a shot and missing the mark. Then we note the error, make the proper adjustments and take another shot — in this way proceeding to our target, our goal.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_2', text: "Mankind's progress broke down, people turned away from the teachings of Aristotle that is they rejected logic reason knowledge progress and even freedom, when you reject reason science and progress you also lose your freedom.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_3', text: "The proper attitude is to go into the gym like a rational human being and perform only the precise amount of exercise required by nature. More is not better; less is not better; the precise amount required is best.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_4', text: "Don't make the mistake of comparing yourself to others. The only person you can accurately compare yourself to is . . . YOU !", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_5', text: "When in possession of a valid theory-no matter what the field of endeavor and you're making the proper practical application, progress should literally be almost spectacular all the time.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_6', text: "Either one continues to gain knowledge and progress morally or he does not and goes backwards.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_7', text: "The concept of overtraining, unwilling or unable to define the term, only dimly aware that it means something negative, they use it as a 'floating abstraction,' i.e., a concept with no ties to reality. As such it is not so much misused, but barely used at all, and plays no significant role in their thinking.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_8', text: "The principle of intensity refers almost exclusively to the human will and the ability to command your muscles to contract against the only real resistance-your own mind.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_9', text: "Reality dictates how you must guide your training efforts to successfully develop larger muscles; and the nature of reason determines how you must guide your thinking so as to achieve intellectual independence.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_10', text: "Discovering exactly what you want is the hard part, since a rigorous and structured self-examination is required-a kind of spiritual search.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_11', text: "The mind is actually very much like a muscle in that only through persistent training can it's capacity be stretched.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_12', text: "Don't be duped into believing that successful individuals possess some mystical endowment, and then tear your hair out wondering if you have it. Neither is the high-level motivation-and the associated self-confidence-an accident of birth randomly bestowed upon a blessed few. Rather, it is in fact a trait that can be cultivated by anyone.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_13', text: "A few rational ideas will put a halt to your seemingly endless' irrational negative doubts and restore peace and calm within your soul.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_14', text: "It is only within the context of having a proper developed mind that you will be able to truly enjoy the achievements of your material values, including that of a more muscular body.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_15', text: "Negative thoughts and comments seem to program the individual to behave in a like manner. Think positively, speak positively, and you'll act accordingly.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_16', text: "I know that it is difficult to accept ideas that are new, especially if they happen to challenge that which is near and dear to you. But remember -- if you want to lead the orchestra, you have to turn your back on the crowd.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_17', text: "The conformist declares: 'I believe it because others believe it.' The non-conformist, just as irrational, says: 'I don’t believe it because others do.' That rare third person, the individualist, declares: 'I believe it because I can see the reasons it’s true.'", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_18', text: "If you abdicate the responsibility of learning the nature of your own consciousness, your means of survival, then you can never control it: thus you unknowingly deliver yourself into the power of someone other than you–someone who might just have your worst interests at heart.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_19', text: "The most important thing, I think, is motivation—everyone can improve themselves—and that's important. Not everyone is going to become Mr.Olympia, but we can all improve ourselves.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_20', text: "Win or lose, you are a winner for having realized a personal ambition and overcome all the obstacles you did to get here!", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_21', text: "Don't just be a bodybuilder, let your muscles serve as an expression of your victorious will and your glorious reason. Be the greatest damned bodybuilder YOU can possibly be!", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_22', text: "Don't vanish into the vast swamp of mediocrity by believing maturity is gained by abandoning one's ideals, values, and goals and ultimately, losing self-esteem. Hold on to that noble vision, don't betray that fire; give it shape, reality, and purpose.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_23', text: "One cannot actualize his goals until he visualizes them clearly in the mind's eye.", speaker: "Mike Mentzer", isCustom: false),
    Affirmation(id: 'def_24', text: "Man's proper stature is not one of mediocrity, failure, frustration, or defeat, but one of achievement, strength, and nobility. In short, man can and ought to be a hero.", speaker: "Mike Mentzer", isCustom: false),
  ];

  List<Affirmation> get affirmations {
    final List<Affirmation> list = [];
    if (_settings.showSystem) list.addAll(_defaultAffirmations);
    if (_settings.showCustom) list.addAll(_customAffirmations);
    
    // Sort based on settings if needed, for now just follow standard order
    // But since it's a wheel, the caller might want the full list.
    return list;
  }

  // To show all in library tabs regardless of filter
  List<Affirmation> get allSystemAffirmations => _defaultAffirmations;
  List<Affirmation> get allCustomAffirmations => _customAffirmations;

  void initializeForUser(String userId) {
    _localRepo = AffirmationLocalRepository(userId: userId);
    _loadData();
    _setupRealtimeSubscription(userId);
    ConnectivityService().addReconnectListener(_onReconnect);
  }

  void _onReconnect() async {
    await _syncLocalToCloud();
    await _loadData(silent: true);
  }

  void _setupRealtimeSubscription(String userId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = _supabase.channel('public:affirmations_sync:$userId');
    _realtimeChannel!.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'affirmations',
      callback: (payload) async {
        if (payload.newRecord.isNotEmpty) {
          final affirmation = Affirmation.fromMap(payload.newRecord);
          await _localRepo!.insertAffirmation(affirmation);
          _refreshList();
        } else if (payload.eventType == PostgresChangeEvent.delete) {
          final String? id = payload.oldRecord['id'];
          if (id != null) {
            await _localRepo!.deleteAffirmation(id);
            _refreshList();
          }
        }
      },
    );
    _realtimeChannel!.subscribe();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_localRepo == null) return;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      // MANDATORY: Push local offline changes BEFORE pulling from cloud
      await _syncLocalToCloud();

      _customAffirmations = await _localRepo!.getAllAffirmations();
      _settings = await _localRepo!.getSettings();
      _updateCurrentAffirmation();
      _startRotation();
      notifyListeners();

      final cloudAffs = await _cloudRepo.getAllAffirmations();
      if (cloudAffs != null) {
        final localAffs = await _localRepo!.getAllAffirmations();
        final cloudIds = cloudAffs.map((a) => a.id).toSet();

        // Deletion Reconciliation: Remove local synced affirmations missing from cloud
        for (var localA in localAffs) {
          if (localA.isSynced == 1 && !cloudIds.contains(localA.id)) {
            await _localRepo!.deleteAffirmation(localA.id);
          }
        }

        for (var aff in cloudAffs) {
          await _localRepo!.insertAffirmation(aff, isFromCloud: true);
        }
        _customAffirmations = await _localRepo!.getAllAffirmations();
      }
      final cloudSettings = await _cloudRepo.getSettings();
      if (cloudSettings != null) {
        await _localRepo!.saveSettings(cloudSettings, isFromCloud: true);
        _settings = await _localRepo!.getSettings();
      }
      _updateCurrentAffirmation();
      _startRotation();
    } finally {
      if (!silent) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _refreshList() async {
    if (_localRepo == null) return;
    _customAffirmations = await _localRepo!.getAllAffirmations();
    _updateCurrentAffirmation();
    notifyListeners();
  }

  bool _lastWasSystem = true;

  void _updateCurrentAffirmation() {
    final List<Affirmation> systemItems = _settings.showSystem ? _defaultAffirmations : [];
    final List<Affirmation> customItems = _settings.showCustom ? _customAffirmations : [];
    
    final List<Affirmation> available = [];
    if (_settings.orderDirection == 'desc') {
      available.addAll([...systemItems.reversed, ...customItems.reversed]);
    } else {
      available.addAll([...systemItems, ...customItems]);
    }

    if (available.isEmpty) {
      _currentAffirmation = null;
      notifyListeners();
      return;
    }

    if (_settings.rotationMode == 'random') {
      _currentAffirmation = available[Random().nextInt(available.length)];
    } else if (_settings.rotationMode == 'alternative') {
      // Toggle between system and custom if both are available
      if (systemItems.isNotEmpty && customItems.isNotEmpty) {
        if (_lastWasSystem) {
          _currentAffirmation = customItems[Random().nextInt(customItems.length)];
          _lastWasSystem = false;
        } else {
          _currentAffirmation = systemItems[Random().nextInt(systemItems.length)];
          _lastWasSystem = true;
        }
      } else {
        // Fallback to random if only one type is available
        _currentAffirmation = available[Random().nextInt(available.length)];
      }
    } else {
      // 'continuous' - follows the order as placed
      _currentIndex = (_currentIndex + 1) % available.length;
      _currentAffirmation = available[_currentIndex];
    }
    notifyListeners();
  }

  void setManualAffirmation(Affirmation affirmation) {
    _currentAffirmation = affirmation;
    // Find index in current filtered list for 'continuous' mode tracking
    final list = affirmations;
    final idx = list.indexWhere((a) => a.id == affirmation.id);
    if (idx != -1) _currentIndex = idx;
    
    notifyListeners();
    _startRotation(); // Restart timer to give user full duration
  }

  void _startRotation() {
    _rotationTimer?.cancel();
    _rotationTimer = Timer.periodic(Duration(minutes: _settings.rotationMinutes), (_) {
      _updateCurrentAffirmation();
    });
  }

  Future<void> updateSettings(AffirmationSettings settings) async {
    final updatedSettings = settings.copyWith(
      isSynced: 0,
      updatedAt: DateTime.now(),
    );
    _settings = updatedSettings;
    notifyListeners();
    if (_localRepo != null) {
      await _localRepo!.saveSettings(updatedSettings);
      try {
        await _cloudRepo.saveSettings(updatedSettings);
        await _localRepo!.markSettingsSynced();
        _settings = updatedSettings.copyWith(isSynced: 1);
        notifyListeners();
      } catch (e) {
        debugPrint("Sync Settings Error: $e");
      }
      _startRotation();
    }
  }

  Future<void> updateOrder(List<Affirmation> orderedList) async {
    // Only custom affirmations are persisted in DB order, defaults are static in this implementation
    // But we can treat the whole list as reorderable in UI
    final customOnly = orderedList.where((a) => a.isCustom).toList();
    _customAffirmations = customOnly;
    notifyListeners();
    if (_localRepo != null) {
      await _localRepo!.updateAffirmationOrder(customOnly);
      // Syncing order to cloud usually involves updating each record's display_order
      for (var aff in customOnly) {
        _cloudRepo.insertAffirmation(aff);
      }
    }
  }

  Future<void> addAffirmation(String text, [String? speaker]) async {
    if (_localRepo == null) return;
    final affirmation = Affirmation(
      text: text,
      speaker: speaker,
      isCustom: true,
      isSynced: 0,
      updatedAt: DateTime.now(),
      displayOrder: _customAffirmations.length,
    );
    _customAffirmations.add(affirmation);
    notifyListeners();
    try {
      await _localRepo!.insertAffirmation(affirmation);
      await _cloudRepo.insertAffirmation(affirmation);
      await _localRepo!.markAffirmationSynced(affirmation.id);
      _refreshList();
    } catch (e) { debugPrint("Add Error: $e"); }
  }

  Future<void> updateAffirmation(Affirmation affirmation) async {
    if (_localRepo == null) return;
    final index = _customAffirmations.indexWhere((a) => a.id == affirmation.id);
    if (index != -1) {
      final updated = affirmation.copyWith(
        isSynced: 0,
        updatedAt: DateTime.now(),
      );
      _customAffirmations[index] = updated;
      notifyListeners();
      try {
        await _localRepo!.insertAffirmation(updated);
        await _cloudRepo.insertAffirmation(updated);
        await _localRepo!.markAffirmationSynced(affirmation.id);
        _refreshList();
      } catch (e) { debugPrint("Update Error: $e"); }
    }
  }

  Future<void> deleteAffirmation(String id) async {
    if (_localRepo == null) return;
    _customAffirmations.removeWhere((a) => a.id == id);
    notifyListeners();
    try {
      await _localRepo!.deleteAffirmation(id);
      await _localRepo!.addToDeletionQueue(id, 'affirmations');
      await _cloudRepo.deleteAffirmation(id);
      await _localRepo!.removeFromDeletionQueue(id);
    } catch (e) { debugPrint("Delete Error: $e"); }
  }

  Future<void> _syncLocalToCloud() async {
    if (_localRepo == null) return;
    
    final syncProv = SyncProvider();
    syncProv.startFeatureSync();

    try {
      final count = await _localRepo!.getUnsyncedCount();
      syncProv.addTotalItems(count);

      // 1. Push Deletions
      final deletions = await _localRepo!.getPendingDeletions();
      for (var del in deletions) {
        final id = del['id'] as String;
        final table = del['table_name'] as String;
        try {
          if (table == 'affirmations') await _cloudRepo.deleteAffirmation(id);
          await _localRepo!.removeFromDeletionQueue(id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      // 2. Push Changes
      final unsynced = await _localRepo!.getUnsyncedAffirmations();
      for (var aff in unsynced) {
        try {
          await _cloudRepo.insertAffirmation(aff);
          await _localRepo!.markAffirmationSynced(aff.id);
          syncProv.incrementCompleted();
        } catch (_) {}
      }

      final unsyncedSettings = await _localRepo!.getUnsyncedSettings();
      if (unsyncedSettings != null) {
        try {
          await _cloudRepo.saveSettings(unsyncedSettings);
          await _localRepo!.markSettingsSynced();
          syncProv.incrementCompleted();
        } catch (_) {}
      }
    } finally {
      syncProv.endFeatureSync();
    }
  }

  Future<void> forceRefresh() async {
    await _syncLocalToCloud();
    await _loadData();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    super.dispose();
  }
}
