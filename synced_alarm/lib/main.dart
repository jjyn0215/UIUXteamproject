import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/services.dart';

import 'src/app/synced_alarm_app.dart';
import 'src/data/app_providers.dart';
import 'src/platform/alarm_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  if (useFirebase) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  runApp(const ProviderScope(child: SyncedAlarmApp()));
  unawaited(_initializeStartupServices());
}

Future<void> _initializeStartupServices() async {
  try {
    if (useFirebase) {
      await ensureFirebaseInitialized();
    }
    await AlarmNotificationService.instance.initialize(
      firebaseEnabled: useFirebase,
    );
  } on Object catch (error, stackTrace) {
    debugPrint('Startup service initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
