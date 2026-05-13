import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

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
    this.snoozeUntil,
    this.lastTriggeredDate,
    this.updatedBy,
    this.revision = 0,
  });

  factory Alarm.create({
    required String groupId,
    required String label,
    required TimeOfDay time,
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
    final scheduled = today.isAfter(base)
        ? today
        : today.add(const Duration(days: 1));
    if (snoozeUntil != null && snoozeUntil!.isAfter(base)) {
      return snoozeUntil!;
    }
    return scheduled;
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
      snoozeUntil: clearSnooze ? null : snoozeUntil ?? this.snoozeUntil,
      lastTriggeredDate: lastTriggeredDate ?? this.lastTriggeredDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      updatedBy: updatedBy ?? this.updatedBy,
      revision: revision ?? this.revision + 1,
    );
  }
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
