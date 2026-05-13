import 'dart:async';

import 'package:flutter/material.dart';

import '../models/alarm.dart';
import 'alarm_repository.dart';

class LocalDemoAlarmRepository implements AlarmRepository {
  LocalDemoAlarmRepository() {
    final now = TimeOfDay.now();
    _alarms = [
      Alarm.create(
        groupId: 'demo',
        label: 'Morning focus',
        time: TimeOfDay(hour: (now.hour + 1) % 24, minute: 30),
        updatedBy: 'local-demo',
      ),
      Alarm.create(
        groupId: 'demo',
        label: 'Class reminder',
        time: const TimeOfDay(hour: 14, minute: 0),
        updatedBy: 'local-demo',
      ).copyWith(enabled: false),
    ];
  }

  final _controller = StreamController<List<Alarm>>.broadcast();
  late List<Alarm> _alarms;

  @override
  Future<void> joinGroup({
    required String groupId,
    required String accessCode,
  }) async {
    if (groupId.trim().isEmpty || accessCode.trim().isEmpty) {
      throw ArgumentError('groupId and accessCode are required.');
    }
  }

  @override
  Stream<List<Alarm>> watchAlarms({
    required String groupId,
    required String accessCode,
  }) async* {
    yield _visibleAlarms(groupId);
    yield* _controller.stream.map((alarms) {
      return alarms.where((alarm) => alarm.groupId == groupId).toList();
    });
  }

  @override
  Future<void> upsertAlarm(Alarm alarm, {required String accessCode}) async {
    final index = _alarms.indexWhere((item) => item.id == alarm.id);
    final updated = alarm.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      _alarms = [..._alarms, updated];
    } else {
      _alarms = [..._alarms]..[index] = updated;
    }
    _emit();
  }

  @override
  Future<void> deleteAlarm({
    required String groupId,
    required String alarmId,
    required String accessCode,
  }) async {
    _alarms = _alarms.where((alarm) => alarm.id != alarmId).toList();
    _emit();
  }

  @override
  Future<void> setAlarmEnabled({
    required String groupId,
    required String alarmId,
    required bool enabled,
    required String accessCode,
  }) async {
    _alarms = [
      for (final alarm in _alarms)
        if (alarm.id == alarmId) alarm.copyWith(enabled: enabled) else alarm,
    ];
    _emit();
  }

  @override
  Future<void> sendCommand(
    AlarmCommand command, {
    required String accessCode,
  }) async {
    _alarms = [
      for (final alarm in _alarms)
        if (alarm.id == command.alarmId)
          switch (command.commandType) {
            AlarmCommandType.dismiss => alarm.copyWith(
              clearSnooze: true,
              lastTriggeredDate: DateTime.now(),
            ),
            AlarmCommandType.snooze => alarm.copyWith(
              snoozeUntil: DateTime.now().add(const Duration(minutes: 5)),
            ),
            AlarmCommandType.ring => alarm.copyWith(
              lastTriggeredDate: DateTime.now(),
            ),
          }
        else
          alarm,
    ];
    _emit();
  }

  List<Alarm> _visibleAlarms(String groupId) {
    final alarms = _alarms.where((alarm) => alarm.groupId == groupId).toList();
    alarms.sort((a, b) => a.timeOfDayMinutes.compareTo(b.timeOfDayMinutes));
    return alarms;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_alarms));
    }
  }
}
