import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:synced_alarm/src/app/synced_alarm_app.dart';
import 'package:synced_alarm/src/data/app_providers.dart';
import 'package:synced_alarm/src/features/alarms/alarm_due_tick_tracker.dart';
import 'package:synced_alarm/src/models/alarm.dart';
import 'package:synced_alarm/src/platform/alarm_task_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the alarm list shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmsProvider.overrideWith((ref) => Stream.value(const <Alarm>[])),
        ],
        child: const SyncedAlarmApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Alarms'), findsWidgets);
    expect(find.byTooltip('New alarm'), findsOneWidget);
    expect(find.byIcon(Icons.sync_disabled_rounded), findsOneWidget);
  });

  testWidgets('opens the alarm editor', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmsProvider.overrideWith((ref) => Stream.value(const <Alarm>[])),
        ],
        child: const SyncedAlarmApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('New alarm'));
    await tester.pumpAndSettle();

    expect(find.text('Set alarm'), findsOneWidget);
    expect(find.text('Label'), findsOneWidget);
  });

  testWidgets('toggles snooze details in the alarm editor', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmsProvider.overrideWith((ref) => Stream.value(const <Alarm>[])),
        ],
        child: const SyncedAlarmApp(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('New alarm'));
    await tester.pumpAndSettle();

    expect(find.text('Use snooze'), findsOneWidget);
    expect(find.text('Snooze after'), findsOneWidget);
    expect(find.text('Max snoozes'), findsOneWidget);

    await tester.ensureVisible(find.text('Use snooze'));
    await tester.tap(find.text('Use snooze'));
    await tester.pumpAndSettle();

    expect(find.text('Snooze after'), findsNothing);
    expect(find.text('Max snoozes'), findsNothing);
  });

  testWidgets('shows a dedicated alarm screen while an alarm is ringing', (
    WidgetTester tester,
  ) async {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmsProvider.overrideWith((ref) => Stream.value([alarm])),
          ringingAlarmProvider.overrideWith(
            () => _FixedRingingAlarmNotifier(alarm),
          ),
        ],
        child: const SyncedAlarmApp(),
      ),
    );
    await tester.pump();

    expect(find.text('8:30 AM'), findsOneWidget);
    expect(find.text('Morning standup'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byTooltip('New alarm'), findsNothing);
  });

  testWidgets('hides the snooze action when snooze is disabled', (
    WidgetTester tester,
  ) async {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: true,
      maxSnoozeCount: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          alarmsProvider.overrideWith((ref) => Stream.value([alarm])),
          ringingAlarmProvider.overrideWith(
            () => _FixedRingingAlarmNotifier(alarm),
          ),
        ],
        child: const SyncedAlarmApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Snooze'), findsNothing);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('dismiss on ringing screen finishes alarm presentation', (
    WidgetTester tester,
  ) async {
    final alarm = Alarm(
      id: 'alarm-1',
      groupId: 'demo',
      label: 'Morning standup',
      timeOfDayMinutes: 8 * 60 + 30,
      enabled: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final calls = <MethodCall>[];
    const channel = MethodChannel('com.teamproject.synced_alarm/alarm_task');
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call);
      if (call.method == 'finishAlarmPresentation') return true;
      return null;
    });
    FlutterLocalNotificationsPlatform.instance =
        _FakeAndroidLocalNotificationsPlugin();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await AlarmTaskController.finishAlarmPresentation();
      expect(
        calls.map((call) => call.method),
        contains('finishAlarmPresentation'),
      );
      calls.clear();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            alarmsProvider.overrideWith((ref) => Stream.value([alarm])),
            alarmListControllerProvider.overrideWith(
              (ref) => _NoopAlarmListController(ref),
            ),
            ringingAlarmProvider.overrideWith(
              () => _FixedRingingAlarmNotifier(alarm),
            ),
          ],
          child: const SyncedAlarmApp(),
        ),
      );
      await tester.pump();

      expect(find.widgetWithText(FilledButton, 'Dismiss'), findsOneWidget);
      final dismissButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Dismiss'),
      );
      expect(dismissButton.onPressed, isNotNull);
      dismissButton.onPressed?.call();
      await tester.pumpAndSettle(const Duration(seconds: 1));
      for (var i = 0; i < 20; i++) {
        if (calls.any((call) => call.method == 'finishAlarmPresentation')) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        calls.map((call) => call.method),
        contains('finishAlarmPresentation'),
      );
      expect(find.widgetWithText(FilledButton, 'Dismiss'), findsNothing);
      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
      expect(find.byTooltip('New alarm'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  testWidgets(
    'clears a resolved ringing alarm when returning to the main task',
    (WidgetTester tester) async {
      final now = DateTime.now();
      final alarm = Alarm(
        id: 'alarm-1',
        groupId: 'demo',
        label: 'Morning standup',
        timeOfDayMinutes: now.hour * 60 + now.minute,
        enabled: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      await AlarmDueTickTracker().markResolved(alarm, now);

      final calls = <MethodCall>[];
      const channel = MethodChannel('com.teamproject.synced_alarm/alarm_task');
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      FlutterLocalNotificationsPlatform.instance =
          _FakeAndroidLocalNotificationsPlugin();
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              alarmsProvider.overrideWith((ref) => Stream.value([alarm])),
              ringingAlarmProvider.overrideWith(
                () => _FixedRingingAlarmNotifier(alarm),
              ),
            ],
            child: const SyncedAlarmApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.widgetWithText(FilledButton, 'Dismiss'), findsNothing);
        expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);
        expect(
          calls.map((call) => call.method),
          contains('stopAlarmVibration'),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
      }
    },
  );
}

class _FixedRingingAlarmNotifier extends RingingAlarmNotifier {
  _FixedRingingAlarmNotifier(this.alarm);

  final Alarm alarm;

  @override
  Alarm? build() => alarm;
}

class _NoopAlarmListController extends AlarmListController {
  _NoopAlarmListController(super.ref);

  @override
  Future<void> dismiss(Alarm alarm, {bool clearRingingAlarm = true}) async {}
}

class _FakeAndroidLocalNotificationsPlugin
    extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    return true;
  }

  @override
  Future<NotificationAppLaunchDetails?>
  getNotificationAppLaunchDetails() async {
    return null;
  }

  @override
  Future<void> createNotificationChannel(
    AndroidNotificationChannel notificationChannel,
  ) async {}

  @override
  Future<bool?> requestNotificationsPermission() async => true;

  @override
  Future<void> cancel({required int id, String? tag}) async {}
}
