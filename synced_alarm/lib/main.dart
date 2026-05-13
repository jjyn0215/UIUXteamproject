import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/synced_alarm_app.dart';
import 'src/data/app_providers.dart';
import 'src/platform/alarm_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useFirebase) {
    await ensureFirebaseInitialized();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  await AlarmNotificationService.instance.initialize(
    firebaseEnabled: useFirebase,
  );
  runApp(const ProviderScope(child: SyncedAlarmApp()));
}
