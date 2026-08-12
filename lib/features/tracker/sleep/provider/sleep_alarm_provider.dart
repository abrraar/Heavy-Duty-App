// lib/features/tracker/sleep/provider/sleep_alarm_provider.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:uuid/uuid.dart';
import '../model/sleep_alarm.dart';
import '../../../../core/utils/id_utils.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:permission_handler/permission_handler.dart';
import '../data/sleep_alarm_repository.dart';

class SleepAlarmProvider with ChangeNotifier {
  List<SleepAlarm> _alarms = [];
  bool _isInitialized = false;
  SleepAlarmRepository? _repo;
  SleepAlarmSettings _settings = SleepAlarmSettings();

  List<SleepAlarm> get alarms => _alarms;
  SleepAlarmSettings get settings => _settings;
  
  static const int bedtimeId = 888;
  static const int wakeUpId = 999;

  bool get isBedtimeAlarmEnabled => _settings.bedtimeEnabled;
  bool get isWakeUpAlarmEnabled => _settings.wakeUpEnabled;

  void initializeForUser(String userId) {
    _repo = SleepAlarmRepository(userId: userId);
    init();
  }

  Future<void> init() async {
    if (!_isInitialized) {
      await Alarm.init();
      _isInitialized = true;
    }

    if (_repo != null) {
      _settings = await _repo!.getSettings();
    }
    await _loadAlarms();
    notifyListeners();
  }

  Future<bool> checkAndRequestPermissions(BuildContext context) async {
    // Check Notification Permission (Android 13+)
    if (Platform.isAndroid || Platform.isIOS) {
      final notificationStatus = await Permission.notification.status;
      if (notificationStatus.isDenied) {
        await Permission.notification.request();
      }
    }

    // Check Exact Alarm Permission (Android 12+)
    if (Platform.isAndroid) {
      final status = await Permission.scheduleExactAlarm.status;
      if (status.isDenied) {
        if (context.mounted) {
          final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: const Color(0xFF1A1A1A),
              title: const Text("Alarm Permissions", style: TextStyle(color: Colors.white)),
              content: const Text(
                "To wake you up reliably, Heavy Duty needs permission to set exact alarms. Please enable this in the next screen.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("CANCEL", style: TextStyle(color: Colors.white54)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("OPEN SETTINGS", style: TextStyle(color: Color(0xFFD32F2F))),
                ),
              ],
            ),
          );

          if (proceed == true) {
            const intent = AndroidIntent(
              action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
            );
            await intent.launch();
          }
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _loadAlarms() async {
    final List<AlarmSettings> scheduledAlarms = await Alarm.getAlarms();
    _alarms = scheduledAlarms.map((a) {
      return SleepAlarm(
        id: a.id,
        label: a.notificationSettings.body,
        time: a.dateTime,
        audioPath: a.assetAudioPath ?? 'assets/audio/alarm.mp3',
        isEnabled: true,
        type: (a.id == bedtimeId) 
            ? AlarmType.bedtime
            : (a.notificationSettings.title.contains("NAP") ? AlarmType.nap : AlarmType.wakeUp),
      );
    }).toList();
    notifyListeners();
  }

  Future<void> updateSettings({
    bool? bedtimeEnabled,
    int? bedtimeHour,
    int? bedtimeMinute,
    String? bedtimeAudioPath,
    bool? wakeUpEnabled,
    int? wakeUpHour,
    int? wakeUpMinute,
    String? wakeUpAudioPath,
  }) async {
    _settings = SleepAlarmSettings(
      bedtimeEnabled: bedtimeEnabled ?? _settings.bedtimeEnabled,
      bedtimeHour: bedtimeHour ?? _settings.bedtimeHour,
      bedtimeMinute: bedtimeMinute ?? _settings.bedtimeMinute,
      bedtimeAudioPath: bedtimeAudioPath ?? _settings.bedtimeAudioPath,
      wakeUpEnabled: wakeUpEnabled ?? _settings.wakeUpEnabled,
      wakeUpHour: wakeUpHour ?? _settings.wakeUpHour,
      wakeUpMinute: wakeUpMinute ?? _settings.wakeUpMinute,
      wakeUpAudioPath: wakeUpAudioPath ?? _settings.wakeUpAudioPath,
    );

    if (_repo != null) {
      await _repo!.saveSettings(_settings);
    }

    // Refresh Alarms based on new settings
    if (_settings.bedtimeEnabled) {
      await _scheduleBedtime();
    } else {
      await Alarm.stop(bedtimeId);
    }

    if (_settings.wakeUpEnabled) {
      await _scheduleWakeUp();
    } else {
      await Alarm.stop(wakeUpId);
    }

    await _loadAlarms();
  }

  Future<void> _scheduleBedtime() async {
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, _settings.bedtimeHour, _settings.bedtimeMinute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));

    await setIndividualAlarm(
      id: bedtimeId,
      time: target,
      audioPath: _settings.bedtimeAudioPath ?? 'assets/audio/alarm.mp3',
      title: 'Sleep Time',
      body: 'Time to head to bed for optimal recovery.',
      volume: 0.6,
    );
  }

  Future<void> _scheduleWakeUp() async {
    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, _settings.wakeUpHour, _settings.wakeUpMinute);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));

    await setIndividualAlarm(
      id: wakeUpId,
      time: target,
      audioPath: _settings.wakeUpAudioPath ?? 'assets/audio/alarm.mp3',
      title: 'Wake Up',
      body: 'Rise and grind. Recovery complete.',
      volume: 0.8,
    );
  }

  Future<void> setIndividualAlarm({
    required int id,
    required DateTime time,
    required String audioPath,
    required String title,
    required String body,
    double volume = 0.7,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fixed(
        volume: volume,
        volumeEnforced: true,
      ),
      notificationSettings: NotificationSettings(
        title: title,
        body: body,
        stopButton: 'Stop',
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
    );

    await Alarm.set(alarmSettings: alarmSettings);
    await _loadAlarms();
  }

  Future<void> stopAlarm(int id) async {
    await Alarm.stop(id);
    // Also update settings to reflect disabled state if it was a system alarm
    if (id == bedtimeId) {
       await updateSettings(bedtimeEnabled: false);
    } else if (id == wakeUpId) {
       await updateSettings(wakeUpEnabled: false);
    }
    await _loadAlarms();
  }

  Future<void> setNapAlarm(Duration duration, {String audioPath = 'assets/audio/alarm.mp3'}) async {
    final int id = IdUtils.stringToIntId("NAP_${const Uuid().v4()}");
    final DateTime time = DateTime.now().add(duration);

    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: audioPath,
      loopAudio: true,
      vibrate: true,
      volumeSettings: const VolumeSettings.fixed(
        volume: 0.7,
        volumeEnforced: true,
      ),
      notificationSettings: const NotificationSettings(
        title: 'NAP OVER',
        body: 'Recovery Burst Complete.',
        stopButton: 'Stop',
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
    );

    await Alarm.set(alarmSettings: alarmSettings);
    await _loadAlarms();
  }

  Future<void> stopAll() async {
    final List<AlarmSettings> all = await Alarm.getAlarms();
    for (var a in all) {
      await Alarm.stop(a.id);
    }
    await updateSettings(bedtimeEnabled: false, wakeUpEnabled: false);
    await _loadAlarms();
  }
}
