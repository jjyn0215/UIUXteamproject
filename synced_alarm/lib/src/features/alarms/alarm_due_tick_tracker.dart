import '../../models/alarm.dart';

class AlarmDueTickTracker {
  final Set<String> _handledTicks = {};

  bool shouldRing(Alarm alarm, DateTime now) {
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return false;
    final justBecameDue =
        !dueAt.isAfter(now) &&
        now.difference(dueAt) < const Duration(seconds: 70);
    if (!justBecameDue) return false;
    return _handledTicks.add(alarmDueTickKey(alarm, dueAt));
  }

  void markHandled(Alarm alarm, DateTime now) {
    final dueAt = alarmDueTimeFor(alarm, now);
    if (dueAt == null) return;
    _handledTicks.add(alarmDueTickKey(alarm, dueAt));
  }
}

DateTime? alarmDueTimeFor(Alarm alarm, DateTime now) {
  if (alarm.snoozeUntil != null &&
      now.difference(alarm.snoozeUntil!).abs() < const Duration(minutes: 10)) {
    return alarm.snoozeUntil;
  }
  return DateTime(
    now.year,
    now.month,
    now.day,
    alarm.timeOfDay.hour,
    alarm.timeOfDay.minute,
  );
}

String alarmDueTickKey(Alarm alarm, DateTime dueAt) {
  return '${alarm.id}-${dueAt.year}-${dueAt.month}-${dueAt.day}-'
      '${dueAt.hour}-${dueAt.minute}';
}
