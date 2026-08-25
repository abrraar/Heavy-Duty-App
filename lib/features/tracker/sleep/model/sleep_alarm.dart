// lib/features/tracker/sleep/model/sleep_alarm.dart

enum AlarmType { wakeUp, nap, bedtime }

class SleepAlarm {
  final int id; // ID for alarm package (must be int)
  final String label;
  final DateTime time; // This is the wake-up time (when alarm rings)
  final DateTime? bedtime;
  final String audioPath;
  final bool isEnabled;
  final AlarmType type;
  final List<int> days; // 1-7 for recurring, empty for one-time

  SleepAlarm({
    required this.id,
    required this.label,
    required this.time,
    this.bedtime,
    this.audioPath = 'assets/audio/alarm.mp3',
    this.isEnabled = true,
    this.type = AlarmType.wakeUp,
    this.days = const [],
  });

  SleepAlarm copyWith({
    String? label,
    DateTime? time,
    DateTime? bedtime,
    String? audioPath,
    bool? isEnabled,
    AlarmType? type,
    List<int>? days,
  }) {
    return SleepAlarm(
      id: id,
      label: label ?? this.label,
      time: time ?? this.time,
      bedtime: bedtime ?? this.bedtime,
      audioPath: audioPath ?? this.audioPath,
      isEnabled: isEnabled ?? this.isEnabled,
      type: type ?? this.type,
      days: days ?? this.days,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'time': time.toIso8601String(),
      'bedtime': bedtime?.toIso8601String(),
      'audio_path': audioPath,
      'is_enabled': isEnabled ? 1 : 0,
      'type': type.name,
      'days': days.join(','),
    };
  }

  factory SleepAlarm.fromMap(Map<String, dynamic> map) {
    return SleepAlarm(
      id: map['id'] as int,
      label: map['label'] as String,
      time: DateTime.parse(map['time'] as String),
      bedtime: map['bedtime'] != null ? DateTime.parse(map['bedtime'] as String) : null,
      audioPath: map['audio_path'] as String? ?? 'assets/audio/alarm.mp3',
      isEnabled: (map['is_enabled'] as int) == 1,
      type: AlarmType.values.firstWhere((e) => e.name == map['type']),
      days: (map['days'] as String).isEmpty 
          ? [] 
          : (map['days'] as String).split(',').map((e) => int.parse(e)).toList(),
    );
  }
}
