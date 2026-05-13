import 'package:flutter_test/flutter_test.dart';
import 'package:synced_alarm/src/features/alarms/alarm_due_tick_tracker.dart';
import 'package:synced_alarm/src/models/alarm.dart';

void main() {
  test('does not ring again after the current due tick is handled', () {
    final tracker = AlarmDueTickTracker();
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    tracker.markHandled(alarm, DateTime(2026, 5, 8, 8, 30, 10));

    expect(tracker.shouldRing(alarm, DateTime(2026, 5, 8, 8, 30, 20)), isFalse);
    expect(tracker.shouldRing(alarm, DateTime(2026, 5, 9, 8, 30, 10)), isTrue);
  });
}
