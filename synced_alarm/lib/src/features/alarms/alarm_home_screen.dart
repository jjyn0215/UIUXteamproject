import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_providers.dart';
import '../../design/app_theme.dart';
import '../../models/alarm.dart';
import '../../platform/alarm_task_controller.dart';
import '../../platform/alarm_notification_service.dart';
import '../settings/settings_sheet.dart';
import 'alarm_due_tick_tracker.dart';
import 'alarm_editor_sheet.dart';
import 'alarm_ring_screen.dart';

class AlarmHomeScreen extends ConsumerStatefulWidget {
  const AlarmHomeScreen({super.key});

  @override
  ConsumerState<AlarmHomeScreen> createState() => _AlarmHomeScreenState();
}

class _AlarmHomeScreenState extends ConsumerState<AlarmHomeScreen> {
  Timer? _timer;
  ProviderSubscription<AsyncValue<List<Alarm>>>? _alarmScheduleSubscription;
  StreamSubscription<AlarmNotificationLaunch>? _alarmLaunchSubscription;
  StreamSubscription<AlarmNotificationActionRequest>? _alarmActionSubscription;
  final AlarmDueTickTracker _dueTickTracker = AlarmDueTickTracker();
  String? _pendingAlarmLaunchId;
  AlarmNotificationActionRequest? _pendingAlarmAction;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _alarmScheduleSubscription = ref.listenManual<AsyncValue<List<Alarm>>>(
      alarmsProvider,
      (_, next) {
        final alarms = next.value;
        if (alarms != null) {
          _handlePendingAlarmAction(alarms);
          _handlePendingAlarmLaunch(alarms);
          if (ref.read(ringingAlarmProvider) == null) {
            unawaited(
              ref.read(alarmListControllerProvider).syncScheduledAlarms(alarms),
            );
          }
        }
      },
      fireImmediately: true,
    );
    _alarmLaunchSubscription = AlarmNotificationService.instance.alarmLaunches
        .listen(_handleAlarmLaunch);
    _alarmActionSubscription = AlarmNotificationService.instance.alarmActions
        .listen(_handleAlarmAction);
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        setState(() {});
        _ringDueAlarm();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handlePendingAlarmAction();
      _handlePendingAlarmLaunch();
      _ringDueAlarm();
    });
  }

  @override
  void dispose() {
    _alarmScheduleSubscription?.close();
    unawaited(_alarmLaunchSubscription?.cancel());
    unawaited(_alarmActionSubscription?.cancel());
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alarms = ref.watch(alarmsProvider);
    final ringingAlarm = ref.watch(ringingAlarmProvider);
    ref.watch(deviceRegistrationProvider);
    if (ringingAlarm != null) {
      return AlarmRingScreen(
        alarm: ringingAlarm,
        onDismiss: () {
          return _runAlarmScreenAction(() {
            return ref.read(alarmListControllerProvider).dismiss(ringingAlarm);
          });
        },
        onSnooze: () {
          return _runAlarmScreenAction(() {
            return ref.read(alarmListControllerProvider).snooze(ringingAlarm);
          });
        },
      );
    }

    final title = switch (_selectedTab) {
      0 => 'Alarms',
      1 => 'History',
      _ => 'Settings',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Sync status',
            icon: const Icon(Icons.sync_rounded),
            onPressed: () {
              setState(() => _selectedTab = 2);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            switch (_selectedTab) {
              0 => alarms.when(
                data: (items) => _AlarmListView(
                  alarms: items,
                  now: DateTime.now(),
                  onCreate: () => showAlarmEditor(context),
                  onEdit: (alarm) => showAlarmEditor(context, alarm: alarm),
                  onToggle: (alarm, enabled) {
                    return ref
                        .read(alarmListControllerProvider)
                        .toggleAlarm(alarm, enabled);
                  },
                  onDelete: (alarm) {
                    return ref
                        .read(alarmListControllerProvider)
                        .deleteAlarm(alarm);
                  },
                  onTestRing: (alarm) {
                    return ref.read(alarmListControllerProvider).ring(alarm);
                  },
                ),
                error: (error, _) => _ErrorPanel(
                  error: error,
                  onRetry: () => ref.invalidate(alarmsProvider),
                ),
                loading: () => const _LoadingPanel(),
              ),
              1 => const _HistoryPanel(),
              _ => const SettingsPanel(),
            },
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton(
              tooltip: 'New alarm',
              onPressed: () => showAlarmEditor(context),
              backgroundColor: SereneWakeColors.primary,
              foregroundColor: SereneWakeColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) {
          setState(() => _selectedTab = index);
        },
        backgroundColor: SereneWakeColors.surface,
        indicatorColor: SereneWakeColors.primarySoft,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm_rounded),
            label: 'Alarms',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _ringDueAlarm() {
    final alarms = ref.read(alarmsProvider).value;
    if (alarms == null || ref.read(ringingAlarmProvider) != null) {
      return;
    }

    final now = DateTime.now();
    for (final alarm in alarms.where((alarm) => alarm.enabled)) {
      if (_dueTickTracker.shouldRing(alarm, now)) {
        unawaited(ref.read(alarmListControllerProvider).ring(alarm));
        return;
      }
    }
  }

  void _handleAlarmLaunch(AlarmNotificationLaunch launch) {
    final pendingLaunch =
        AlarmNotificationService.instance.consumePendingAlarmLaunch() ?? launch;
    final alarms = ref.read(alarmsProvider).value;
    if (alarms == null || !_showLaunchedAlarm(pendingLaunch.alarmId, alarms)) {
      _pendingAlarmLaunchId = pendingLaunch.alarmId;
    }
  }

  void _handleAlarmAction(AlarmNotificationActionRequest action) {
    final pendingAction =
        AlarmNotificationService.instance.consumePendingAlarmAction() ?? action;
    final alarms = ref.read(alarmsProvider).value;
    if (alarms == null || !_runAlarmNotificationAction(pendingAction, alarms)) {
      _pendingAlarmAction = pendingAction;
    }
  }

  void _handlePendingAlarmLaunch([List<Alarm>? alarms]) {
    final initialLaunch = AlarmNotificationService.instance
        .consumePendingAlarmLaunch();
    if (initialLaunch != null) {
      _pendingAlarmLaunchId = initialLaunch.alarmId;
    }

    final pendingAlarmId = _pendingAlarmLaunchId;
    if (pendingAlarmId == null) return;
    final availableAlarms = alarms ?? ref.read(alarmsProvider).value;
    if (availableAlarms == null) return;
    _showLaunchedAlarm(pendingAlarmId, availableAlarms);
  }

  void _handlePendingAlarmAction([List<Alarm>? alarms]) {
    final initialAction = AlarmNotificationService.instance
        .consumePendingAlarmAction();
    if (initialAction != null) {
      _pendingAlarmAction = initialAction;
    }

    final pendingAction = _pendingAlarmAction;
    if (pendingAction == null) return;
    final availableAlarms = alarms ?? ref.read(alarmsProvider).value;
    if (availableAlarms == null) return;
    _runAlarmNotificationAction(pendingAction, availableAlarms);
  }

  bool _runAlarmNotificationAction(
    AlarmNotificationActionRequest action,
    List<Alarm> alarms,
  ) {
    final alarm = _findAlarmById(alarms, action.alarmId);
    if (alarm == null) return false;

    _pendingAlarmAction = null;
    _dueTickTracker.markHandled(alarm, DateTime.now());
    final controller = ref.read(alarmListControllerProvider);
    switch (action.type) {
      case AlarmNotificationActionType.dismiss:
        unawaited(controller.dismiss(alarm));
      case AlarmNotificationActionType.snooze:
        unawaited(controller.snooze(alarm));
    }
    return true;
  }

  bool _showLaunchedAlarm(String alarmId, List<Alarm> alarms) {
    final alarm = _findAlarmById(alarms, alarmId);
    if (alarm == null) return false;
    _pendingAlarmLaunchId = null;
    _dueTickTracker.markHandled(alarm, DateTime.now());
    ref.read(ringingAlarmProvider.notifier).show(alarm);
    if (mounted && _selectedTab != 0) {
      setState(() => _selectedTab = 0);
    }
    return true;
  }

  Alarm? _findAlarmById(List<Alarm> alarms, String alarmId) {
    for (final alarm in alarms) {
      if (alarm.id == alarmId) return alarm;
    }
    return null;
  }

  Future<void> _runAlarmScreenAction(Future<void> Function() action) async {
    try {
      await action();
    } finally {
      await AlarmTaskController.moveTaskToBack();
    }
  }
}

class _AlarmListView extends StatelessWidget {
  const _AlarmListView({
    required this.alarms,
    required this.now,
    required this.onCreate,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onTestRing,
  });

  final List<Alarm> alarms;
  final DateTime now;
  final VoidCallback onCreate;
  final ValueChanged<Alarm> onEdit;
  final Future<void> Function(Alarm alarm, bool enabled) onToggle;
  final Future<void> Function(Alarm alarm) onDelete;
  final Future<void> Function(Alarm alarm) onTestRing;

  @override
  Widget build(BuildContext context) {
    final sortedAlarms = [...alarms]
      ..sort((a, b) => a.timeOfDayMinutes.compareTo(b.timeOfDayMinutes));
    final nextAlarm = _nextAlarm(sortedAlarms, now);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth, 560.0);
        return Center(
          child: SizedBox(
            width: maxWidth,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.margin,
                AppSpacing.sm,
                AppSpacing.margin,
                120,
              ),
              children: [
                if (nextAlarm != null) ...[
                  _NextAlarmCard(alarm: nextAlarm, now: now),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (sortedAlarms.isEmpty)
                  _EmptyAlarmPanel(onCreate: onCreate)
                else
                  for (final alarm in sortedAlarms) ...[
                    _AlarmCard(
                      alarm: alarm,
                      now: now,
                      onEdit: () => onEdit(alarm),
                      onToggle: (enabled) => onToggle(alarm, enabled),
                      onDelete: () => onDelete(alarm),
                      onTestRing: () => onTestRing(alarm),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Alarm? _nextAlarm(List<Alarm> alarms, DateTime now) {
    final enabledAlarms = alarms.where((alarm) => alarm.enabled).toList();
    if (enabledAlarms.isEmpty) return null;
    enabledAlarms.sort(
      (a, b) => a.nextOccurrence(now).compareTo(b.nextOccurrence(now)),
    );
    return enabledAlarms.first;
  }
}

class _NextAlarmCard extends StatelessWidget {
  const _NextAlarmCard({required this.alarm, required this.now});

  final Alarm alarm;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = alarm.nextOccurrence(now);
    final duration = next.difference(now);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).abs();
    final remaining = hours <= 0
        ? '$minutes min'
        : '${hours}h ${minutes.toString().padLeft(2, '0')}m';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: SereneWakeColors.primarySoft.withAlpha(120),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SereneWakeColors.primarySoft),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next Alarm',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: SereneWakeColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            alarm.timeLabel,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              color: SereneWakeColors.primaryDark,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  alarm.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: SereneWakeColors.text,
                  ),
                ),
              ),
              Text(
                'Starts in $remaining',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SereneWakeColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlarmCard extends StatefulWidget {
  const _AlarmCard({
    required this.alarm,
    required this.now,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onTestRing,
  });

  final Alarm alarm;
  final DateTime now;
  final VoidCallback onEdit;
  final Future<void> Function(bool enabled) onToggle;
  final Future<void> Function() onDelete;
  final Future<void> Function() onTestRing;

  @override
  State<_AlarmCard> createState() => _AlarmCardState();
}

class _AlarmCardState extends State<_AlarmCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final alarm = widget.alarm;
    final subtitle = alarm.enabled
        ? _formatNext(alarm.nextOccurrence(widget.now), widget.now)
        : 'Off';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: widget.onEdit,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alarm.timeLabel,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: alarm.enabled
                                    ? SereneWakeColors.text
                                    : SereneWakeColors.mutedText,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          alarm.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: SereneWakeColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Switch(
                    value: alarm.enabled,
                    onChanged: _busy
                        ? null
                        : (enabled) async {
                            setState(() => _busy = true);
                            await widget.onToggle(enabled);
                            if (mounted) setState(() => _busy = false);
                          },
                  ),
                  PopupMenuButton<_AlarmAction>(
                    tooltip: 'Alarm actions',
                    onSelected: (action) async {
                      switch (action) {
                        case _AlarmAction.edit:
                          widget.onEdit();
                          return;
                        case _AlarmAction.test:
                          await widget.onTestRing();
                          return;
                        case _AlarmAction.delete:
                          await _confirmDelete(context);
                          return;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _AlarmAction.edit,
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: _AlarmAction.test,
                        child: Text('Test ring'),
                      ),
                      PopupMenuItem(
                        value: _AlarmAction.delete,
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: SereneWakeColors.mutedText,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _DayChips(enabled: alarm.enabled),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete alarm?'),
        content: Text(widget.alarm.timeLabel),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.onDelete();
    }
  }

  String _formatNext(DateTime next, DateTime now) {
    final duration = next.difference(now);
    if (duration.inMinutes < 1) return 'Rings now';
    if (duration.inHours < 1) return 'Rings in ${duration.inMinutes} min';
    return 'Rings in ${duration.inHours}h '
        '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}m';
  }
}

class _DayChips extends StatelessWidget {
  const _DayChips({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Wrap(
      spacing: 6,
      children: [
        for (var index = 0; index < labels.length; index++)
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled && index < 5
                  ? SereneWakeColors.primarySoft
                  : SereneWakeColors.surfaceContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              labels[index],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: enabled && index < 5
                    ? SereneWakeColors.primaryDark
                    : SereneWakeColors.mutedText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.margin),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    color: SereneWakeColors.primary,
                    size: 40,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No alarm history',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyAlarmPanel extends StatelessWidget {
  const _EmptyAlarmPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: SereneWakeColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.alarm_add_rounded,
            color: SereneWakeColors.primary,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No alarms yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New alarm'),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: SereneWakeColors.primary),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: SereneWakeColors.error,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sync unavailable',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: SereneWakeColors.mutedText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AlarmAction { edit, test, delete }
