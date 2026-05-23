import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/device_registration.dart';
import 'firebase_operation_timeout.dart';

class FirebaseDeviceRegistrar {
  FirebaseDeviceRegistrar({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Future<DeviceRegistration> registerCurrentDevice({
    String? groupId,
    required String deviceId,
    String? webVapidKey,
  }) async {
    final user = await _ensureSignedIn();

    final token = await _fcmToken(webVapidKey: webVapidKey);
    final humanName = await _humanReadableDeviceName(deviceId);
    final registration = DeviceRegistration(
      id: deviceId,
      uid: user.uid,
      groupId: groupId ?? '',
      platform: _platformName,
      displayName: humanName,
      fcmToken: token,
      notificationsEnabled: token != null,
      lastSeenAt: DateTime.now(),
    );

    if (groupId != null && groupId.isNotEmpty) {
      await withFirebaseOperationTimeout(
        _firestore
            .collection('groups')
            .doc(groupId)
            .collection('devices')
            .doc(deviceId)
            .set(registration.toJson(), SetOptions(merge: true)),
        operationName: 'register device',
      );
    }

    await withFirebaseOperationTimeout(
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection('devices')
          .doc(deviceId)
          .set(registration.toJson(), SetOptions(merge: true)),
      operationName: 'register user device',
    );

    return registration;
  }

  Future<User> _ensureSignedIn() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;
    throw StateError('Sign in before registering this device.');
  }

  Future<String?> _fcmToken({String? webVapidKey}) async {
    if (!_supportsFcm) return null;
    try {
      final settings = await withFirebaseOperationTimeout(
        _messaging.requestPermission(),
        operationName: 'notification permission request',
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await withFirebaseOperationTimeout(
        _messaging.getToken(vapidKey: webVapidKey),
        operationName: 'FCM token fetch',
      );
    } catch (e, st) {
      debugPrint('FCM token fetch failed: $e\n$st');
      return null;
    }
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

  /// 기기 제조사+모델명 + 축약 ID를 조합하여 사람이 읽을 수 있는 기기 이름을 생성합니다.
  /// 예: "Samsung Galaxy S24 (a7f3)"
  Future<String> _humanReadableDeviceName(String deviceId) async {
    final shortId = deviceId.length >= 4 ? deviceId.substring(0, 4) : deviceId;

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        final browser = webInfo.browserName.name;
        return '$browser ($shortId)';
      }

      if (!kIsWeb && Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        final manufacturer = _capitalize(androidInfo.manufacturer);
        final model = androidInfo.model;
        // 일부 기기에서 모델명에 이미 제조사가 포함됨 (예: "Samsung SM-S928N")
        if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) {
          return '$model ($shortId)';
        }
        return '$manufacturer $model ($shortId)';
      }

      if (!kIsWeb && Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        final name = iosInfo.name;
        return '$name ($shortId)';
      }

      if (!kIsWeb && Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return '${linuxInfo.prettyName} ($shortId)';
      }

      if (!kIsWeb && Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return '${windowsInfo.computerName} ($shortId)';
      }
    } catch (e) {
      debugPrint('Failed to get device info: $e');
    }

    return '$_platformName ($shortId)';
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  Future<void> deleteDevice({
    required String uid,
    required String deviceId,
    required List<String> groupIds,
  }) async {
    await _ensureSignedIn();
    await withFirebaseOperationTimeout(
      _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .delete(),
      operationName: 'delete user device',
    );

    for (final groupId in groupIds) {
      try {
        await withFirebaseOperationTimeout(
          _firestore
              .collection('groups')
              .doc(groupId)
              .collection('devices')
              .doc(deviceId)
              .delete(),
          operationName: 'delete group device mapping',
        );
      } catch (e, st) {
        debugPrint(
          'Failed to delete device mapping for group $groupId: $e\n$st',
        );
      }
    }
  }
}

@visibleForTesting
bool supportsFirebaseMessaging({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb || platform == TargetPlatform.android;
}
