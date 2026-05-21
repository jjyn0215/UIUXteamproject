import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alarm.dart';
import 'alarm_repository.dart';

class LocalDemoAlarmRepository implements AlarmRepository {
  LocalDemoAlarmRepository();

  static const _prefsKey = 'synced_alarm_local_alarms_v1';

  final _controller = StreamController<List<Alarm>>.broadcast();
  List<Alarm> _alarms = const [];
  bool _loaded = false;

  @override
  Future<void> joinGroup({
    required String groupId,
    required String accessCode,
  }) async {
    if (groupId.trim().isEmpty || accessCode.trim().isEmpty) {
      throw ArgumentError('groupId and accessCode are required.');
    }
  }

  @override
  Stream<List<Alarm>> watchAlarms({
    required String groupId,
    required String accessCode,
  }) async* {
    await _ensureLoaded();
    yield _visibleAlarms(groupId);
    yield* _controller.stream.map((alarms) {
      return alarms.where((alarm) => alarm.groupId == groupId).toList();
    });
  }

  @override
  Future<void> upsertAlarm(Alarm alarm, {required String accessCode}) async {
    await _ensureLoaded();
    final index = _alarms.indexWhere((item) => item.id == alarm.id);
    final updated = alarm.copyWith(updatedAt: DateTime.now());
    if (index == -1) {
      _alarms = [..._alarms, updated];
    } else {
      _alarms = [..._alarms]..[index] = updated;
    }
    await _save();
    _emit();
  }

  @override
  Future<void> deleteAlarm({
    required String groupId,
    required String alarmId,
    required String accessCode,
  }) async {
    await _ensureLoaded();
    _alarms = _alarms.where((alarm) => alarm.id != alarmId).toList();
    await _save();
    _emit();
  }

  @override
  Future<void> setAlarmEnabled({
    required String groupId,
    required String alarmId,
    required bool enabled,
    required String accessCode,
  }) async {
    await _ensureLoaded();
    _alarms = [
      for (final alarm in _alarms)
        if (alarm.id == alarmId) alarm.copyWith(enabled: enabled) else alarm,
    ];
    await _save();
    _emit();
  }

  @override
  Future<void> sendCommand(
    AlarmCommand command, {
    required String accessCode,
  }) async {
    await _ensureLoaded();
    _alarms = [
      for (final alarm in _alarms)
        if (alarm.id == command.alarmId)
          switch (command.commandType) {
            AlarmCommandType.dismiss => alarm.copyWith(
              clearSnooze: true,
              lastTriggeredDate: DateTime.now(),
            ),
            AlarmCommandType.snooze =>
              alarm.maxSnoozeCount <= 0 ||
                      alarm.snoozeCount >= alarm.maxSnoozeCount
                  ? alarm.copyWith(
                      clearSnooze: true,
                      lastTriggeredDate: DateTime.now(),
                    )
                  : alarm.copyWith(
                      snoozeUntil: DateTime.now().add(
                        Duration(minutes: alarm.snoozeMinutes),
                      ),
                      snoozeCount: alarm.snoozeCount + 1,
                    ),
            AlarmCommandType.ring => alarm.copyWith(
              lastTriggeredDate: DateTime.now(),
            ),
          }
        else
          alarm,
    ];
    await _save();
    _emit();
  }

  List<Alarm> _visibleAlarms(String groupId) {
    final alarms = _alarms.where((alarm) => alarm.groupId == groupId).toList();
    alarms.sort((a, b) => a.timeOfDayMinutes.compareTo(b.timeOfDayMinutes));
    return alarms;
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(List.unmodifiable(_alarms));
    }
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_prefsKey);
    if (encoded == null || encoded.isEmpty) {
      _alarms = const [];
      _loaded = true;
      return;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is List) {
        _alarms =
            [
              for (final item in decoded)
                if (item is Map<String, Object?>)
                  Alarm.fromJson('${item['id'] ?? ''}', item),
            ].where((alarm) {
              return alarm.id.isNotEmpty && !_isLegacyDemoAlarm(alarm);
            }).toList();
      } else {
        _alarms = const [];
      }
    } on Object {
      _alarms = const [];
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode([
      for (final alarm in _alarms) {'id': alarm.id, ...alarm.toJson()},
    ]);
    await prefs.setString(_prefsKey, encoded);
  }

  bool _isLegacyDemoAlarm(Alarm alarm) {
    if (alarm.groupId != 'demo' || alarm.updatedBy != 'local-demo') {
      return false;
    }
    return alarm.label == 'Morning focus' || alarm.label == 'Class reminder';
  }
}
