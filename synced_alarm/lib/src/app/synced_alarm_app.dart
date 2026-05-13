import 'package:flutter/material.dart';

import '../design/app_theme.dart';
import '../features/alarms/alarm_home_screen.dart';

class SyncedAlarmApp extends StatelessWidget {
  const SyncedAlarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Synced Alarm',
      theme: buildSereneWakeTheme(),
      home: const AlarmHomeScreen(),
    );
  }
}
