import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/alarm.dart';
import 'alarm_repository.dart';
import 'firebase_operation_timeout.dart';

class FirebaseAlarmRepository implements AlarmRepository {
  FirebaseAlarmRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<void> joinGroup({
    required String groupId,
    required String accessCode,
  }) async {
    _ensureSignedIn();
    final callable = _functions.httpsCallable('joinGroup');
    await withFirebaseOperationTimeout(
      callable.call<Map<String, Object?>>({
        'groupId': groupId,
        'accessCode': accessCode,
      }),
      operationName: 'join group',
    );
  }

  @override
  Stream<List<Alarm>> watchAlarms({
    required String groupId,
    required String accessCode,
  }) async* {
    _ensureSignedIn();
    yield* _group(groupId)
        .collection('alarms')
        .orderBy('timeOfDayMinutes')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return Alarm.fromJson(doc.id, {...doc.data(), 'groupId': groupId});
          }).toList();
        });
  }

  @override
  Future<void> upsertAlarm(Alarm alarm, {required String accessCode}) async {
    _ensureSignedIn();
    await _group(alarm.groupId)
        .collection('alarms')
        .doc(alarm.id)
        .set(alarm.toJson(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteAlarm({
    required String groupId,
    required String alarmId,
    required String accessCode,
  }) async {
    _ensureSignedIn();
    await _group(groupId).collection('alarms').doc(alarmId).delete();
  }

  @override
  Future<void> setAlarmEnabled({
    required String groupId,
    required String alarmId,
    required bool enabled,
    required String accessCode,
  }) async {
    _ensureSignedIn();
    await _group(groupId).collection('alarms').doc(alarmId).set({
      'enabled': enabled,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': _auth.currentUser?.uid,
      'revision': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> sendCommand(
    AlarmCommand command, {
    required String accessCode,
  }) async {
    _ensureSignedIn();
    await _group(
      command.groupId,
    ).collection('commands').doc(command.id).set(command.toJson());
  }

  DocumentReference<Map<String, dynamic>> _group(String groupId) {
    return _firestore.collection('groups').doc(groupId);
  }

  void _ensureSignedIn() {
    if (_auth.currentUser == null) {
      throw StateError('Sign in before using Firebase alarms.');
    }
  }
}
