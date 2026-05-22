import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/alarm.dart';

const _handledAlarmTicksPrefsKey = 'handled_alarm_due_ticks_v1';
const _handledAlarmTickRetention = Duration(hours: 12);

class AlarmDueTickTracker {
  final Map<String, DateTime> _handledTicks = {};

  Future<bool> shouldRing(Alarm alarm, DateTime now) async {
    await _refreshSharedTicks(now);
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return false;
    final justBecameDue =
        !dueAt.isAfter(now) &&
        now.difference(dueAt) < const Duration(seconds: 70);
    if (!justBecameDue) return false;
    final key = alarmDueTickKey(alarm, dueAt);
    if (_handledTicks.containsKey(key)) return false;
    await _markKeyHandled(key, now);
    return true;
  }

  Future<void> markHandled(Alarm alarm, DateTime now) async {
    await _refreshSharedTicks(now);
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return;
    final key = alarmDueTickKey(alarm, dueAt);
    await _markKeyHandled(key, now);
  }

  Future<void> _refreshSharedTicks(DateTime now) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final rawTicks = prefs.getString(_handledAlarmTicksPrefsKey);
      if (rawTicks != null) {
        final decoded = jsonDecode(rawTicks);
        if (decoded is Map<String, Object?>) {
          for (final entry in decoded.entries) {
            final addedAt = DateTime.tryParse(entry.value?.toString() ?? '');
            if (addedAt != null) {
              _handledTicks[entry.key] = addedAt;
            }
          }
        }
      }
    } catch (_) {
      // Local alarm suppression should never crash the ring flow.
    }
    _cleanup(now);
  }

  Future<void> _markKeyHandled(String key, DateTime now) async {
    _handledTicks[key] = now;
    _cleanup(now);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _handledTicks.map(
          (key, addedAt) => MapEntry(key, addedAt.toIso8601String()),
        ),
      );
      await prefs.setString(_handledAlarmTicksPrefsKey, encoded);
    } catch (_) {
      // In-memory suppression still protects the current Flutter instance.
    }
  }

  void _cleanup(DateTime now) {
    final cutoff = now.subtract(_handledAlarmTickRetention);
    _handledTicks.removeWhere((key, addedAt) => addedAt.isBefore(cutoff));
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
