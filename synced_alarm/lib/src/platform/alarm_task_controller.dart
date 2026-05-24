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

  static Future<bool> finishAlarmPresentation() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('finishAlarmPresentation') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> startAlarmVibration({
    required bool vibrationEnabled,
    required Duration duration,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('startAlarmVibration', {
            'vibrationEnabled': vibrationEnabled,
            'ringDurationMillis': duration.inMilliseconds,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> stopAlarmVibration() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('stopAlarmVibration') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openNotificationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('openNotificationSettings') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> canUseFullScreenIntent() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<bool> openFullScreenIntentSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openFullScreenIntentSettings',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
