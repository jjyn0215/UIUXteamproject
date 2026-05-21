import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../firebase_options.dart';
import '../models/account.dart';
import '../models/alarm.dart';
import '../models/device_registration.dart';
import '../platform/alarm_notification_service.dart';
import 'account_repository.dart';
import 'alarm_repository.dart';
import 'firebase_account_repository.dart';
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
const _deviceIdPrefsKey = 'synced_alarm_device_id';
const _uuid = Uuid();

var _firebaseEmulatorsConnected = false;

final firebaseReadyProvider = FutureProvider<bool>((ref) async {
  if (!useFirebase) return false;
  await ensureFirebaseInitialized();
  return true;
});

final alarmRepositoryProvider = Provider<AlarmRepository>((ref) {
  if (ref.watch(cloudSyncEnabledProvider)) {
    ref.watch(firebaseReadyProvider);
    return FirebaseAlarmRepository();
  }
  return LocalDemoAlarmRepository();
});

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  ref.watch(firebaseReadyProvider);
  return FirebaseAccountRepository();
});

final authStateProvider = StreamProvider<User?>((ref) async* {
  if (!useFirebase) {
    yield null;
    return;
  }
  await ref.watch(firebaseReadyProvider.future);
  yield* ref.watch(accountRepositoryProvider).authStateChanges();
});

final userProfileProvider = StreamProvider<AppUserProfile?>((ref) {
  if (!useFirebase) return Stream<AppUserProfile?>.value(null);
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<AppUserProfile?>.value(null);
  return ref.watch(accountRepositoryProvider).watchUserProfile(user.uid);
});

final userGroupsProvider = StreamProvider<List<AlarmGroupSummary>>((ref) {
  if (!useFirebase) return Stream<List<AlarmGroupSummary>>.value(const []);
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<List<AlarmGroupSummary>>.value(const []);
  return ref.watch(accountRepositoryProvider).watchUserGroups(user.uid);
});

final activeGroupProvider = Provider<AlarmGroupSummary?>((ref) {
  if (!useFirebase) {
    return const AlarmGroupSummary(
      groupId: defaultGroupId,
      name: 'Demo Group',
      role: 'member',
    );
  }

  final groups = ref.watch(userGroupsProvider).value ?? const [];
  if (groups.isEmpty) return null;

  final activeGroupId = ref.watch(userProfileProvider).value?.lastActiveGroupId;
  if (activeGroupId != null) {
    for (final group in groups) {
      if (group.groupId == activeGroupId) return group;
    }
  }
  return groups.first;
});

final cloudSyncEnabledProvider = Provider<bool>((ref) {
  if (!useFirebase) return false;
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  return ref.watch(activeGroupProvider) != null;
});

final deviceIdProvider = FutureProvider<String>((ref) async {
  if (!useFirebase) return defaultDeviceId;
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(_deviceIdPrefsKey);
  if (existing != null && existing.isNotEmpty) return existing;

  final generated = _uuid.v4();
  await prefs.setString(_deviceIdPrefsKey, generated);
  return generated;
});

final alarmsProvider = StreamProvider<List<Alarm>>((ref) {
  if (ref.watch(cloudSyncEnabledProvider)) {
    final activeGroup = ref.watch(activeGroupProvider)!;
    return ref.watch(firebaseReadyProvider.future).asStream().asyncExpand((_) {
      final repository = ref.watch(alarmRepositoryProvider);
      return repository.watchAlarms(
        groupId: activeGroup.groupId,
        accessCode: '',
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
  if (!ref.watch(cloudSyncEnabledProvider)) return null;
  final activeGroup = ref.watch(activeGroupProvider)!;
  await ref.watch(firebaseReadyProvider.future);
  final deviceId = await ref.watch(deviceIdProvider.future);
  return FirebaseDeviceRegistrar().registerCurrentDevice(
    groupId: activeGroup.groupId,
    accessCode: '',
    deviceId: deviceId,
    webVapidKey: firebaseMessagingVapidKey.isEmpty
        ? null
        : firebaseMessagingVapidKey,
  );
});

enum SyncStatusType { local, needsGroup, syncing, active, error }

class SyncStatus {
  const SyncStatus({required this.type, required this.label, this.detail});

  final SyncStatusType type;
  final String label;
  final String? detail;
}

final syncStatusProvider = Provider<SyncStatus>((ref) {
  if (!useFirebase) {
    return const SyncStatus(
      type: SyncStatusType.local,
      label: 'Local mode',
      detail: 'Firebase is not enabled for this run.',
    );
  }

  final firebaseReady = ref.watch(firebaseReadyProvider);
  final authState = ref.watch(authStateProvider);
  final userGroups = ref.watch(userGroupsProvider);
  final deviceRegistration = ref.watch(deviceRegistrationProvider);

  if (firebaseReady.hasError ||
      authState.hasError ||
      userGroups.hasError ||
      deviceRegistration.hasError) {
    return const SyncStatus(
      type: SyncStatusType.error,
      label: 'Sync unavailable',
      detail: 'Open settings and check account or network state.',
    );
  }

  if (firebaseReady.isLoading || authState.isLoading || userGroups.isLoading) {
    return const SyncStatus(
      type: SyncStatusType.syncing,
      label: 'Checking sync',
    );
  }

  if (authState.value == null) {
    return const SyncStatus(
      type: SyncStatusType.local,
      label: 'Local mode',
      detail: 'Sign in to sync alarms with a group.',
    );
  }

  final activeGroup = ref.watch(activeGroupProvider);
  if (activeGroup == null) {
    return const SyncStatus(
      type: SyncStatusType.needsGroup,
      label: 'Needs group',
      detail: 'Create or join a group to start syncing.',
    );
  }

  if (deviceRegistration.isLoading) {
    return const SyncStatus(
      type: SyncStatusType.syncing,
      label: 'Registering device',
    );
  }

  return SyncStatus(
    type: SyncStatusType.active,
    label: 'Sync active',
    detail: activeGroup.name,
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
  bool _clearedUnknownScheduledAlarms = false;

  AlarmRepository get _repository => _ref.read(alarmRepositoryProvider);
  AlarmNotificationService get _notifications =>
      AlarmNotificationService.instance;

  Future<void> _ensureReady() async {
    if (_ref.read(cloudSyncEnabledProvider)) {
      await _ref.read(firebaseReadyProvider.future);
    }
  }

  Future<void> createAlarm({
    required String label,
    required int timeOfDayMinutes,
    Set<int>? repeatWeekdays,
    int? ringDurationMinutes,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? snoozeMinutes,
    int? maxSnoozeCount,
  }) async {
    await _ensureReady();
    final activeGroup = await _activeGroup();
    final deviceId = await _deviceId();
    final alarm = Alarm.create(
      groupId: activeGroup.groupId,
      label: label,
      time: _timeFromMinutes(timeOfDayMinutes),
      repeatWeekdays: repeatWeekdays ?? defaultAlarmRepeatWeekdays,
      ringDurationMinutes:
          ringDurationMinutes ?? defaultAlarmRingDurationMinutes,
      soundEnabled: soundEnabled ?? true,
      vibrationEnabled: vibrationEnabled ?? true,
      snoozeMinutes: snoozeMinutes ?? defaultAlarmSnoozeMinutes,
      maxSnoozeCount: maxSnoozeCount ?? defaultAlarmMaxSnoozeCount,
      updatedBy: deviceId,
    );
    await _repository.upsertAlarm(alarm, accessCode: '');
    await _syncSingleLocalAlarm(alarm, requestExactPermission: true);
  }

  Future<void> updateAlarm(Alarm alarm) async {
    await _ensureReady();
    final deviceId = await _deviceId();
    final updatedAlarm = alarm.copyWith(
      updatedBy: deviceId,
      revision: alarm.revision,
    );
    await _repository.upsertAlarm(updatedAlarm, accessCode: '');
    await _syncSingleLocalAlarm(updatedAlarm, requestExactPermission: true);
  }

  Future<void> toggleAlarm(Alarm alarm, bool enabled) async {
    await _ensureReady();
    await _repository.setAlarmEnabled(
      groupId: alarm.groupId,
      alarmId: alarm.id,
      enabled: enabled,
      accessCode: '',
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
      accessCode: '',
    );
    await _cancelLocalAlarm(alarm.id);
  }

  Future<void> syncScheduledAlarms(List<Alarm> alarms) async {
    if (!_clearedUnknownScheduledAlarms) {
      await _cancelAllLocalAlarms();
      _clearedUnknownScheduledAlarms = true;
    }
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
    final deviceId = await _deviceId();
    _ref.read(ringingAlarmProvider.notifier).show(alarm);
    await AlarmNotificationService.instance.showAlarm(alarm);
    await _repository.sendCommand(
      AlarmCommand.create(
        groupId: alarm.groupId,
        alarmId: alarm.id,
        commandType: AlarmCommandType.ring,
        sourceDeviceId: deviceId,
      ),
      accessCode: '',
    );
  }

  Future<void> dismiss(Alarm alarm) async {
    await _ensureReady();
    final deviceId = await _deviceId();
    _ref.read(ringingAlarmProvider.notifier).clear();
    await _cancelLocalAlarm(alarm.id);
    if (alarm.enabled) {
      final dismissedAlarm = alarm.copyWith(
        clearSnooze: true,
        lastTriggeredDate: DateTime.now(),
        updatedBy: deviceId,
      );
      await _repository.upsertAlarm(dismissedAlarm, accessCode: '');
      await _syncSingleLocalAlarm(dismissedAlarm);
    }
    await _repository.sendCommand(
      AlarmCommand.create(
        groupId: alarm.groupId,
        alarmId: alarm.id,
        commandType: AlarmCommandType.dismiss,
        sourceDeviceId: deviceId,
      ),
      accessCode: '',
    );
  }

  Future<void> snooze(Alarm alarm) async {
    await _ensureReady();
    if (alarm.maxSnoozeCount <= 0 ||
        alarm.snoozeCount >= alarm.maxSnoozeCount) {
      await dismiss(alarm);
      return;
    }
    final deviceId = await _deviceId();
    _ref.read(ringingAlarmProvider.notifier).clear();
    await _cancelLocalAlarm(alarm.id);
    final snoozedAlarm = alarm.copyWith(
      snoozeUntil: DateTime.now().add(Duration(minutes: alarm.snoozeMinutes)),
      lastTriggeredDate: DateTime.now(),
      snoozeCount: alarm.snoozeCount + 1,
      updatedBy: deviceId,
    );
    await _repository.upsertAlarm(snoozedAlarm, accessCode: '');
    await _syncSingleLocalAlarm(snoozedAlarm);
    await _repository.sendCommand(
      AlarmCommand.create(
        groupId: alarm.groupId,
        alarmId: alarm.id,
        commandType: AlarmCommandType.snooze,
        sourceDeviceId: deviceId,
      ),
      accessCode: '',
    );
  }

  Future<AlarmGroupSummary> _activeGroup() async {
    if (!_ref.read(cloudSyncEnabledProvider)) {
      return const AlarmGroupSummary(
        groupId: defaultGroupId,
        name: 'Demo Group',
        role: 'member',
      );
    }
    final activeGroup = _ref.read(activeGroupProvider);
    if (activeGroup == null) {
      throw StateError('Create or join a group before editing alarms.');
    }
    return activeGroup;
  }

  Future<String> _deviceId() {
    if (!_ref.read(cloudSyncEnabledProvider)) {
      return Future.value(defaultDeviceId);
    }
    return _ref.read(deviceIdProvider.future);
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

  Future<void> _cancelAllLocalAlarms() async {
    try {
      await _notifications.cancelAllAlarms();
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Could not cancel stale local notifications: $error\n$stackTrace',
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
