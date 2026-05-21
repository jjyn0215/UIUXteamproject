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

const alarmNotificationChannelId = 'synced_alarm_ringing_v3_sound_vibration';
const alarmSyncNotificationChannelId = 'synced_alarm_sync_v1';
const alarmNotificationSoundRepeatFlag = 4;
const alarmNotificationDismissActionId = 'alarm_action_dismiss';
const alarmNotificationSnoozeActionId = 'alarm_action_snooze';
const _alarmNotificationChannelPrefix = 'synced_alarm_ringing_v3';

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

String alarmNotificationChannelIdFor(Alarm alarm) {
  final sound = alarm.soundEnabled ? 'sound' : 'silent';
  final vibration = alarm.vibrationEnabled ? 'vibration' : 'steady';
  return '${_alarmNotificationChannelPrefix}_${sound}_$vibration';
}

AndroidNotificationChannel alarmNotificationChannelFor(Alarm alarm) {
  return AndroidNotificationChannel(
    alarmNotificationChannelIdFor(alarm),
    'Synced Alarm Ringing',
    description: 'Scheduled alarm notifications with per-alarm alert settings.',
    importance: Importance.max,
    playSound: alarm.soundEnabled,
    enableVibration: alarm.vibrationEnabled,
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
    } on Object catch (error) {
      if ('$error'.startsWith('LateInitializationError')) {
        return;
      }
      rethrow;
    }
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
        final sourceAlarm = action.payloadData.toAlarm();
        if (sourceAlarm == null) return;
        if (sourceAlarm.maxSnoozeCount <= 0 ||
            sourceAlarm.snoozeCount >= sourceAlarm.maxSnoozeCount) {
          await cancelAlarmById(action.alarmId, background: true);
          return;
        }
        final alarm = sourceAlarm.copyWith(
          snoozeUntil: DateTime.now().add(
            Duration(minutes: sourceAlarm.snoozeMinutes),
          ),
          snoozeCount: sourceAlarm.snoozeCount + 1,
        );
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
        enableVibration: alarm.vibrationEnabled,
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
    this.repeatWeekdays = defaultAlarmRepeatWeekdays,
    this.ringDurationMinutes = defaultAlarmRingDurationMinutes,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.snoozeMinutes = defaultAlarmSnoozeMinutes,
    this.maxSnoozeCount = defaultAlarmMaxSnoozeCount,
    this.snoozeCount = 0,
  });

  factory AlarmNotificationPayloadData.fromAlarm(Alarm alarm) {
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

  String encode() {
    return jsonEncode({
      'type': 'alarm',
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
        AlarmNotificationRequest(
          id: alarmNotificationWeekdayId(alarm.id, weekday),
          title: payload.title,
          body: payload.body,
          payload: payload.payload,
          scheduledAt: _nextWeekdayOccurrence(alarm, weekday, base),
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        ),
    ];
  }

  final int id;
  final String title;
  final String body;
  final String? payload;
  final DateTime scheduledAt;
  final DateTimeComponents? matchDateTimeComponents;
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
