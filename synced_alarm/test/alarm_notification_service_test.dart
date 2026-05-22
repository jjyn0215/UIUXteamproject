import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:synced_alarm/src/models/alarm.dart';
import 'package:synced_alarm/src/platform/alarm_notification_service.dart';

void main() {
  test('uses a dedicated ringing channel with repeated sound flag', () {
    expect(
      alarmNotificationChannelId,
      'synced_alarm_ringing_v3_sound_vibration',
    );
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

  test('does not cancel local schedules for alarm command sync data', () {
    expect(
      shouldCancelLocalScheduleForSilentSync({
        'type': 'alarm.command',
        'commandType': 'dismiss',
      }),
      isFalse,
    );
    expect(
      shouldCancelLocalScheduleForSilentSync({
        'type': 'alarm.command',
        'commandType': 'snooze',
      }),
      isFalse,
    );
    expect(
      shouldCancelLocalScheduleForSilentSync({'type': 'alarm.deleted'}),
      isTrue,
    );
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
    expect(launch?.source, AlarmNotificationLaunchSource.notification);
    expect(
      AlarmNotificationLaunch.fromPayload('alarm.command:alarm-1'),
      isNull,
    );
    expect(AlarmNotificationLaunch.fromPayload(null), isNull);
  });

  test('snooze status payload supports actions without opening alarm UI', () {
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
    final payload = AlarmNotificationPayload.fromSnoozeStatus(alarm).payload;

    expect(AlarmNotificationLaunch.fromPayload(payload), isNull);

    final dismiss = AlarmNotificationActionRequest.fromResponse(
      NotificationResponse(
        notificationResponseType:
            NotificationResponseType.selectedNotificationAction,
        actionId: alarmNotificationDismissActionId,
        payload: payload,
      ),
    );

    expect(dismiss?.alarmId, 'alarm-1');
    expect(dismiss?.type, AlarmNotificationActionType.dismiss);
    expect(dismiss?.payloadData.groupId, 'demo');
  });

  test('marks native foreground alarm launches separately from taps', () {
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

    final launch = AlarmNotificationLaunch.fromPayload(
      payload,
      source: AlarmNotificationLaunchSource.nativeForeground,
    );

    expect(launch?.alarmId, 'alarm-1');
    expect(launch?.source, AlarmNotificationLaunchSource.nativeForeground);
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

  test('background dismiss writes only mutable alarm state fields', () {
    final now = DateTime.utc(2026, 5, 23, 7, 30);

    final patch = alarmDismissPatch(now: now, updatedBy: 'device-1');

    expect(
      patch.keys,
      unorderedEquals([
        'snoozeUntil',
        'snoozeCount',
        'lastTriggeredDate',
        'updatedAt',
        'updatedBy',
      ]),
    );
    expect(patch['snoozeUntil'], isNull);
    expect(patch['snoozeCount'], 0);
    expect(patch['lastTriggeredDate'], now.toIso8601String());
    expect(patch['updatedAt'], now.toIso8601String());
    expect(patch['updatedBy'], 'device-1');
    expect(patch, isNot(contains('enabled')));
    expect(patch, isNot(contains('label')));
    expect(patch, isNot(contains('timeOfDayMinutes')));
    expect(patch, isNot(contains('createdAt')));
  });

  test('background snooze writes only mutable alarm state fields', () {
    final now = DateTime.utc(2026, 5, 23, 7, 30);

    final patch = alarmSnoozePatch(
      now: now,
      updatedBy: 'device-1',
      snoozeMinutes: 10,
      snoozeCount: 2,
    );

    expect(
      patch.keys,
      unorderedEquals([
        'snoozeUntil',
        'snoozeCount',
        'lastTriggeredDate',
        'updatedAt',
        'updatedBy',
      ]),
    );
    expect(
      patch['snoozeUntil'],
      now.add(const Duration(minutes: 10)).toIso8601String(),
    );
    expect(patch['snoozeCount'], 2);
    expect(patch['lastTriggeredDate'], now.toIso8601String());
    expect(patch['updatedAt'], now.toIso8601String());
    expect(patch['updatedBy'], 'device-1');
    expect(patch, isNot(contains('enabled')));
    expect(patch, isNot(contains('label')));
    expect(patch, isNot(contains('timeOfDayMinutes')));
    expect(patch, isNot(contains('createdAt')));
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

  test('Android manifest registers the foreground alarm receiver', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".ForegroundAlarmReceiver"'));
  });

  test(
    'foreground alarm routing uses visible lifecycle instead of pause state',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/teamproject/synced_alarm/'
        'SyncedAlarmFlutterActivity.kt',
      ).readAsStringSync();

      expect(source, contains('override fun onStart()'));
      expect(source, contains('override fun onStop()'));
      expect(source, contains('private var isMainActivityVisible'));
      expect(source, contains('return isMainActivityVisible'));
      expect(source, isNot(contains('private var isMainActivityResumed')));
    },
  );

  test(
    'Android manifest routes full-screen alarms to a dedicated activity',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:name=".LaunchRouterActivity"'));
      expect(manifest, contains('android:name=".AlarmActivity"'));
      expect(manifest, contains('android:name=".MainActivity"'));
      expect(
        manifest,
        contains('android:taskAffinity="com.teamproject.synced_alarm.alarm"'),
      );
      expect(manifest, contains('android:showWhenLocked="true"'));
      expect(manifest, contains('android:turnScreenOn="true"'));
    },
  );

  test(
    'LaunchRouterActivity only routes ringing alarm payloads to AlarmActivity',
    () {
      final source = File(
        'android/app/src/main/kotlin/com/teamproject/synced_alarm/'
        'LaunchRouterActivity.kt',
      ).readAsStringSync();

      expect(source, contains('JSONObject(payload)'));
      expect(source, contains('optString("type") == "alarm"'));
      expect(source, contains('optString("purpose", "alarm") == "alarm"'));
      expect(source, isNot(contains('return hasExtra("payload")')));
    },
  );

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

  test('builds weekly scheduled notifications for selected weekdays', () {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Class',
      timeOfDayMinutes: 8 * 60,
      enabled: true,
      repeatWeekdays: {DateTime.monday, DateTime.wednesday},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    final requests = AlarmNotificationRequest.scheduledRequestsFromAlarm(
      alarm,
      from: DateTime(2026, 5, 17, 9),
    );

    expect(requests, hasLength(2));
    expect(
      requests.map((request) => request.matchDateTimeComponents),
      everyElement(DateTimeComponents.dayOfWeekAndTime),
    );
    expect(
      requests.map((request) => request.scheduledAt),
      containsAll([DateTime(2026, 5, 18, 8), DateTime(2026, 5, 20, 8)]),
    );
    expect(requests.map((request) => request.id).toSet(), hasLength(2));
  });

  test('builds foreground alarm trigger arguments from scheduled requests', () {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Class',
      timeOfDayMinutes: 8 * 60,
      enabled: true,
      repeatWeekdays: {DateTime.monday},
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final requests = AlarmNotificationRequest.scheduledRequestsFromAlarm(
      alarm,
      from: DateTime(2026, 5, 17, 9),
    );

    final args = foregroundAlarmTriggerArgumentsFromRequests(requests);

    expect(args, hasLength(1));
    expect(args.single['id'], alarmNotificationWeekdayId('alarm-1', 1));
    expect(
      args.single['triggerAtMillis'],
      DateTime(2026, 5, 18, 8).millisecondsSinceEpoch,
    );
    expect(
      AlarmNotificationPayloadData.fromPayload(
        args.single['payload'] as String?,
      )?.alarmId,
      'alarm-1',
    );
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
