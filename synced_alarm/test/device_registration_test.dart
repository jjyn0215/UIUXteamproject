import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:synced_alarm/src/models/device_registration.dart';
import 'package:synced_alarm/src/data/firebase_device_registrar.dart';
import 'package:synced_alarm/src/data/firebase_operation_timeout.dart';

void main() {
  test('serializes device id for Firestore rules', () {
    final registration = DeviceRegistration(
      id: 'web-1',
      uid: 'uid-1',
      groupId: 'demo',
      platform: 'web',
      displayName: 'web-web-1',
      fcmToken: 'token',
      notificationsEnabled: true,
      lastSeenAt: DateTime.utc(2026),
    );

    expect(registration.toJson(), containsPair('deviceId', 'web-1'));
    expect(registration.toJson(), containsPair('uid', 'uid-1'));
    expect(registration.toJson(), containsPair('notificationsEnabled', true));
  });

  test('limits Firebase Messaging support to Android and Web', () {
    expect(
      supportsFirebaseMessaging(isWeb: false, platform: TargetPlatform.android),
      isTrue,
    );
    expect(
      supportsFirebaseMessaging(isWeb: true, platform: TargetPlatform.linux),
      isTrue,
    );
    expect(
      supportsFirebaseMessaging(isWeb: false, platform: TargetPlatform.linux),
      isFalse,
    );
    expect(
      supportsFirebaseMessaging(isWeb: false, platform: TargetPlatform.windows),
      isFalse,
    );
  });

  test('times out stalled Firebase startup operations', () async {
    final stalled = Completer<void>();

    await expectLater(
      withFirebaseOperationTimeout(
        stalled.future,
        operationName: 'anonymous sign-in',
        timeout: const Duration(milliseconds: 1),
      ),
      throwsA(isA<FirebaseOperationTimeoutException>()),
    );
  });
}
