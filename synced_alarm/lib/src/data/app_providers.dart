import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';
import '../models/alarm.dart';
import '../models/device_registration.dart';
import '../platform/alarm_notification_service.dart';
import 'alarm_repository.dart';
import 'firebase_alarm_repository.dart';
import 'firebase_device_registrar.dart';
import 'local_demo_alarm_repository.dart';

const useFirebase = bool.fromEnvironment('USE_FIREBASE');
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const firebaseEmulatorHost = String.fromEnvironment(
  'FIREBASE_EMULATOR_HOST',
  defaultValue: 'localhost',
);
const firebaseAuthEmulatorPort = int.fromEnvironment(
  'FIREBASE_AUTH_EMULATOR_PORT',
  defaultValue: 9099,
);
const firestoreEmulatorPort = int.fromEnvironment(
  'FIRESTORE_EMULATOR_PORT',
  defaultValue: 8080,
);
const firebaseFunctionsEmulatorPort = int.fromEnvironment(
  'FIREBASE_FUNCTIONS_EMULATOR_PORT',
  defaultValue: 5001,
);
const firebaseMessagingVapidKey = String.fromEnvironment(
  'FIREBASE_MESSAGING_VAPID_KEY',
);
const defaultGroupId = String.fromEnvironment(
  'ALARM_GROUP_ID',
  defaultValue: 'demo',
);
const defaultAccessCode = String.fromEnvironment(
  'ALARM_ACCESS_CODE',
  defaultValue: 'demo-access',
);
const defaultDeviceId = String.fromEnvironment(
  'ALARM_DEVICE_ID',
  defaultValue: 'local-device',
);

var _firebaseEmulatorsConnected = false;

final firebaseReadyProvider = FutureProvider<bool>((ref) async {
  if (!useFirebase) return false;
  await ensureFirebaseInitialized();
  return true;
});

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  if (useFirebase) {
    ref.watch(firebaseReadyProvider);
    return FirebaseAlarmRepository();
  }
  return LocalDemoAlarmRepository();
});

final alarmsProvider = StreamProvider<List<Alarm>>((ref) {
  if (useFirebase) {
    return ref.watch(firebaseReadyProvider.future).asStream().asyncExpand((_) {
      final repository = ref.watch(alarmRepositoryProvider);
      return repository.watchAlarms(
        groupId: defaultGroupId,
        accessCode: defaultAccessCode,
      );
    });
  }
  final repository = ref.watch(alarmRepositoryProvider);
  return repository.watchAlarms(
    groupId: defaultGroupId,
    accessCode: defaultAccessCode,
  );
});

final deviceRegistrationProvider = FutureProvider<DeviceRegistration?>((
  ref,
) async {
  if (!useFirebase) return null;
  await ref.watch(firebaseReadyProvider.future);
  return FirebaseDeviceRegistrar().registerCurrentDevice(
    groupId: defaultGroupId,
    accessCode: defaultAccessCode,
    deviceId: defaultDeviceId,
    webVapidKey: firebaseMessagingVapidKey.isEmpty
        ? null
        : firebaseMessagingVapidKey,
  );
});

final ringingAlarmProvider = NotifierProvider<RingingAlarmNotifier, Alarm?>(
  RingingAlarmNotifier.new,
);

class RingingAlarmNotifier extends Notifier<Alarm?> {
  @override
  Alarm? build() => null;

  void show(Alarm alarm) {
    state = alarm;
  }

  void clear() {
    state = null;
  }
}

final alarmListControllerProvider = Provider<AlarmListController>((ref) {
  return AlarmListController(ref);
});

class AlarmListController {
  AlarmListController(this._ref);

  final Ref _ref;
  Set<String> _knownLocalAlarmIds = {};

  AlarmRepository get _repository => _ref.read(alarmRepositoryProvider);
  AlarmNotificationService get _notifications =>
      AlarmNotificationService.instance;

  Future<void> _ensureReady() async {
    if (useFirebase) {
      await _ref.read(firebaseReadyProvider.future);
    }
  }

  Future<void> createAlarm({
    required String label,
    required int timeOfDayMinutes,
  }) async {
    await _ensureReady();
    final alarm = Alarm.create(
      groupId: defaultGroupId,
      label: label,
      time: _timeFromMinutes(timeOfDayMinutes),
      updatedBy: defaultDeviceId,
    );
    await _repository.upsertAlarm(alarm, accessCode: defaultAccessCode);
    await _syncSingleLocalAlarm(alarm, requestExactPermission: true);
  }

  Future<void> updateAlarm(Alarm alarm) async {
    await _ensureReady();
    await _repository.upsertAlarm(alarm, accessCode: defaultAccessCode);
    await _syncSingleLocalAlarm(alarm, requestExactPermission: true);
  }

  Future<void> toggleAlarm(Alarm alarm, bool enabled) async {
    await _ensureReady();
    await _repository.setAlarmEnabled(
      groupId: alarm.groupId,
      alarmId: alarm.id,
      enabled: enabled,
      accessCode: defaultAccessCode,
    );
    await _syncSingleLocalAlarm(
      alarm.copyWith(enabled: enabled),
      requestExactPermission: enabled,
    );
  }

  Future<void> deleteAlarm(Alarm alarm) async {
    await _ensureReady();
    await _repository.deleteAlarm(
      groupId: alarm.groupId,
      alarmId: alarm.id,
      accessCode: defaultAccessCode,
    );
    await _cancelLocalAlarm(alarm.id);
  }

  Future<void> syncScheduledAlarms(List<Alarm> alarms) async {
    final incomingIds = alarms.map((alarm) => alarm.id).toSet();
    for (final removedId in _knownLocalAlarmIds.difference(incomingIds)) {
      await _cancelLocalAlarm(removedId);
    }
    for (final alarm in alarms) {
      await _syncSingleLocalAlarm(alarm);
    }
    _knownLocalAlarmIds = incomingIds;
  }

  Future<void> ring(Alarm alarm) async {
    await _ensureReady();
    _ref.read(ringingAlarmProvider.notifier).show(alarm);
    await AlarmNotificationService.instance.showAlarm(alarm);
    await _repository.sendCommand(
      AlarmCommand.create(
        groupId: alarm.groupId,
        alarmId: alarm.id,
        commandType: AlarmCommandType.ring,
        sourceDeviceId: defaultDeviceId,
      ),
      accessCode: defaultAccessCode,
    );
  }

  Future<void> dismiss(Alarm alarm) async {
    await _ensureReady();
    _ref.read(ringingAlarmProvider.notifier).clear();
    await _cancelLocalAlarm(alarm.id);
    if (alarm.enabled) {
      await _syncSingleLocalAlarm(alarm);
    }
    await _repository.sendCommand(
      AlarmCommand.create(
        groupId: alarm.groupId,
        alarmId: alarm.id,
        commandType: AlarmCommandType.dismiss,
        sourceDeviceId: defaultDeviceId,
      ),
      accessCode: defaultAccessCode,
    );
  }

  Future<void> snooze(Alarm alarm) async {
    await _ensureReady();
    _ref.read(ringingAlarmProvider.notifier).clear();
    await _cancelLocalAlarm(alarm.id);
    final snoozedAlarm = alarm.copyWith(
      snoozeUntil: DateTime.now().add(const Duration(minutes: 5)),
    );
    await _syncSingleLocalAlarm(snoozedAlarm);
    await _repository.sendCommand(
      AlarmCommand.create(
        groupId: alarm.groupId,
        alarmId: alarm.id,
        commandType: AlarmCommandType.snooze,
        sourceDeviceId: defaultDeviceId,
      ),
      accessCode: defaultAccessCode,
    );
  }

  Future<void> _syncSingleLocalAlarm(
    Alarm alarm, {
    bool requestExactPermission = false,
  }) async {
    try {
      if (alarm.enabled) {
        await _notifications.scheduleAlarm(
          alarm,
          requestExactPermission: requestExactPermission,
        );
      } else {
        await _notifications.cancelAlarm(alarm);
      }
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Could not sync local notification for alarm ${alarm.id}: '
        '$error\n$stackTrace',
      );
    }
  }

  Future<void> _cancelLocalAlarm(String alarmId) async {
    try {
      await _notifications.cancelAlarmById(alarmId);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Could not cancel local notification for alarm $alarmId: '
        '$error\n$stackTrace',
      );
    }
  }
}

TimeOfDay _timeFromMinutes(int minutes) {
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

Future<void> ensureFirebaseInitialized() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  if (useFirebaseEmulator && !_firebaseEmulatorsConnected) {
    await FirebaseAuth.instance.useAuthEmulator(
      firebaseEmulatorHost,
      firebaseAuthEmulatorPort,
    );
    FirebaseFirestore.instance.useFirestoreEmulator(
      firebaseEmulatorHost,
      firestoreEmulatorPort,
    );
    FirebaseFunctions.instance.useFunctionsEmulator(
      firebaseEmulatorHost,
      firebaseFunctionsEmulatorPort,
    );
    _firebaseEmulatorsConnected = true;
  }
}
