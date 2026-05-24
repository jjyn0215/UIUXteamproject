import 'dart:async';
import 'dart:io' show Platform;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../firebase_options.dart';
import '../models/account.dart';
import '../models/alarm.dart';
import '../models/device_registration.dart';
import '../platform/alarm_notification_service.dart';
import '../platform/alarm_task_controller.dart';
import 'account_repository.dart';
import 'alarm_repository.dart';
import 'firebase_account_repository.dart';
import 'firebase_alarm_repository.dart';
import 'firebase_device_registrar.dart';
import 'local_demo_alarm_repository.dart';

const useFirebase = bool.fromEnvironment('USE_FIREBASE');
const useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
final isFlutterTest =
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
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

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  final version = packageInfo.version.trim();
  final buildNumber = packageInfo.buildNumber.trim();
  if (buildNumber.isEmpty) return version;
  return '$version+$buildNumber';
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

  const secureStorage = FlutterSecureStorage();
  final existingSecure = await secureStorage.read(key: _deviceIdPrefsKey);
  if (existingSecure != null && existingSecure.isNotEmpty) {
    return existingSecure;
  }

  final prefs = await SharedPreferences.getInstance();
  final existingPrefs = prefs.getString(_deviceIdPrefsKey);
  if (existingPrefs != null && existingPrefs.isNotEmpty) {
    await secureStorage.write(key: _deviceIdPrefsKey, value: existingPrefs);
    await prefs.remove(_deviceIdPrefsKey);
    return existingPrefs;
  }

  final generated = _uuid.v4();
  await secureStorage.write(key: _deviceIdPrefsKey, value: generated);
  return generated;
});

final alarmsProvider = StreamProvider<List<Alarm>>((ref) {
  if (ref.watch(cloudSyncEnabledProvider)) {
    final groups = ref.watch(userGroupsProvider).value ?? const [];
    if (groups.isEmpty) {
      return Stream.value(const <Alarm>[]);
    }

    final controller = StreamController<List<Alarm>>();
    final subscriptions = <String, StreamSubscription>{};
    final latestAlarms = <String, List<Alarm>>{};

    void emitMerged() {
      if (controller.isClosed) return;
      final merged = latestAlarms.values.expand((list) => list).toList();
      merged.sort((a, b) => a.timeOfDayMinutes.compareTo(b.timeOfDayMinutes));
      controller.add(merged);
    }

    ref
        .watch(firebaseReadyProvider.future)
        .then((_) {
          if (controller.isClosed) return;
          for (final group in groups) {
            final stream = ref
                .read(alarmRepositoryProvider)
                .watchAlarms(groupId: group.groupId, accessCode: '');
            subscriptions[group.groupId] = stream.listen(
              (alarms) {
                latestAlarms[group.groupId] = alarms;
                emitMerged();
              },
              onError: (err) {
                debugPrint(
                  'Error watching alarms for group ${group.groupId}: $err',
                );
              },
            );
          }
        })
        .catchError((err) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        });

    ref.onDispose(() {
      for (final sub in subscriptions.values) {
        sub.cancel();
      }
      controller.close();
    });

    return controller.stream;
  }
  final repository = ref.watch(alarmRepositoryProvider);
  return repository.watchAlarms(
    groupId: defaultGroupId,
    accessCode: defaultAccessCode,
  );
});

final deviceRegistrationProvider = FutureProvider<List<DeviceRegistration>>((
  ref,
) async {
  if (!useFirebase) return const [];

  final user = ref.watch(authStateProvider).value;
  if (user == null) return const [];

  await ref.watch(firebaseReadyProvider.future);
  final deviceId = await ref.watch(deviceIdProvider.future);
  final registrar = FirebaseDeviceRegistrar();
  final registrations = <DeviceRegistration>[];

  final groups = ref.watch(userGroupsProvider).value ?? const [];

  if (groups.isEmpty) {
    try {
      final reg = await registrar.registerCurrentDevice(
        groupId: null,
        deviceId: deviceId,
        webVapidKey: firebaseMessagingVapidKey.isEmpty
            ? null
            : firebaseMessagingVapidKey,
      );
      registrations.add(reg);
    } catch (e, st) {
      debugPrint('Failed to register user-only device: $e\n$st');
      rethrow;
    }
  } else {
    for (final group in groups) {
      try {
        final reg = await registrar.registerCurrentDevice(
          groupId: group.groupId,
          deviceId: deviceId,
          webVapidKey: firebaseMessagingVapidKey.isEmpty
              ? null
              : firebaseMessagingVapidKey,
        );
        registrations.add(reg);
      } catch (e, st) {
        debugPrint(
          'Failed to register device for group ${group.groupId}: $e\n$st',
        );
        rethrow;
      }
    }
  }
  return registrations;
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
    final error =
        firebaseReady.error ??
        authState.error ??
        userGroups.error ??
        deviceRegistration.error;

    return SyncStatus(
      type: SyncStatusType.error,
      label: 'Sync unavailable',
      detail: error != null
          ? 'Error: $error'
          : 'Open settings and check account or network state.',
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
    required String groupId,
    Set<int>? repeatWeekdays,
    int? ringDurationMinutes,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? snoozeMinutes,
    int? maxSnoozeCount,
  }) async {
    await _ensureReady();
    final deviceId = await _deviceId();
    final alarm = Alarm.create(
      groupId: groupId,
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
      revision: alarm.revision + 1,
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
    if (!enabled) {
      await AlarmNotificationService.instance.cancelSnoozeNotification(
        alarm.id,
      );
    }
  }

  Future<void> deleteAlarm(Alarm alarm) async {
    await _ensureReady();
    await _repository.deleteAlarm(
      groupId: alarm.groupId,
      alarmId: alarm.id,
      accessCode: '',
    );
    await _cancelLocalAlarm(alarm.id);
    await AlarmNotificationService.instance.cancelSnoozeNotification(alarm.id);
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
    await AlarmNotificationService.instance.cancelSnoozeNotification(alarm.id);
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

  Future<void> dismiss(Alarm alarm, {bool clearRingingAlarm = true}) async {
    await _ensureReady();
    final deviceId = await _deviceId();
    if (clearRingingAlarm) {
      _ref.read(ringingAlarmProvider.notifier).clear();
    }
    await _cancelLocalAlarm(alarm.id);
    await AlarmNotificationService.instance.cancelSnoozeNotification(alarm.id);
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

  Future<void> snooze(Alarm alarm, {bool clearRingingAlarm = true}) async {
    await _ensureReady();
    if (alarm.maxSnoozeCount <= 0 ||
        alarm.snoozeCount >= alarm.maxSnoozeCount) {
      await dismiss(alarm, clearRingingAlarm: clearRingingAlarm);
      return;
    }
    final deviceId = await _deviceId();
    if (clearRingingAlarm) {
      _ref.read(ringingAlarmProvider.notifier).clear();
    }
    await _cancelLocalAlarm(alarm.id);
    final snoozedAlarm = alarm.copyWith(
      snoozeUntil: DateTime.now().add(Duration(minutes: alarm.snoozeMinutes)),
      lastTriggeredDate: DateTime.now(),
      snoozeCount: alarm.snoozeCount + 1,
      updatedBy: deviceId,
    );
    await _repository.upsertAlarm(snoozedAlarm, accessCode: '');
    await _syncSingleLocalAlarm(snoozedAlarm);
    await AlarmNotificationService.instance.showSnoozeNotification(
      snoozedAlarm,
    );
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

final permissionStateProvider =
    NotifierProvider<PermissionStateNotifier, AsyncValue<bool>>(
      PermissionStateNotifier.new,
    );

class PermissionStateNotifier extends Notifier<AsyncValue<bool>> {
  @override
  AsyncValue<bool> build() {
    if (isFlutterTest) {
      return const AsyncValue.data(true);
    }
    _checkPermissionsInitially();
    return const AsyncValue.loading();
  }

  Future<void> _checkPermissionsInitially() async {
    await checkPermissions();
  }

  Future<void> checkPermissions() async {
    try {
      if (isFlutterTest) {
        state = const AsyncValue.data(true);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('hasSeenPermissionGuide') ?? false;
      if (!hasSeen) {
        state = const AsyncValue.data(false);
        return;
      }

      final notificationGranted = await Permission.notification.isGranted;
      final exactAlarmGranted = await Permission.scheduleExactAlarm.isGranted;
      final fullScreenIntentGranted =
          await AlarmTaskController.canUseFullScreenIntent();

      state = AsyncValue.data(
        notificationGranted && exactAlarmGranted && fullScreenIntentGranted,
      );
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> completeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenPermissionGuide', true);
    await checkPermissions();
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _themePrefsKey = 'synced_alarm_theme_mode';

  @override
  ThemeMode build() {
    if (isFlutterTest) {
      return ThemeMode.system;
    }
    _loadThemeMode();
    return ThemeMode.system;
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeStr = prefs.getString(_themePrefsKey) ?? 'system';
      state = _parseThemeMode(themeStr);
    } catch (_) {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefsKey, _themeModeToString(mode));
    } catch (_) {}
  }

  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

class DefaultAlarmSettings {
  const DefaultAlarmSettings({
    required this.snoozeMinutes,
    required this.ringDurationMinutes,
    required this.soundEnabled,
    required this.vibrationEnabled,
  });

  final int snoozeMinutes;
  final int ringDurationMinutes;
  final bool soundEnabled;
  final bool vibrationEnabled;

  DefaultAlarmSettings copyWith({
    int? snoozeMinutes,
    int? ringDurationMinutes,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return DefaultAlarmSettings(
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      ringDurationMinutes: ringDurationMinutes ?? this.ringDurationMinutes,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

class DefaultAlarmSettingsNotifier extends Notifier<DefaultAlarmSettings> {
  static const _snoozeKey = 'default_alarm_snooze_minutes';
  static const _ringKey = 'default_alarm_ring_duration_minutes';
  static const _soundKey = 'default_alarm_sound_enabled';
  static const _vibrateKey = 'default_alarm_vibration_enabled';

  @override
  DefaultAlarmSettings build() {
    if (isFlutterTest) {
      return const DefaultAlarmSettings(
        snoozeMinutes: 5,
        ringDurationMinutes: 5,
        soundEnabled: true,
        vibrationEnabled: true,
      );
    }
    _loadSettings();
    return const DefaultAlarmSettings(
      snoozeMinutes: 5,
      ringDurationMinutes: 5,
      soundEnabled: true,
      vibrationEnabled: true,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = DefaultAlarmSettings(
        snoozeMinutes: prefs.getInt(_snoozeKey) ?? 5,
        ringDurationMinutes: prefs.getInt(_ringKey) ?? 5,
        soundEnabled: prefs.getBool(_soundKey) ?? true,
        vibrationEnabled: prefs.getBool(_vibrateKey) ?? true,
      );
    } catch (_) {}
  }

  Future<void> setSnoozeMinutes(int minutes) async {
    state = state.copyWith(snoozeMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeKey, minutes);
  }

  Future<void> setRingDurationMinutes(int minutes) async {
    state = state.copyWith(ringDurationMinutes: minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_ringKey, minutes);
  }

  Future<void> setSoundEnabled(bool enabled) async {
    state = state.copyWith(soundEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundKey, enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    state = state.copyWith(vibrationEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrateKey, enabled);
  }
}

final defaultAlarmSettingsProvider =
    NotifierProvider<DefaultAlarmSettingsNotifier, DefaultAlarmSettings>(
      DefaultAlarmSettingsNotifier.new,
    );

class LocaleNotifier extends Notifier<Locale?> {
  static const _localePrefsKey = 'synced_alarm_locale';

  @override
  Locale? build() {
    if (isFlutterTest) {
      return const Locale('en');
    }
    _loadLocale();
    return null;
  }

  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_localePrefsKey);
      if (languageCode != null) {
        state = Locale(languageCode);
      }
    } catch (_) {}
  }

  Future<void> setLocale(Locale? locale) async {
    state = locale;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (locale != null) {
        await prefs.setString(_localePrefsKey, locale.languageCode);
      } else {
        await prefs.remove(_localePrefsKey);
      }
    } catch (_) {}
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale?>(
  LocaleNotifier.new,
);

final groupDevicesProvider = StreamProvider<List<DeviceRegistration>>((ref) {
  if (!useFirebase) {
    return Stream.value(const []);
  }

  final groups = ref.watch(userGroupsProvider).value ?? const [];
  if (groups.isEmpty) {
    return Stream.value(const <DeviceRegistration>[]);
  }

  final controller = StreamController<List<DeviceRegistration>>();
  final subscriptions = <String, StreamSubscription>{};
  final latestDevices = <String, List<DeviceRegistration>>{};

  void emitMerged() {
    if (controller.isClosed) return;

    final uniqueDevices = <String, DeviceRegistration>{};
    for (final deviceList in latestDevices.values) {
      for (final device in deviceList) {
        uniqueDevices[device.id] = device;
      }
    }

    final merged = uniqueDevices.values.toList();
    merged.sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    controller.add(merged);
  }

  for (final group in groups) {
    final stream = FirebaseFirestore.instance
        .collection('groups')
        .doc(group.groupId)
        .collection('devices')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DeviceRegistration.fromJson(doc.id, doc.data());
          }).toList();
        });

    subscriptions[group.groupId] = stream.listen(
      (devices) {
        latestDevices[group.groupId] = devices;
        emitMerged();
      },
      onError: (err) {
        debugPrint('Error watching devices for group ${group.groupId}: $err');
      },
    );
  }

  ref.onDispose(() {
    for (final sub in subscriptions.values) {
      sub.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

final userDevicesProvider = StreamProvider<List<DeviceRegistration>>((ref) {
  if (!useFirebase) {
    return Stream.value(const []);
  }

  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value(const []);
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('devices')
      .snapshots()
      .map((snapshot) {
        return snapshot.docs.map((doc) {
          return DeviceRegistration.fromJson(doc.id, doc.data());
        }).toList();
      });
});

final groupDevicesFamilyProvider =
    StreamProvider.family<List<DeviceRegistration>, String>((ref, groupId) {
      if (!useFirebase) {
        return Stream.value(const []);
      }

      return FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('devices')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return DeviceRegistration.fromJson(doc.id, doc.data());
            }).toList();
          });
    });

final groupMembersFamilyProvider =
    StreamProvider.family<List<GroupMember>, String>((ref, groupId) {
      if (!useFirebase) {
        return Stream.value(const []);
      }

      return FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('members')
          .snapshots()
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              return GroupMember.fromJson(doc.id, doc.data());
            }).toList();
          });
    });
