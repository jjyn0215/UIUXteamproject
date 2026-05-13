import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AlarmTaskController {
  static const _channel = MethodChannel(
    'com.teamproject.synced_alarm/alarm_task',
  );

  static Future<void> moveTaskToBack() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('moveTaskToBack');
    } on MissingPluginException {
      return;
    }
  }
}
