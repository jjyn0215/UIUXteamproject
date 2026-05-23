import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';
import '../models/alarm.dart';

const alarmNotificationChannelId =
    'synced_alarm_ringing_v4_sound_native_vibration';
const alarmSyncNotificationChannelId = 'synced_alarm_sync_v1';
const alarmNotificationSoundRepeatFlag = 4;
const alarmNotificationDismissActionId = 'alarm_action_dismiss';
const alarmNotificationSnoozeActionId = 'alarm_action_snooze';
const _alarmNotificationChannelPrefix = 'synced_alarm_ringing_v4';
const _alarmPayloadPurposeAlarm = 'alarm';
const _alarmPayloadPurposeSnoozeStatus = 'snoozeStatus';
const _alarmTriggerChannel = MethodChannel(
  'com.teamproject.synced_alarm/alarm_trigger',
);
const _alarmSchedulerChannel = MethodChannel(
  'com.teamproject.synced_alarm/alarm_scheduler',
);

const alarmNotificationActions = <AndroidNotificationAction>[
  AndroidNotificationAction(alarmNotificationSnoozeActionId, 'Snooze'),
  AndroidNotificationAction(
    alarmNotificationDismissActionId,
    'Dismiss',
    semanticAction: SemanticAction.delete,
  ),
];

const _ringingChannel = AndroidNotificationChannel(
  alarmNotificationChannelId,
  'Synced Alarm Ringing',
  description: 'Scheduled alarm notifications with repeated alert sound.',
  importance: Importance.max,
  playSound: true,
  enableVibration: false,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

String alarmNotificationChannelIdFor(Alarm alarm) {
  final sound = alarm.soundEnabled ? 'sound' : 'silent';
  return '${_alarmNotificationChannelPrefix}_${sound}_native_vibration';
}

AndroidNotificationChannel alarmNotificationChannelFor(Alarm alarm) {
  return AndroidNotificationChannel(
    alarmNotificationChannelIdFor(alarm),
    'Synced Alarm Ringing',
    description: 'Scheduled alarm notifications with native vibration control.',
    importance: Importance.max,
    playSound: alarm.soundEnabled,
    enableVibration: false,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );
}

const _syncChannel = AndroidNotificationChannel(
  alarmSyncNotificationChannelId,
  'Synced Alarm Sync',
  description: 'Silent synchronization status notifications.',
  importance: Importance.low,
  playSound: false,
  enableVibration: false,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await AlarmNotificationService.instance
      ._initializeBackgroundLocalNotifications();
  await AlarmNotificationService.instance.showRemoteMessage(message);
}

@pragma('vm:entry-point')
void alarmNotificationTapBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  await AlarmNotificationService.instance.handleBackgroundNotificationResponse(
    response,
  );
}

class AlarmNotificationService {
  AlarmNotificationService._();

  static final instance = AlarmNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<AlarmNotificationLaunch> _alarmLaunchController =
      StreamController<AlarmNotificationLaunch>.broadcast();
  final StreamController<AlarmNotificationActionRequest>
  _alarmActionController =
      StreamController<AlarmNotificationActionRequest>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  AlarmNotificationLaunch? _pendingAlarmLaunch;
  AlarmNotificationActionRequest? _pendingAlarmAction;
  bool _localInitialized = false;
  bool _messagingInitialized = false;
  bool _nativeAlarmTriggerInitialized = false;
  bool _timeZoneInitialized = false;
  bool _exactAlarmPermissionRequested = false;

  Stream<AlarmNotificationLaunch> get alarmLaunches =>
      _alarmLaunchController.stream;

  Stream<AlarmNotificationActionRequest> get alarmActions =>
      _alarmActionController.stream;

  AlarmNotificationLaunch? consumePendingAlarmLaunch() {
    final launch = _pendingAlarmLaunch;
    _pendingAlarmLaunch = null;
    return launch;
  }

  AlarmNotificationActionRequest? consumePendingAlarmAction() {
    final action = _pendingAlarmAction;
    _pendingAlarmAction = null;
    return action;
  }

  @visibleForTesting
  void handleNotificationResponseForTesting(NotificationResponse response) {
    _handleNotificationResponse(response);
  }

  Future<void> initialize({required bool firebaseEnabled}) async {
    await initializeLocalNotifications();
    if (firebaseEnabled) {
      await initializeFirebaseMessaging();
    }
  }

  Future<void> initializeLocalNotifications() async {
    await _initializeLocalNotifications(
      captureInitialLaunch: true,
      requestPermission: true,
    );
  }

  Future<void> _initializeBackgroundLocalNotifications() async {
    await _initializeLocalNotifications(
      captureInitialLaunch: false,
      requestPermission: false,
    );
  }

  Future<void> _initializeLocalNotifications({
    required bool captureInitialLaunch,
    required bool requestPermission,
  }) async {
    if (kIsWeb || _localInitialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      linux: LinuxInitializationSettings(
        defaultActionName: 'Open Synced Alarm',
      ),
      windows: WindowsInitializationSettings(
        appName: 'Synced Alarm',
        appUserModelId: 'com.teamproject.synced_alarm',
        guid: '7f87f1fc-7820-4c11-93c4-b6d1f9f0b2b5',
      ),
    );

    await _notifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          alarmNotificationTapBackground,
    );
    await _initializeNativeAlarmTriggers();
    if (captureInitialLaunch) {
      await _captureInitialAlarmLaunch();
    }
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(_ringingChannel);
    await androidImplementation?.createNotificationChannel(_syncChannel);
    if (requestPermission) {
      await androidImplementation?.requestNotificationsPermission();
    }
    _localInitialized = true;
  }

  Future<void> initializeFirebaseMessaging() async {
    if (_messagingInitialized) return;

    if (!kIsWeb) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      showRemoteMessage,
    );
    _messagingInitialized = true;
  }

  Future<void> showAlarm(Alarm alarm) async {
    final payload = AlarmNotificationPayload.fromAlarm(alarm);
    final details = _ringingNotificationDetailsFor(alarm);
    await initializeLocalNotifications();
    await _createRingingChannelFor(alarm);
    return _notifications.show(
      id: payload.id,
      title: payload.title,
      body: payload.body,
      notificationDetails: details,
      payload: payload.payload,
    );
  }

  Future<void> showSnoozeNotification(Alarm alarm) async {
    if (kIsWeb) return;
    if (alarm.snoozeUntil == null) return;

    final id = alarmNotificationId(alarm.id) + 10000;
    final payload = AlarmNotificationPayload.fromSnoozeStatus(alarm);

    final snoozeTime = alarm.snoozeUntil!;
    final hour = snoozeTime.hour;
    final minute = snoozeTime.minute.toString().padLeft(2, '0');
    final period = hour < 12 ? 'AM' : 'PM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$hour12:$minute $period';

    final label = alarm.label.trim().isEmpty ? 'Alarm' : alarm.label;
    final body =
        '$label · $timeStr에 다시 울립니다 (${alarm.snoozeCount}/${alarm.maxSnoozeCount}회)';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        alarmSyncNotificationChannelId,
        'Synced Alarm Sync',
        channelDescription: 'Alarm sync and status notifications.',
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.status,
        playSound: false,
        enableVibration: false,
        ongoing: true,
        autoCancel: false,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(
            alarmNotificationDismissActionId,
            'Dismiss',
            semanticAction: SemanticAction.delete,
          ),
        ],
      ),
      linux: LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.low,
        defaultActionName: 'Open Synced Alarm',
      ),
      windows: WindowsNotificationDetails(
        scenario: WindowsNotificationScenario.reminder,
        duration: WindowsNotificationDuration.short,
      ),
    );

    await initializeLocalNotifications();
    await _notifications.show(
      id: id,
      title: '스누즈 진행 중',
      body: body,
      notificationDetails: details,
      payload: payload.payload,
    );
  }

  Future<void> cancelSnoozeNotification(String alarmId) async {
    if (kIsWeb) return;
    final id = alarmNotificationId(alarmId) + 10000;
    await initializeLocalNotifications();
    await _notifications.cancel(id: id);
  }

  Future<void> scheduleAlarm(
    Alarm alarm, {
    bool requestExactPermission = false,
    bool background = false,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!alarm.enabled) {
      await cancelAlarm(alarm);
      return;
    }

    if (background) {
      await _initializeBackgroundLocalNotifications();
    } else {
      await initializeLocalNotifications();
    }
    await _initializeTimeZone();
    await cancelAlarm(alarm);
    await _createRingingChannelFor(alarm);
    final requests = AlarmNotificationRequest.scheduledRequestsFromAlarm(alarm);
    final exactAllowed = await _canScheduleExactAlarms(
      requestPermission: requestExactPermission,
    );
    final details = _ringingNotificationDetailsFor(alarm);
    for (final request in requests) {
      await _notifications.zonedSchedule(
        id: request.id,
        title: request.title,
        body: request.body,
        scheduledDate: tz.TZDateTime.from(request.scheduledAt, tz.local),
        notificationDetails: details,
        androidScheduleMode: exactAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: request.matchDateTimeComponents,
        payload: request.payload,
      );
    }
    if (!background) {
      await _scheduleForegroundAlarmTriggers(requests);
    }
  }

  Future<void> cancelAlarm(Alarm alarm) {
    return cancelAlarmById(alarm.id);
  }

  Future<void> cancelAlarmById(
    String alarmId, {
    bool background = false,
  }) async {
    if (kIsWeb) return;
    if (background) {
      await _initializeBackgroundLocalNotifications();
    } else {
      await initializeLocalNotifications();
    }
    await _notifications.cancel(id: alarmNotificationId(alarmId));
    for (final weekday in defaultAlarmRepeatWeekdays) {
      await _notifications.cancel(
        id: alarmNotificationWeekdayId(alarmId, weekday),
      );
    }
    if (!background) {
      await _cancelForegroundAlarmTriggersForAlarm(alarmId);
    }
  }

  Future<void> cancelAllAlarms({bool background = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      if (background) {
        await _initializeBackgroundLocalNotifications();
      } else {
        await initializeLocalNotifications();
      }
      await _notifications.cancelAll();
      if (!background) {
        await _alarmSchedulerChannel.invokeMethod<void>(
          'cancelAllForegroundTriggers',
        );
      }
    } on Object catch (error) {
      if ('$error'.startsWith('LateInitializationError')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> scheduleForegroundTriggersForAlarm(Alarm alarm) async {
    if (!alarm.enabled) return;
    await _scheduleForegroundAlarmTriggers(
      AlarmNotificationRequest.scheduledRequestsFromAlarm(alarm),
    );
  }

  Future<void> handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final action = AlarmNotificationActionRequest.fromResponse(response);
    if (action == null) return;

    final groupId = action.payloadData.groupId;
    final alarmId = action.alarmId;
    final hasGroup = groupId != null && groupId.isNotEmpty;

    String deviceId = 'unknown_device';
    try {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString('synced_alarm_device_id') ?? 'unknown_device';
    } catch (_) {}

    switch (action.type) {
      case AlarmNotificationActionType.dismiss:
        await cancelAlarmById(action.alarmId, background: true);
        if (hasGroup && FirebaseAuth.instance.currentUser != null) {
          try {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('alarms')
                .doc(alarmId)
                .set({
                  ...alarmDismissPatch(
                    now: DateTime.now(),
                    updatedBy: deviceId,
                  ),
                  'revision': FieldValue.increment(1),
                }, SetOptions(merge: true));

            final command = AlarmCommand.create(
              groupId: groupId,
              alarmId: alarmId,
              commandType: AlarmCommandType.dismiss,
              sourceDeviceId: deviceId,
            );
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('commands')
                .doc(command.id)
                .set(command.toJson());
          } catch (e, stackTrace) {
            debugPrint('Error dismissing alarm in background: $e\n$stackTrace');
          }
        }

      case AlarmNotificationActionType.snooze:
        final sourceAlarm = action.payloadData.toAlarm();
        if (sourceAlarm == null) return;
        if (sourceAlarm.maxSnoozeCount <= 0 ||
            sourceAlarm.snoozeCount >= sourceAlarm.maxSnoozeCount) {
          await cancelAlarmById(action.alarmId, background: true);
          if (hasGroup && FirebaseAuth.instance.currentUser != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .collection('alarms')
                  .doc(alarmId)
                  .set({
                    ...alarmDismissPatch(
                      now: DateTime.now(),
                      updatedBy: deviceId,
                    ),
                    'revision': FieldValue.increment(1),
                  }, SetOptions(merge: true));

              final command = AlarmCommand.create(
                groupId: groupId,
                alarmId: alarmId,
                commandType: AlarmCommandType.dismiss,
                sourceDeviceId: deviceId,
              );
              await FirebaseFirestore.instance
                  .collection('groups')
                  .doc(groupId)
                  .collection('commands')
                  .doc(command.id)
                  .set(command.toJson());
            } catch (e, stackTrace) {
              debugPrint(
                'Error auto-dismissing (max snooze) in background: $e\n$stackTrace',
              );
            }
          }
          return;
        }

        final now = DateTime.now();
        final snoozeUntil = now.add(
          Duration(minutes: sourceAlarm.snoozeMinutes),
        );
        final snoozeCount = sourceAlarm.snoozeCount + 1;
        final alarm = sourceAlarm.copyWith(
          snoozeUntil: snoozeUntil,
          snoozeCount: snoozeCount,
          lastTriggeredDate: now,
          updatedBy: deviceId,
          revision: sourceAlarm.revision + 1,
        );
        await cancelAlarmById(action.alarmId, background: true);
        await scheduleAlarm(alarm, background: true);

        if (hasGroup && FirebaseAuth.instance.currentUser != null) {
          try {
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('alarms')
                .doc(alarmId)
                .set({
                  ...alarmSnoozePatch(
                    now: now,
                    updatedBy: deviceId,
                    snoozeMinutes: sourceAlarm.snoozeMinutes,
                    snoozeCount: snoozeCount,
                  ),
                  'revision': FieldValue.increment(1),
                }, SetOptions(merge: true));

            final command = AlarmCommand.create(
              groupId: groupId,
              alarmId: alarmId,
              commandType: AlarmCommandType.snooze,
              sourceDeviceId: deviceId,
            );
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('commands')
                .doc(command.id)
                .set(command.toJson());
          } catch (e, stackTrace) {
            debugPrint('Error snoozing alarm in background: $e\n$stackTrace');
          }
        }
    }
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (message.notification == null &&
        !shouldShowRemoteDataNotification(message.data)) {
      await _handleSilentSync(message);
      return;
    }

    final payload = AlarmNotificationPayload.fromRemoteMessage(message);
    await showNotification(
      id: payload.id,
      title: payload.title,
      body: payload.body,
      payload: payload.payload,
      notificationDetails: _syncNotificationDetails,
    );
  }

  Alarm? _alarmFromData(
    Map<String, String> data,
    String alarmId,
    String groupId,
  ) {
    try {
      final hourAndMinuteStr = data['timeOfDayMinutes'];
      if (hourAndMinuteStr == null) return null;
      final timeOfDayMinutes = int.parse(hourAndMinuteStr);
      final enabled = data['enabled'] == 'true';

      final label = data['label'] ?? 'Alarm';
      final ringDurationMinutes = int.parse(data['ringDurationMinutes'] ?? '5');
      final soundEnabled = data['soundEnabled'] == 'true';
      final vibrationEnabled = data['vibrationEnabled'] == 'true';
      final snoozeMinutes = int.parse(data['snoozeMinutes'] ?? '5');
      final maxSnoozeCount = int.parse(data['maxSnoozeCount'] ?? '3');
      final snoozeCount = int.parse(data['snoozeCount'] ?? '0');
      final revision = int.parse(data['revision'] ?? '0');

      Set<int> repeatWeekdays = defaultAlarmRepeatWeekdays;
      if (data.containsKey('repeatWeekdays')) {
        try {
          final List<dynamic> list = jsonDecode(data['repeatWeekdays']!);
          repeatWeekdays = list.map((e) => int.parse(e.toString())).toSet();
        } catch (_) {}
      }

      DateTime? snoozeUntil;
      if (data['snoozeUntil'] != null && data['snoozeUntil']!.isNotEmpty) {
        snoozeUntil = DateTime.tryParse(data['snoozeUntil']!);
      }

      DateTime? lastTriggeredDate;
      if (data['lastTriggeredDate'] != null &&
          data['lastTriggeredDate']!.isNotEmpty) {
        lastTriggeredDate = DateTime.tryParse(data['lastTriggeredDate']!);
      }

      final createdAt =
          data['createdAt'] != null && data['createdAt']!.isNotEmpty
          ? DateTime.tryParse(data['createdAt']!) ?? DateTime.now()
          : DateTime.now();

      final updatedAt =
          data['updatedAt'] != null && data['updatedAt']!.isNotEmpty
          ? DateTime.tryParse(data['updatedAt']!) ?? DateTime.now()
          : DateTime.now();

      final updatedBy = data['updatedBy'];

      return Alarm(
        id: alarmId,
        groupId: groupId,
        label: label,
        timeOfDayMinutes: timeOfDayMinutes,
        enabled: enabled,
        repeatWeekdays: repeatWeekdays,
        ringDurationMinutes: ringDurationMinutes,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        snoozeMinutes: snoozeMinutes,
        maxSnoozeCount: maxSnoozeCount,
        snoozeCount: snoozeCount,
        snoozeUntil: snoozeUntil,
        lastTriggeredDate: lastTriggeredDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
        updatedBy: updatedBy != null && updatedBy.isNotEmpty ? updatedBy : null,
        revision: revision,
      );
    } catch (e, stackTrace) {
      debugPrint('Error parsing Alarm from FCM data: $e\n$stackTrace');
      return null;
    }
  }

  Future<void> _handleSilentSync(RemoteMessage message) async {
    final Map<String, String> data = message.data.cast<String, String>();
    final type = data['type'];
    final groupId = data['groupId'];
    final alarmId = data['alarmId'];

    if (groupId == null ||
        alarmId == null ||
        groupId.isEmpty ||
        alarmId.isEmpty) {
      return;
    }

    try {
      if (type == 'alarm.created' || type == 'alarm.updated') {
        final alarm = _alarmFromData(data, alarmId, groupId);
        if (alarm != null) {
          await scheduleAlarm(alarm, background: true);
        } else {
          debugPrint(
            'Silent sync: Alarm data was null or failed to parse from FCM payload.',
          );
        }
      } else if (shouldCancelLocalScheduleForSilentSync(data)) {
        await cancelAlarmById(alarmId, background: true);
      } else if (type == 'alarm.command') {
        debugPrint(
          'Silent sync: command ${data['commandType']} received for $alarmId; '
          'local schedule is driven by alarm update/delete payloads.',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Error during background silent sync: $e\n$stackTrace');
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    String? payload,
  }) async {
    if (kIsWeb) return;
    await initializeLocalNotifications();
    await _notifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  Future<void> _initializeTimeZone() async {
    if (_timeZoneInitialized) return;
    tz_data.initializeTimeZones();
    try {
      final timeZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZone.identifier));
    } on Object {
      tz.setLocalLocation(tz.local);
    }
    _timeZoneInitialized = true;
  }

  Future<bool> _canScheduleExactAlarms({
    required bool requestPermission,
  }) async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canSchedule = await androidImplementation
        ?.canScheduleExactNotifications();
    if (canSchedule == false &&
        requestPermission &&
        !_exactAlarmPermissionRequested) {
      _exactAlarmPermissionRequested = true;
      return await androidImplementation?.requestExactAlarmsPermission() ??
          false;
    }
    return canSchedule ?? true;
  }

  Future<void> _captureInitialAlarmLaunch() async {
    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp != true) return;
    final response = launchDetails?.notificationResponse;
    if (response != null) {
      _handleNotificationResponse(response);
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final action = AlarmNotificationActionRequest.fromResponse(response);
    if (action != null) {
      _pendingAlarmAction = action;
      _alarmActionController.add(action);
      return;
    }
    _handleNotificationPayload(response.payload);
  }

  void _handleNotificationPayload(
    String? payload, {
    AlarmNotificationLaunchSource source =
        AlarmNotificationLaunchSource.notification,
  }) {
    final launch = AlarmNotificationLaunch.fromPayload(payload, source: source);
    if (launch == null) return;
    _pendingAlarmLaunch = launch;
    _alarmLaunchController.add(launch);
  }

  Future<void> _initializeNativeAlarmTriggers() async {
    if (_nativeAlarmTriggerInitialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _alarmTriggerChannel.setMethodCallHandler(_handleNativeAlarmTriggerCall);
    _nativeAlarmTriggerInitialized = true;
    try {
      final pendingPayload = await _alarmTriggerChannel.invokeMethod<String>(
        'consumePendingAlarmTrigger',
      );
      if (pendingPayload != null && pendingPayload.isNotEmpty) {
        _handleNotificationPayload(
          pendingPayload,
          source: AlarmNotificationLaunchSource.nativeForeground,
        );
      }
    } on MissingPluginException {
      return;
    }
  }

  Future<Object?> _handleNativeAlarmTriggerCall(MethodCall call) async {
    if (call.method != 'alarmTriggered') return null;
    final payload = call.arguments as String?;
    if (payload == null || payload.isEmpty) return false;
    _handleNotificationPayload(
      payload,
      source: AlarmNotificationLaunchSource.nativeForeground,
    );
    return true;
  }

  Future<void> _scheduleForegroundAlarmTriggers(
    List<AlarmNotificationRequest> requests,
  ) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final args = foregroundAlarmTriggerArgumentsFromRequests(requests);
    if (args.isEmpty) return;
    try {
      await _alarmSchedulerChannel.invokeMethod<void>(
        'scheduleForegroundTriggers',
        args,
      );
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _cancelForegroundAlarmTriggersForAlarm(String alarmId) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _alarmSchedulerChannel.invokeMethod<void>(
        'cancelForegroundTriggers',
        foregroundAlarmTriggerIdsForAlarm(alarmId),
      );
    } on MissingPluginException {
      return;
    }
  }

  Future<void> _createRingingChannelFor(Alarm alarm) async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImplementation?.createNotificationChannel(
      alarmNotificationChannelFor(alarm),
    );
  }

  NotificationDetails _ringingNotificationDetailsFor(Alarm alarm) {
    final channel = alarmNotificationChannelFor(alarm);
    final additionalFlags = alarm.soundEnabled
        ? Int32List.fromList(<int>[alarmNotificationSoundRepeatFlag])
        : null;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        playSound: alarm.soundEnabled,
        enableVibration: false,
        silent: !alarm.soundEnabled && !alarm.vibrationEnabled,
        fullScreenIntent: true,
        additionalFlags: additionalFlags,
        timeoutAfter: alarm.ringDurationMinutes * 60 * 1000,
        ongoing: true,
        autoCancel: false,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        actions: alarmNotificationActions,
      ),
      linux: LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.critical,
        defaultActionName: 'Open Synced Alarm',
      ),
      windows: WindowsNotificationDetails(
        scenario: WindowsNotificationScenario.alarm,
        duration: WindowsNotificationDuration.long,
      ),
    );
  }

  NotificationDetails get _syncNotificationDetails {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _syncChannel.id,
        _syncChannel.name,
        channelDescription: _syncChannel.description,
        importance: Importance.low,
        priority: Priority.low,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.status,
      ),
      linux: LinuxNotificationDetails(
        urgency: LinuxNotificationUrgency.low,
        defaultActionName: 'Open Synced Alarm',
      ),
      windows: WindowsNotificationDetails(
        scenario: WindowsNotificationScenario.reminder,
        duration: WindowsNotificationDuration.short,
      ),
    );
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    _messagingInitialized = false;
  }
}

bool shouldShowRemoteDataNotification(Map<String, dynamic> data) {
  final type = '${data['type'] ?? ''}';
  if (type == 'alarm.created' ||
      type == 'alarm.updated' ||
      type == 'alarm.deleted' ||
      type == 'alarm.command') {
    return false;
  }
  return type.isNotEmpty;
}

bool shouldCancelLocalScheduleForSilentSync(Map<String, dynamic> data) {
  return '${data['type'] ?? ''}' == 'alarm.deleted';
}

Map<String, Object?> alarmDismissPatch({
  required DateTime now,
  required String updatedBy,
}) {
  final timestamp = now.toIso8601String();
  return {
    'snoozeUntil': null,
    'snoozeCount': 0,
    'lastTriggeredDate': timestamp,
    'updatedAt': timestamp,
    'updatedBy': updatedBy,
  };
}

Map<String, Object?> alarmSnoozePatch({
  required DateTime now,
  required String updatedBy,
  required int snoozeMinutes,
  required int snoozeCount,
}) {
  final timestamp = now.toIso8601String();
  return {
    'snoozeUntil': now.add(Duration(minutes: snoozeMinutes)).toIso8601String(),
    'snoozeCount': snoozeCount,
    'lastTriggeredDate': timestamp,
    'updatedAt': timestamp,
    'updatedBy': updatedBy,
  };
}

enum AlarmNotificationLaunchSource {
  notification,
  nativeForeground,
  foregroundTimer,
}

class AlarmNotificationLaunch {
  const AlarmNotificationLaunch({
    required this.alarmId,
    this.source = AlarmNotificationLaunchSource.notification,
  });

  static AlarmNotificationLaunch? fromPayload(
    String? payload, {
    AlarmNotificationLaunchSource source =
        AlarmNotificationLaunchSource.notification,
  }) {
    final data = AlarmNotificationPayloadData.fromPayload(payload);
    if (data != null) {
      if (!data.launchesAlarmUi) return null;
      return AlarmNotificationLaunch(alarmId: data.alarmId, source: source);
    }

    const alarmPayloadPrefix = 'alarm:';
    if (payload == null || !payload.startsWith(alarmPayloadPrefix)) {
      return null;
    }

    final alarmId = payload.substring(alarmPayloadPrefix.length).trim();
    if (alarmId.isEmpty) return null;
    return AlarmNotificationLaunch(alarmId: alarmId, source: source);
  }

  final String alarmId;
  final AlarmNotificationLaunchSource source;
}

enum AlarmNotificationActionType { dismiss, snooze }

class AlarmNotificationActionRequest {
  const AlarmNotificationActionRequest({
    required this.alarmId,
    required this.type,
    required this.payloadData,
  });

  static AlarmNotificationActionRequest? fromResponse(
    NotificationResponse response,
  ) {
    final payloadData = AlarmNotificationPayloadData.fromPayload(
      response.payload,
    );
    if (payloadData == null) return null;

    final type = switch (response.actionId) {
      alarmNotificationDismissActionId => AlarmNotificationActionType.dismiss,
      alarmNotificationSnoozeActionId => AlarmNotificationActionType.snooze,
      _ => null,
    };
    if (type == null) return null;

    return AlarmNotificationActionRequest(
      alarmId: payloadData.alarmId,
      type: type,
      payloadData: payloadData,
    );
  }

  final String alarmId;
  final AlarmNotificationActionType type;
  final AlarmNotificationPayloadData payloadData;
}

class AlarmNotificationPayloadData {
  const AlarmNotificationPayloadData({
    required this.alarmId,
    this.groupId,
    this.label,
    this.timeOfDayMinutes,
    this.repeatWeekdays = defaultAlarmRepeatWeekdays,
    this.ringDurationMinutes = defaultAlarmRingDurationMinutes,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.snoozeMinutes = defaultAlarmSnoozeMinutes,
    this.maxSnoozeCount = defaultAlarmMaxSnoozeCount,
    this.snoozeCount = 0,
    this.purpose = _alarmPayloadPurposeAlarm,
  });

  factory AlarmNotificationPayloadData.fromAlarm(
    Alarm alarm, {
    String purpose = _alarmPayloadPurposeAlarm,
  }) {
    return AlarmNotificationPayloadData(
      alarmId: alarm.id,
      groupId: alarm.groupId,
      label: alarm.label,
      timeOfDayMinutes: alarm.timeOfDayMinutes,
      repeatWeekdays: alarm.repeatWeekdays,
      ringDurationMinutes: alarm.ringDurationMinutes,
      soundEnabled: alarm.soundEnabled,
      vibrationEnabled: alarm.vibrationEnabled,
      snoozeMinutes: alarm.snoozeMinutes,
      maxSnoozeCount: alarm.maxSnoozeCount,
      snoozeCount: alarm.snoozeCount,
      purpose: purpose,
    );
  }

  static AlarmNotificationPayloadData? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['type'] != 'alarm') return null;
      final alarmId = decoded['alarmId'] as String?;
      if (alarmId == null || alarmId.trim().isEmpty) return null;
      final purpose =
          decoded['purpose'] as String? ?? _alarmPayloadPurposeAlarm;
      return AlarmNotificationPayloadData(
        alarmId: alarmId,
        groupId: decoded['groupId'] as String?,
        label: decoded['label'] as String?,
        timeOfDayMinutes: decoded['timeOfDayMinutes'] as int?,
        repeatWeekdays: _payloadWeekdays(decoded['repeatWeekdays']),
        ringDurationMinutes:
            decoded['ringDurationMinutes'] as int? ??
            defaultAlarmRingDurationMinutes,
        soundEnabled: decoded['soundEnabled'] as bool? ?? true,
        vibrationEnabled: decoded['vibrationEnabled'] as bool? ?? true,
        snoozeMinutes:
            decoded['snoozeMinutes'] as int? ?? defaultAlarmSnoozeMinutes,
        maxSnoozeCount:
            decoded['maxSnoozeCount'] as int? ?? defaultAlarmMaxSnoozeCount,
        snoozeCount: decoded['snoozeCount'] as int? ?? 0,
        purpose: purpose,
      );
    } on Object {
      const alarmPayloadPrefix = 'alarm:';
      if (!payload.startsWith(alarmPayloadPrefix)) return null;
      final alarmId = payload.substring(alarmPayloadPrefix.length).trim();
      if (alarmId.isEmpty) return null;
      return AlarmNotificationPayloadData(alarmId: alarmId);
    }
  }

  final String alarmId;
  final String? groupId;
  final String? label;
  final int? timeOfDayMinutes;
  final Set<int> repeatWeekdays;
  final int ringDurationMinutes;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int snoozeMinutes;
  final int maxSnoozeCount;
  final int snoozeCount;
  final String purpose;

  bool get launchesAlarmUi => purpose == _alarmPayloadPurposeAlarm;

  String encode() {
    return jsonEncode({
      'type': 'alarm',
      'purpose': purpose,
      'alarmId': alarmId,
      if (groupId != null) 'groupId': groupId,
      if (label != null) 'label': label,
      if (timeOfDayMinutes != null) 'timeOfDayMinutes': timeOfDayMinutes,
      'repeatWeekdays': repeatWeekdays.toList()..sort(),
      'ringDurationMinutes': ringDurationMinutes,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'snoozeMinutes': snoozeMinutes,
      'maxSnoozeCount': maxSnoozeCount,
      'snoozeCount': snoozeCount,
    });
  }

  Alarm? toAlarm({DateTime? snoozeUntil, int? snoozeCount}) {
    final minutes = timeOfDayMinutes;
    if (minutes == null) return null;
    final now = DateTime.now();
    return Alarm(
      id: alarmId,
      groupId: groupId ?? 'demo',
      label: label?.trim().isEmpty ?? true ? 'Alarm' : label!.trim(),
      timeOfDayMinutes: minutes,
      enabled: true,
      repeatWeekdays: repeatWeekdays,
      ringDurationMinutes: ringDurationMinutes,
      soundEnabled: soundEnabled,
      vibrationEnabled: vibrationEnabled,
      snoozeMinutes: snoozeMinutes,
      maxSnoozeCount: maxSnoozeCount,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      snoozeUntil: snoozeUntil,
      createdAt: now,
      updatedAt: now,
    );
  }
}

Set<int> _payloadWeekdays(Object? value) {
  if (value is Iterable) {
    final weekdays = value
        .whereType<int>()
        .where((weekday) => weekday >= DateTime.monday)
        .where((weekday) => weekday <= DateTime.sunday)
        .toSet();
    if (weekdays.isNotEmpty) return Set.unmodifiable(weekdays);
  }
  return defaultAlarmRepeatWeekdays;
}

class AlarmNotificationPayload {
  const AlarmNotificationPayload({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  factory AlarmNotificationPayload.fromAlarm(Alarm alarm) {
    final data = AlarmNotificationPayloadData.fromAlarm(alarm);
    return AlarmNotificationPayload(
      id: alarmNotificationId(alarm.id),
      title: 'Synced Alarm',
      body: '${alarm.timeLabel} · ${alarm.label}',
      payload: data.encode(),
    );
  }

  factory AlarmNotificationPayload.fromSnoozeStatus(Alarm alarm) {
    final data = AlarmNotificationPayloadData.fromAlarm(
      alarm,
      purpose: _alarmPayloadPurposeSnoozeStatus,
    );
    return AlarmNotificationPayload(
      id: alarmNotificationId(alarm.id) + 10000,
      title: '스누즈 진행 중',
      body: '${alarm.timeLabel} · ${alarm.label}',
      payload: data.encode(),
    );
  }

  factory AlarmNotificationPayload.fromData(Map<String, dynamic> data) {
    final type = '${data['type'] ?? 'alarm.update'}';
    final alarmId = '${data['alarmId'] ?? ''}';
    final commandType = '${data['commandType'] ?? ''}';
    final title = switch (type) {
      'alarm.command' => 'Alarm command',
      'alarm.created' => 'Alarm created',
      'alarm.updated' => 'Alarm updated',
      'alarm.deleted' => 'Alarm deleted',
      _ => 'Synced Alarm',
    };
    final body = commandType.isNotEmpty
        ? 'Command: $commandType'
        : alarmId.isNotEmpty
        ? 'Alarm: $alarmId'
        : 'Alarm sync update received';

    return AlarmNotificationPayload(
      id: Object.hash(type, alarmId, commandType),
      title: title,
      body: body,
      payload: alarmId.isEmpty ? type : '$type:$alarmId',
    );
  }

  factory AlarmNotificationPayload.fromRemoteMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      return AlarmNotificationPayload(
        id: (message.messageId ?? notification.hashCode.toString()).hashCode,
        title: notification.title ?? 'Synced Alarm',
        body: notification.body ?? 'Alarm sync update received',
        payload: message.messageId,
      );
    }
    return AlarmNotificationPayload.fromData(message.data);
  }

  final int id;
  final String title;
  final String body;
  final String? payload;
}

class AlarmNotificationRequest {
  const AlarmNotificationRequest({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.scheduledAt,
    required this.matchDateTimeComponents,
  });

  factory AlarmNotificationRequest.fromAlarm(Alarm alarm, {DateTime? from}) {
    final payload = AlarmNotificationPayload.fromAlarm(alarm);
    final base = from ?? DateTime.now();
    final isSnoozed =
        alarm.snoozeUntil != null && alarm.snoozeUntil!.isAfter(base);
    return AlarmNotificationRequest(
      id: payload.id,
      title: payload.title,
      body: payload.body,
      payload: payload.payload,
      scheduledAt: alarm.nextOccurrence(base),
      matchDateTimeComponents: isSnoozed ? null : DateTimeComponents.time,
    );
  }

  static List<AlarmNotificationRequest> scheduledRequestsFromAlarm(
    Alarm alarm, {
    DateTime? from,
  }) {
    final base = from ?? DateTime.now();
    if (alarm.snoozeUntil != null && alarm.snoozeUntil!.isAfter(base)) {
      return [AlarmNotificationRequest.fromAlarm(alarm, from: base)];
    }

    final payload = AlarmNotificationPayload.fromAlarm(alarm);
    final weekdays = alarm.repeatWeekdays.toList()..sort();
    return [
      for (final weekday in weekdays)
        () {
          final scheduledAt = _nextWeekdayOccurrence(alarm, weekday, base);
          // 만약 다음 실행 날짜가 6일 이상 떨어져 있고 오늘 요일과 일치한다면(이미 오늘 울리고 다음 주로 계산된 경우),
          // dayOfWeekAndTime 버그를 방지하기 위해 단발성(matchDateTimeComponents = null) 알람으로 예약을 우회합니다.
          final isNextWeekAlready =
              scheduledAt.difference(base).inDays >= 6 &&
              weekday == base.weekday;
          return AlarmNotificationRequest(
            id: alarmNotificationWeekdayId(alarm.id, weekday),
            title: payload.title,
            body: payload.body,
            payload: payload.payload,
            scheduledAt: scheduledAt,
            matchDateTimeComponents: isNextWeekAlready
                ? null
                : DateTimeComponents.dayOfWeekAndTime,
          );
        }(),
    ];
  }

  final int id;
  final String title;
  final String body;
  final String? payload;
  final DateTime scheduledAt;
  final DateTimeComponents? matchDateTimeComponents;
}

List<Map<String, Object?>> foregroundAlarmTriggerArgumentsFromRequests(
  List<AlarmNotificationRequest> requests,
) {
  return [
    for (final request in requests)
      {
        'id': request.id,
        'triggerAtMillis': request.scheduledAt.millisecondsSinceEpoch,
        'payload': request.payload,
      },
  ];
}

List<int> foregroundAlarmTriggerIdsForAlarm(String alarmId) {
  return [
    alarmNotificationId(alarmId),
    for (final weekday in defaultAlarmRepeatWeekdays)
      alarmNotificationWeekdayId(alarmId, weekday),
  ];
}

DateTime _nextWeekdayOccurrence(Alarm alarm, int weekday, DateTime from) {
  final todayAtAlarmTime = DateTime(
    from.year,
    from.month,
    from.day,
    alarm.timeOfDay.hour,
    alarm.timeOfDay.minute,
  );
  for (var dayOffset = 0; dayOffset <= 7; dayOffset++) {
    final candidate = todayAtAlarmTime.add(Duration(days: dayOffset));
    if (candidate.weekday == weekday && candidate.isAfter(from)) {
      return candidate;
    }
  }
  return todayAtAlarmTime.add(const Duration(days: 7));
}

int alarmNotificationId(String alarmId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in alarmId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

int alarmNotificationWeekdayId(String alarmId, int weekday) {
  return alarmNotificationId('$alarmId-weekday-$weekday');
}
