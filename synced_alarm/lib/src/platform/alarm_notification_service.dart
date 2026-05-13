import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../firebase_options.dart';
import '../models/alarm.dart';

const alarmNotificationChannelId = 'synced_alarm_ringing_v2';
const alarmSyncNotificationChannelId = 'synced_alarm_sync_v1';
const alarmNotificationSoundRepeatFlag = 4;
const alarmNotificationDismissActionId = 'alarm_action_dismiss';
const alarmNotificationSnoozeActionId = 'alarm_action_snooze';
const alarmSnoozeDuration = Duration(minutes: 5);

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
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

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
  await AlarmNotificationService.instance.initializeLocalNotifications();
  await AlarmNotificationService.instance.showRemoteMessage(message);
}

@pragma('vm:entry-point')
void alarmNotificationTapBackground(NotificationResponse response) async {
  DartPluginRegistrant.ensureInitialized();
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

  Future<void> showAlarm(Alarm alarm) {
    final payload = AlarmNotificationPayload.fromAlarm(alarm);
    return showNotification(
      id: payload.id,
      title: payload.title,
      body: payload.body,
      payload: payload.payload,
      notificationDetails: _ringingNotificationDetails,
    );
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
    final request = AlarmNotificationRequest.fromAlarm(alarm);
    final exactAllowed = await _canScheduleExactAlarms(
      requestPermission: requestExactPermission,
    );
    await _notifications.zonedSchedule(
      id: request.id,
      title: request.title,
      body: request.body,
      scheduledDate: tz.TZDateTime.from(request.scheduledAt, tz.local),
      notificationDetails: _ringingNotificationDetails,
      androidScheduleMode: exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: request.matchDateTimeComponents,
      payload: request.payload,
    );
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
  }

  Future<void> handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) async {
    final action = AlarmNotificationActionRequest.fromResponse(response);
    if (action == null) return;

    switch (action.type) {
      case AlarmNotificationActionType.dismiss:
        await cancelAlarmById(action.alarmId, background: true);
      case AlarmNotificationActionType.snooze:
        final alarm = action.payloadData.toAlarm(
          snoozeUntil: DateTime.now().add(alarmSnoozeDuration),
        );
        if (alarm == null) return;
        await cancelAlarmById(action.alarmId, background: true);
        await scheduleAlarm(alarm, background: true);
    }
  }

  Future<void> showRemoteMessage(RemoteMessage message) async {
    if (message.notification == null &&
        !shouldShowRemoteDataNotification(message.data)) {
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

  void _handleNotificationPayload(String? payload) {
    final launch = AlarmNotificationLaunch.fromPayload(payload);
    if (launch == null) return;
    _pendingAlarmLaunch = launch;
    _alarmLaunchController.add(launch);
  }

  NotificationDetails get _ringingNotificationDetails {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _ringingChannel.id,
        _ringingChannel.name,
        channelDescription: _ringingChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        additionalFlags: Int32List.fromList(<int>[
          alarmNotificationSoundRepeatFlag,
        ]),
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

class AlarmNotificationLaunch {
  const AlarmNotificationLaunch({required this.alarmId});

  static AlarmNotificationLaunch? fromPayload(String? payload) {
    final data = AlarmNotificationPayloadData.fromPayload(payload);
    if (data != null) {
      return AlarmNotificationLaunch(alarmId: data.alarmId);
    }

    const alarmPayloadPrefix = 'alarm:';
    if (payload == null || !payload.startsWith(alarmPayloadPrefix)) {
      return null;
    }

    final alarmId = payload.substring(alarmPayloadPrefix.length).trim();
    if (alarmId.isEmpty) return null;
    return AlarmNotificationLaunch(alarmId: alarmId);
  }

  final String alarmId;
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
    final launch = AlarmNotificationLaunch.fromPayload(response.payload);
    if (payloadData == null || launch == null) return null;

    final type = switch (response.actionId) {
      alarmNotificationDismissActionId => AlarmNotificationActionType.dismiss,
      alarmNotificationSnoozeActionId => AlarmNotificationActionType.snooze,
      _ => null,
    };
    if (type == null) return null;

    return AlarmNotificationActionRequest(
      alarmId: launch.alarmId,
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
  });

  factory AlarmNotificationPayloadData.fromAlarm(Alarm alarm) {
    return AlarmNotificationPayloadData(
      alarmId: alarm.id,
      groupId: alarm.groupId,
      label: alarm.label,
      timeOfDayMinutes: alarm.timeOfDayMinutes,
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
      return AlarmNotificationPayloadData(
        alarmId: alarmId,
        groupId: decoded['groupId'] as String?,
        label: decoded['label'] as String?,
        timeOfDayMinutes: decoded['timeOfDayMinutes'] as int?,
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

  String encode() {
    return jsonEncode({
      'type': 'alarm',
      'alarmId': alarmId,
      if (groupId != null) 'groupId': groupId,
      if (label != null) 'label': label,
      if (timeOfDayMinutes != null) 'timeOfDayMinutes': timeOfDayMinutes,
    });
  }

  Alarm? toAlarm({DateTime? snoozeUntil}) {
    final minutes = timeOfDayMinutes;
    if (minutes == null) return null;
    final now = DateTime.now();
    return Alarm(
      id: alarmId,
      groupId: groupId ?? 'demo',
      label: label?.trim().isEmpty ?? true ? 'Alarm' : label!.trim(),
      timeOfDayMinutes: minutes,
      enabled: true,
      snoozeUntil: snoozeUntil,
      createdAt: now,
      updatedAt: now,
    );
  }
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

  final int id;
  final String title;
  final String body;
  final String? payload;
  final DateTime scheduledAt;
  final DateTimeComponents? matchDateTimeComponents;
}

int alarmNotificationId(String alarmId) {
  var hash = 0x811c9dc5;
  for (final codeUnit in alarmId.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}
