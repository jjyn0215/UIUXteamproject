import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/device_registration.dart';
import 'firebase_operation_timeout.dart';

class FirebaseDeviceRegistrar {
  FirebaseDeviceRegistrar({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseMessaging? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseMessaging _messaging;

  Future<DeviceRegistration> registerCurrentDevice({
    required String groupId,
    required String accessCode,
    required String deviceId,
    String? webVapidKey,
  }) async {
    final user = await _ensureSignedIn();
    if (accessCode.trim().isNotEmpty) {
      await withFirebaseOperationTimeout(
        _functions.httpsCallable('joinGroup').call<Map<String, Object?>>({
          'groupId': groupId,
          'accessCode': accessCode,
        }),
        operationName: 'join group',
      );
    }

    final token = await _fcmToken(webVapidKey: webVapidKey);
    final registration = DeviceRegistration(
      id: deviceId,
      uid: user.uid,
      groupId: groupId,
      platform: _platformName,
      displayName: '$_platformName-$deviceId',
      fcmToken: token,
      notificationsEnabled: token != null,
      lastSeenAt: DateTime.now(),
    );

    await _firestore
        .collection('groups')
        .doc(groupId)
        .collection('devices')
        .doc(deviceId)
        .set(registration.toJson(), SetOptions(merge: true));

    return registration;
  }

  Future<User> _ensureSignedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;
    throw StateError('Sign in before registering this device.');
  }

  Future<String?> _fcmToken({String? webVapidKey}) async {
    if (!_supportsFcm) return null;
    final settings = await withFirebaseOperationTimeout(
      _messaging.requestPermission(),
      operationName: 'notification permission request',
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return withFirebaseOperationTimeout(
      _messaging.getToken(vapidKey: webVapidKey),
      operationName: 'FCM token fetch',
    );
  }

  bool get _supportsFcm {
    return supportsFirebaseMessaging(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
    );
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }
}

@visibleForTesting
bool supportsFirebaseMessaging({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb || platform == TargetPlatform.android;
}
