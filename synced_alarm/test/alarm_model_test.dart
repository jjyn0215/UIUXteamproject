import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synced_alarm/src/models/alarm.dart';

void main() {
  test('uses detailed alarm defaults for existing Firestore data', () {
    final alarm = Alarm.fromJson('alarm-1', {
      'groupId': 'demo',
      'label': 'Legacy alarm',
      'timeOfDayMinutes': 8 * 60,
      'enabled': true,
      'createdAt': '2026-05-19T00:00:00.000Z',
      'updatedAt': '2026-05-19T00:00:00.000Z',
      'revision': 1,
    });

    expect(alarm.repeatWeekdays, defaultAlarmRepeatWeekdays);
    expect(alarm.ringDurationMinutes, 5);
    expect(alarm.soundEnabled, isTrue);
    expect(alarm.vibrationEnabled, isTrue);
    expect(alarm.snoozeMinutes, 5);
    expect(alarm.maxSnoozeCount, 3);
    expect(alarm.snoozeCount, 0);
  });

  test('finds the next occurrence using selected weekdays', () {
    final alarm = Alarm.create(
      groupId: 'demo',
      label: 'Class',
      time: const TimeOfDay(hour: 8, minute: 0),
    ).copyWith(repeatWeekdays: {DateTime.tuesday, DateTime.thursday});

    expect(
      alarm.nextOccurrence(DateTime(2026, 5, 18, 9)),
      DateTime(2026, 5, 19, 8),
    );
    expect(
      alarm.nextOccurrence(DateTime(2026, 5, 19, 9)),
      DateTime(2026, 5, 21, 8),
    );
  });

  test('serializes detailed alarm settings', () {
    final alarm =
        Alarm.create(
          groupId: 'demo',
          label: 'Detailed',
          time: const TimeOfDay(hour: 7, minute: 30),
        ).copyWith(
          repeatWeekdays: {DateTime.monday, DateTime.friday},
          ringDurationMinutes: 10,
          soundEnabled: false,
          vibrationEnabled: true,
          snoozeMinutes: 15,
          maxSnoozeCount: 2,
          snoozeCount: 1,
        );

    final json = alarm.toJson();

    expect(json['repeatWeekdays'], [DateTime.monday, DateTime.friday]);
    expect(json['ringDurationMinutes'], 10);
    expect(json['soundEnabled'], isFalse);
    expect(json['vibrationEnabled'], isTrue);
    expect(json['snoozeMinutes'], 15);
    expect(json['maxSnoozeCount'], 2);
    expect(json['snoozeCount'], 1);
  });
}
