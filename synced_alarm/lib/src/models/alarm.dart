import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const defaultAlarmRepeatWeekdays = <int>{
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
  DateTime.sunday,
};
const defaultAlarmRingDurationMinutes = 5;
const defaultAlarmSnoozeMinutes = 5;
const defaultAlarmMaxSnoozeCount = 3;

enum AlarmCommandType { ring, dismiss, snooze }

class Alarm {
  const Alarm({
    required this.id,
    required this.groupId,
    required this.label,
    required this.timeOfDayMinutes,
    required this.enabled,
    required this.createdAt,
    required this.updatedAt,
    this.repeatWeekdays = defaultAlarmRepeatWeekdays,
    this.ringDurationMinutes = defaultAlarmRingDurationMinutes,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.snoozeMinutes = defaultAlarmSnoozeMinutes,
    this.maxSnoozeCount = defaultAlarmMaxSnoozeCount,
    this.snoozeCount = 0,
    this.snoozeUntil,
    this.lastTriggeredDate,
    this.updatedBy,
    this.revision = 0,
  });

  factory Alarm.create({
    required String groupId,
    required String label,
    required TimeOfDay time,
    Set<int> repeatWeekdays = defaultAlarmRepeatWeekdays,
    int ringDurationMinutes = defaultAlarmRingDurationMinutes,
    bool soundEnabled = true,
    bool vibrationEnabled = true,
    int snoozeMinutes = defaultAlarmSnoozeMinutes,
    int maxSnoozeCount = defaultAlarmMaxSnoozeCount,
    String? updatedBy,
  }) {
    final now = DateTime.now();
    return Alarm(
      id: _uuid.v4(),
      groupId: groupId,
      label: label.trim().isEmpty ? 'Alarm' : label.trim(),
      timeOfDayMinutes: time.hour * 60 + time.minute,
      enabled: true,
      createdAt: now,
      updatedAt: now,
      repeatWeekdays: _normalizeRepeatWeekdays(repeatWeekdays),
      ringDurationMinutes: ringDurationMinutes,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      snoozeMinutes: snoozeMinutes,
      maxSnoozeCount: maxSnoozeCount,
      updatedBy: updatedBy,
    );
  }

  factory Alarm.fromJson(String id, Map<String, Object?> json) {
    return Alarm(
      id: id,
      groupId: json['groupId'] as String? ?? 'demo',
      label: json['label'] as String? ?? 'Alarm',
      timeOfDayMinutes: json['timeOfDayMinutes'] as int? ?? 420,
      enabled: json['enabled'] as bool? ?? true,
      repeatWeekdays: _repeatWeekdaysFromJson(json['repeatWeekdays']),
      ringDurationMinutes: _boundedInt(
        json['ringDurationMinutes'],
        defaultAlarmRingDurationMinutes,
        min: 1,
        max: 60,
      ),
      soundEnabled: json['soundEnabled'] as bool? ?? true,
      vibrationEnabled: json['vibrationEnabled'] as bool? ?? true,
      snoozeMinutes: _boundedInt(
        json['snoozeMinutes'],
        defaultAlarmSnoozeMinutes,
        min: 1,
        max: 120,
      ),
      maxSnoozeCount: _boundedInt(
        json['maxSnoozeCount'],
        defaultAlarmMaxSnoozeCount,
        min: 0,
        max: 10,
      ),
      snoozeCount: _boundedInt(json['snoozeCount'], 0, min: 0, max: 10),
      snoozeUntil: _dateFromJson(json['snoozeUntil']),
      lastTriggeredDate: _dateFromJson(json['lastTriggeredDate']),
      createdAt: _dateFromJson(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateFromJson(json['updatedAt']) ?? DateTime.now(),
      updatedBy: json['updatedBy'] as String?,
      revision: json['revision'] as int? ?? 0,
    );
  }

  final String id;
  final String groupId;
  final String label;
  final int timeOfDayMinutes;
  final bool enabled;
  final Set<int> repeatWeekdays;
  final int ringDurationMinutes;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int snoozeMinutes;
  final int maxSnoozeCount;
  final int snoozeCount;
  final DateTime? snoozeUntil;
  final DateTime? lastTriggeredDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? updatedBy;
  final int revision;

  TimeOfDay get timeOfDay {
    return TimeOfDay(
      hour: timeOfDayMinutes ~/ 60,
      minute: timeOfDayMinutes % 60,
    );
  }

  DateTime nextOccurrence([DateTime? from]) {
    final base = from ?? DateTime.now();
    final today = DateTime(
      base.year,
      base.month,
      base.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
    if (snoozeUntil != null && snoozeUntil!.isAfter(base)) {
      return snoozeUntil!;
    }
    for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
      final candidate = today.add(Duration(days: dayOffset));
      if (!candidate.isAfter(base)) continue;
      if (repeatWeekdays.contains(candidate.weekday)) return candidate;
    }
    return today.add(const Duration(days: 1));
  }

  String get timeLabel {
    final hour = timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod;
    final minute = timeOfDay.minute.toString().padLeft(2, '0');
    final period = timeOfDay.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Map<String, Object?> toJson() {
    return {
      'groupId': groupId,
      'label': label,
      'timeOfDayMinutes': timeOfDayMinutes,
      'enabled': enabled,
      'repeatWeekdays': repeatWeekdays.toList()..sort(),
      'ringDurationMinutes': ringDurationMinutes,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'snoozeMinutes': snoozeMinutes,
      'maxSnoozeCount': maxSnoozeCount,
      'snoozeCount': snoozeCount,
      'snoozeUntil': snoozeUntil?.toIso8601String(),
      'lastTriggeredDate': lastTriggeredDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'updatedBy': updatedBy,
      'revision': revision,
    };
  }

  Alarm copyWith({
    String? label,
    int? timeOfDayMinutes,
    bool? enabled,
    Set<int>? repeatWeekdays,
    int? ringDurationMinutes,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? snoozeMinutes,
    int? maxSnoozeCount,
    int? snoozeCount,
    DateTime? snoozeUntil,
    bool clearSnooze = false,
    DateTime? lastTriggeredDate,
    DateTime? updatedAt,
    String? updatedBy,
    int? revision,
  }) {
    return Alarm(
      id: id,
      groupId: groupId,
      label: label ?? this.label,
      timeOfDayMinutes: timeOfDayMinutes ?? this.timeOfDayMinutes,
      enabled: enabled ?? this.enabled,
      repeatWeekdays: _normalizeRepeatWeekdays(
        repeatWeekdays ?? this.repeatWeekdays,
      ),
      ringDurationMinutes: ringDurationMinutes ?? this.ringDurationMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      maxSnoozeCount: maxSnoozeCount ?? this.maxSnoozeCount,
      snoozeCount: clearSnooze ? 0 : snoozeCount ?? this.snoozeCount,
      snoozeUntil: clearSnooze ? null : snoozeUntil ?? this.snoozeUntil,
      lastTriggeredDate: lastTriggeredDate ?? this.lastTriggeredDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      updatedBy: updatedBy ?? this.updatedBy,
      revision: revision ?? this.revision + 1,
    );
  }
}

Set<int> _repeatWeekdaysFromJson(Object? value) {
  if (value is Iterable) {
    return _normalizeRepeatWeekdays(value.whereType<int>().toSet());
  }
  return defaultAlarmRepeatWeekdays;
}

Set<int> _normalizeRepeatWeekdays(Set<int> value) {
  final normalized = value
      .where((weekday) => weekday >= DateTime.monday)
      .where((weekday) => weekday <= DateTime.sunday)
      .toSet();
  if (normalized.isEmpty) return defaultAlarmRepeatWeekdays;
  return Set.unmodifiable(normalized);
}

int _boundedInt(
  Object? value,
  int fallback, {
  required int min,
  required int max,
}) {
  final parsed = value is int ? value : fallback;
  if (parsed < min) return min;
  if (parsed > max) return max;
  return parsed;
}

class AlarmCommand {
  const AlarmCommand({
    required this.id,
    required this.groupId,
    required this.alarmId,
    required this.commandType,
    required this.sourceDeviceId,
    required this.createdAt,
    required this.expiresAt,
  });

  factory AlarmCommand.create({
    required String groupId,
    required String alarmId,
    required AlarmCommandType commandType,
    required String sourceDeviceId,
  }) {
    final now = DateTime.now();
    return AlarmCommand(
      id: _uuid.v4(),
      groupId: groupId,
      alarmId: alarmId,
      commandType: commandType,
      sourceDeviceId: sourceDeviceId,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
    );
  }

  final String id;
  final String groupId;
  final String alarmId;
  final AlarmCommandType commandType;
  final String sourceDeviceId;
  final DateTime createdAt;
  final DateTime expiresAt;

  Map<String, Object?> toJson() {
    return {
      'groupId': groupId,
      'alarmId': alarmId,
      'commandType': commandType.name,
      'sourceDeviceId': sourceDeviceId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

DateTime? _dateFromJson(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  final dynamic maybeTimestamp = value;
  try {
    return maybeTimestamp.toDate() as DateTime;
  } on Object {
    return null;
  }
}
