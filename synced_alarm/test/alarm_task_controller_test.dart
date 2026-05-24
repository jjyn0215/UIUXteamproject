import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:synced_alarm/src/platform/alarm_task_controller.dart';

void main() {
  test('checks and opens full-screen intent settings on Android', () async {
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.teamproject.synced_alarm/alarm_task');
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      return switch (call.method) {
        'canUseFullScreenIntent' => false,
        'openFullScreenIntentSettings' => true,
        _ => null,
      };
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    try {
      expect(await AlarmTaskController.canUseFullScreenIntent(), isFalse);
      expect(await AlarmTaskController.openFullScreenIntentSettings(), isTrue);
      expect(calls.map((call) => call.method), [
        'canUseFullScreenIntent',
        'openFullScreenIntentSettings',
      ]);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  test(
    'treats full-screen intent as unavailable on non-Android platforms',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        expect(await AlarmTaskController.canUseFullScreenIntent(), isFalse);
        expect(
          await AlarmTaskController.openFullScreenIntentSettings(),
          isFalse,
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
