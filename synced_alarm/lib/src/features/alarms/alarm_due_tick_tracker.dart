import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/alarm.dart';

const _handledAlarmTicksPrefsKey = 'handled_alarm_due_ticks_v1';
const _resolvedAlarmTicksPrefsKey = 'resolved_alarm_due_ticks_v1';
const _handledAlarmTickRetention = Duration(hours: 12);

class AlarmDueTickTracker {
  final Map<String, DateTime> _handledTicks = {};
  final Map<String, DateTime> _resolvedTicks = {};

  Future<bool> shouldRing(Alarm alarm, DateTime now) async {
    await _refreshSharedTicks(
      prefsKey: _handledAlarmTicksPrefsKey,
      target: _handledTicks,
      now: now,
    );
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return false;
    final justBecameDue =
        !dueAt.isAfter(now) &&
        now.difference(dueAt) < const Duration(seconds: 70);
    if (!justBecameDue) return false;
    final key = alarmDueTickKey(alarm, dueAt);
    if (_handledTicks.containsKey(key)) return false;
    await _markKey(
      prefsKey: _handledAlarmTicksPrefsKey,
      target: _handledTicks,
      key: key,
      now: now,
    );
    return true;
  }

  Future<void> markHandled(Alarm alarm, DateTime now) async {
    await _refreshSharedTicks(
      prefsKey: _handledAlarmTicksPrefsKey,
      target: _handledTicks,
      now: now,
    );
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return;
    final key = alarmDueTickKey(alarm, dueAt);
    await _markKey(
      prefsKey: _handledAlarmTicksPrefsKey,
      target: _handledTicks,
      key: key,
      now: now,
    );
  }

  Future<void> markResolved(Alarm alarm, DateTime now) async {
    await _refreshSharedTicks(
      prefsKey: _resolvedAlarmTicksPrefsKey,
      target: _resolvedTicks,
      now: now,
    );
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return;
    final key = alarmDueTickKey(alarm, dueAt);
    await _markKey(
      prefsKey: _resolvedAlarmTicksPrefsKey,
      target: _resolvedTicks,
      key: key,
      now: now,
    );
  }

  Future<bool> isResolved(Alarm alarm, DateTime now) async {
    await _refreshSharedTicks(
      prefsKey: _resolvedAlarmTicksPrefsKey,
      target: _resolvedTicks,
      now: now,
    );
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return false;
    return _resolvedTicks.containsKey(alarmDueTickKey(alarm, dueAt));
  }

  Future<void> _refreshSharedTicks({
    required String prefsKey,
    required Map<String, DateTime> target,
    required DateTime now,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawTicks = prefs.getString(prefsKey);
      if (rawTicks != null) {
        final decoded = jsonDecode(rawTicks);
        if (decoded is Map<String, Object?>) {
          for (final entry in decoded.entries) {
            final addedAt = DateTime.tryParse(entry.value?.toString() ?? '');
            if (addedAt != null) {
              target[entry.key] = addedAt;
            }
          }
        }
      }
    } catch (_) {
      // Local alarm suppression should never crash the ring flow.
    }
    _cleanup(target, now);
  }

  Future<void> _markKey({
    required String prefsKey,
    required Map<String, DateTime> target,
    required String key,
    required DateTime now,
  }) async {
    target[key] = now;
    _cleanup(target, now);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        target.map((key, addedAt) => MapEntry(key, addedAt.toIso8601String())),
      );
      await prefs.setString(prefsKey, encoded);
    } catch (_) {
      // In-memory suppression still protects the current Flutter instance.
    }
  }

  void _cleanup(Map<String, DateTime> target, DateTime now) {
    final cutoff = now.subtract(_handledAlarmTickRetention);
    target.removeWhere((key, addedAt) => addedAt.isBefore(cutoff));
  }
}

DateTime? alarmDueTimeFor(Alarm alarm, DateTime now) {
  if (alarm.snoozeUntil != null &&
      now.difference(alarm.snoozeUntil!).abs() < const Duration(minutes: 10)) {
    return alarm.snoozeUntil;
  }
  final dueAt = DateTime(
    now.year,
    now.month,
    now.day,
    alarm.timeOfDay.hour,
    alarm.timeOfDay.minute,
  );
  if (!alarm.repeatWeekdays.contains(dueAt.weekday)) return null;
  return dueAt;
}

String alarmDueTickKey(Alarm alarm, DateTime dueAt) {
  return '${alarm.id}-${dueAt.year}-${dueAt.month}-${dueAt.day}-'
      '${dueAt.hour}-${dueAt.minute}';
}
