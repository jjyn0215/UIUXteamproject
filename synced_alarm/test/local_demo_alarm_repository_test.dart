import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synced_alarm/src/data/local_demo_alarm_repository.dart';
import 'package:synced_alarm/src/models/alarm.dart';

void main() {
  test('starts empty instead of scheduling demo alarms', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = LocalDemoAlarmRepository();

    final alarms = await repository
        .watchAlarms(groupId: 'demo', accessCode: '')
        .first;

    expect(alarms, isEmpty);
  });

  test('persists local alarms across repository instances', () async {
    SharedPreferences.setMockInitialValues({});
    final firstRepository = LocalDemoAlarmRepository();
    final alarm = Alarm.create(
      groupId: 'demo',
      label: 'Persistent alarm',
      time: const TimeOfDay(hour: 7, minute: 20),
      updatedBy: 'test-device',
    );

    await firstRepository.upsertAlarm(alarm, accessCode: '');

    final secondRepository = LocalDemoAlarmRepository();
    final alarms = await secondRepository
        .watchAlarms(groupId: 'demo', accessCode: '')
        .first;

    expect(alarms.map((item) => item.id), contains(alarm.id));
    expect(
      alarms.firstWhere((item) => item.id == alarm.id).label,
      'Persistent alarm',
    );
  });

  test(
    'drops legacy generated demo alarms from persisted local data',
    () async {
      final legacyAlarm = Alarm.create(
        groupId: 'demo',
        label: 'Morning focus',
        time: const TimeOfDay(hour: 7, minute: 30),
        updatedBy: 'local-demo',
      );
      final userAlarm = Alarm.create(
        groupId: 'demo',
        label: 'User alarm',
        time: const TimeOfDay(hour: 8, minute: 10),
        updatedBy: 'test-device',
      );
      SharedPreferences.setMockInitialValues({
        'synced_alarm_local_alarms_v1': jsonEncode([
          {'id': legacyAlarm.id, ...legacyAlarm.toJson()},
          {'id': userAlarm.id, ...userAlarm.toJson()},
        ]),
      });
      final repository = LocalDemoAlarmRepository();

      final alarms = await repository
          .watchAlarms(groupId: 'demo', accessCode: '')
          .first;

      expect(alarms.map((alarm) => alarm.id), contains(userAlarm.id));
      expect(alarms.map((alarm) => alarm.id), isNot(contains(legacyAlarm.id)));
    },
  );
}
