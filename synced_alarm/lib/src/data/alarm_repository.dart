import '../models/alarm.dart';

abstract interface class AlarmRepository {
  Future<void> joinGroup({required String groupId, required String accessCode});

  Stream<List<Alarm>> watchAlarms({
    required String groupId,
    required String accessCode,
  });

  Future<void> upsertAlarm(Alarm alarm, {required String accessCode});

  Future<void> deleteAlarm({
    required String groupId,
    required String alarmId,
    required String accessCode,
  });

  Future<void> setAlarmEnabled({
    required String groupId,
    required String alarmId,
    required bool enabled,
    required String accessCode,
  });

  Future<void> sendCommand(AlarmCommand command, {required String accessCode});
}
