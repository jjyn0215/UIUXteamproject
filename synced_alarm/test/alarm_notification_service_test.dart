import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:synced_alarm/src/models/alarm.dart';
import 'package:synced_alarm/src/platform/alarm_notification_service.dart';

void main() {
  test('uses a dedicated ringing channel with repeated sound flag', () {
    expect(
      alarmNotificationChannelId,
      'synced_alarm_ringing_v4_sound_native_vibration',
    );
    expect(alarmSyncNotificationChannelId, 'synced_alarm_sync_v1');
    expect(alarmNotificationSoundRepeatFlag, 4);
  });

  test('rings with native vibration only to avoid overlapping motors', () {
    final source = File(
      'lib/src/platform/alarm_notification_service.dart',
    ).readAsStringSync();

    expect(
      alarmNotificationChannelIdFor(
        Alarm(
          id: 'alarm-1',
          groupId: 'demo',
          label: 'Morning',
          timeOfDayMinutes: 8 * 60,
          enabled: true,
          vibrationEnabled: true,
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      ),
      'synced_alarm_ringing_v4_sound_native_vibration',
    );
    expect(source, contains('enableVibration: false'));
    expect(source, isNot(contains('enableVibration: alarm.vibrationEnabled')));
    expect(source, isNot(contains("final vibration = alarm.vibrationEnabled")));
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

  test('Android manifest registers the foreground alarm receiver', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:name=".ForegroundAlarmReceiver"'));
  });

  test('native alarm vibration loops and can be cancelled', () {
    final file = File(
      'android/app/src/main/kotlin/com/teamproject/synced_alarm/'
      'AlarmVibrationController.kt',
    );

    expect(file.existsSync(), isTrue);
    final source = file.readAsStringSync();
    expect(source, contains('VibrationEffect.createWaveform'));
    expect(source, contains('.vibrate'));
    expect(source, contains('.cancel()'));
    expect(source, contains('postDelayed'));
  });

  test('alarm task channel exposes vibration controls', () {
    final nativeSource = File(
      'android/app/src/main/kotlin/com/teamproject/synced_alarm/'
      'SyncedAlarmFlutterActivity.kt',
    ).readAsStringSync();
    final dartSource = File(
      'lib/src/platform/alarm_task_controller.dart',
    ).readAsStringSync();

    expect(nativeSource, contains('"startAlarmVibration"'));
    expect(nativeSource, contains('"stopAlarmVibration"'));
    expect(nativeSource, contains('AlarmVibrationController.start'));
    expect(nativeSource, contains('AlarmVibrationController.stop'));
    expect(dartSource, contains('startAlarmVibration'));
    expect(dartSource, contains('stopAlarmVibration'));
    expect(dartSource, contains('ringDurationMillis'));
    expect(dartSource, contains('vibrationEnabled'));
  });

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

  test('alarm ringing screen starts and stops native vibration', () {
    final source = File(
      'lib/src/features/alarms/alarm_ring_screen.dart',
    ).readAsStringSync();

    expect(source, contains('AlarmTaskController.startAlarmVibration'));
    expect(source, contains('AlarmTaskController.stopAlarmVibration'));
    expect(source, contains('vibrationEnabled: widget.alarm.vibrationEnabled'));
    expect(source, contains('duration: Duration(minutes:'));
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
