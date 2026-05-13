import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:synced_alarm/src/models/alarm.dart';
import 'package:synced_alarm/src/platform/alarm_notification_service.dart';

void main() {
  test('uses a dedicated ringing channel with repeated sound flag', () {
    expect(alarmNotificationChannelId, 'synced_alarm_ringing_v2');
    expect(alarmSyncNotificationChannelId, 'synced_alarm_sync_v1');
    expect(alarmNotificationSoundRepeatFlag, 4);
  });

  test('suppresses user-visible notifications for Firebase sync data', () {
    for (final type in [
      'alarm.created',
      'alarm.updated',
      'alarm.deleted',
      'alarm.command',
    ]) {
      expect(shouldShowRemoteDataNotification({'type': type}), isFalse);
    }

    expect(shouldShowRemoteDataNotification({'type': 'system.notice'}), isTrue);
  });

  test('builds notification payload from alarm data', () {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final payload = AlarmNotificationPayload.fromAlarm(alarm);

    expect(payload.id, alarmNotificationId(alarm.id));
    expect(payload.title, 'Synced Alarm');
    expect(payload.body, '8:30 AM · Morning standup');
    final payloadData = AlarmNotificationPayloadData.fromPayload(
      payload.payload,
    );
    expect(payloadData?.alarmId, 'alarm-1');
    expect(payloadData?.groupId, 'demo');
    expect(payloadData?.label, 'Morning standup');
    expect(payloadData?.timeOfDayMinutes, 8 * 60 + 30);
  });

  test('parses alarm notification payloads for in-app launch', () {
    final launch = AlarmNotificationLaunch.fromPayload('alarm:alarm-1');

    expect(launch, isNotNull);
    expect(launch?.alarmId, 'alarm-1');
    expect(
      AlarmNotificationLaunch.fromPayload('alarm.command:alarm-1'),
      isNull,
    );
    expect(AlarmNotificationLaunch.fromPayload(null), isNull);
  });

  test('parses alarm notification action responses', () {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final payload = AlarmNotificationPayload.fromAlarm(alarm).payload;
    final dismiss = AlarmNotificationActionRequest.fromResponse(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: alarmNotificationDismissActionId,
        payload: payload,
      ),
    );
    final snooze = AlarmNotificationActionRequest.fromResponse(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: alarmNotificationSnoozeActionId,
        payload: payload,
      ),
    );

    expect(dismiss?.alarmId, 'alarm-1');
    expect(dismiss?.type, AlarmNotificationActionType.dismiss);
    expect(snooze?.alarmId, 'alarm-1');
    expect(snooze?.type, AlarmNotificationActionType.snooze);
    expect(snooze?.payloadData.timeOfDayMinutes, 8 * 60 + 30);
    expect(
      AlarmNotificationActionRequest.fromResponse(
        const NotificationResponse(
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
          actionId: 'unknown',
          payload: 'alarm:alarm-1',
        ),
      ),
      isNull,
    );
  });

  test('alarm notification actions do not open the app UI', () {
    expect(
      alarmNotificationActions.map((action) => action.id),
      containsAll([
        alarmNotificationDismissActionId,
        alarmNotificationSnoozeActionId,
      ]),
    );
    expect(
      alarmNotificationActions.every((action) => !action.showsUserInterface),
      isTrue,
    );
    expect(
      alarmNotificationActions.every((action) => action.cancelNotification),
      isTrue,
    );
  });

  test('Android manifest registers the notification action receiver', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains(
        'com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver',
      ),
    );
  });

  test('builds scheduled alarm notification from next occurrence', () {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final request = AlarmNotificationRequest.fromAlarm(
      alarm,
      from: DateTime(2026, 5, 7, 9),
    );

    expect(request.id, alarmNotificationId(alarm.id));
    expect(request.title, 'Synced Alarm');
    expect(request.body, '8:30 AM · Morning standup');
    expect(
      AlarmNotificationPayloadData.fromPayload(request.payload)?.alarmId,
      'alarm-1',
    );
    expect(request.scheduledAt, DateTime(2026, 5, 8, 8, 30));
    expect(request.matchDateTimeComponents, DateTimeComponents.time);
  });

  test('builds one-shot scheduled notification for snoozed alarm', () {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      snoozeUntil: DateTime(2026, 5, 7, 9, 5),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final request = AlarmNotificationRequest.fromAlarm(
      alarm,
      from: DateTime(2026, 5, 7, 9),
    );

    expect(request.scheduledAt, DateTime(2026, 5, 7, 9, 5));
    expect(request.matchDateTimeComponents, isNull);
  });

  test('builds notification payload from command data', () {
    final payload = AlarmNotificationPayload.fromData({
      'type': 'alarm.command',
      'alarmId': 'alarm-1',
      'commandType': 'snooze',
    });

    expect(payload.title, 'Alarm command');
    expect(payload.body, 'Command: snooze');
    expect(payload.payload, 'alarm.command:alarm-1');
  });
}
